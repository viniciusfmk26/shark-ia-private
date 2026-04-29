# Pipeline Sales-Brain — Funções Pendentes de Integração

**Status atual:** `onPaymentConfirmed` plugado no webhook AmploPay (commit `f48af9b8`, 29/04/2026).
**Backfill aplicado:** 147 opportunities → 'won' via Opção C (payment_after_stage_change).

## Funções existentes em lib/sales-brain/pipeline.ts mas NÃO chamadas

### 1. onTrialExpired(workspaceId, conversationId, contactId, contactName)
**O que faz:** marca opportunity como `lost` quando trial expira sem conversão.

**Onde DEVERIA ser chamado:**
- `app/api/cron/plan-expiry/route.ts` — quando plan_expires_at < NOW() e plan_type='trial'
- `app/api/cron/trial-followup/route.ts` — após N tentativas sem conversão (último step da campanha)
- `app/api/cron/promote-expired-trials/route.ts` — se existir

**Backfill candidato:**
- 1.198 opportunities com stage='trial' e stage_changed_at entre 30-60d atrás
- Sem pagamento posterior
- 100% Uniflix workspace

**Tempo estimado fix:** 30-45min (1 cron + backfill SQL)

---

### 2. onTicketResolved(workspaceId, conversationId, contactId, contactName, resolution)
**O que faz:** registra evento de ticket resolvido (não promove opp diretamente — apenas marca como ponto positivo no funil).

**Onde DEVERIA ser chamado:**
- Endpoint de resolver conversa (procurar `app/api/conversations/.../resolve` ou similar)
- Status change conversation → 'resolved'
- Worker handler quando manualmente resolve via inbox

**Backfill candidato:**
- conversations com status='resolved' (verificar quantas)
- Não crítico — feature passive (só registra evento, não muda stage)

**Tempo estimado fix:** 20-30min

---

### 3. onPaymentConfirmed em outros webhooks
**O que faz:** mesmo que AmploPay — promove opportunity a 'won'.

**Onde DEVERIA ser chamado (verificar existência):**
- `app/api/payments/manual/...` — pagamentos manuais (admin)
- `app/api/payments/...checkout-webhook` — webhook checkout interno
- Qualquer outro provedor de pagamento futuro (Stripe, Mercadopago)

**Backfill candidato:** depende de quantos workspaces usam outros métodos.

**Tempo estimado fix:** 30min por webhook adicional

---

### 4. onPlanExpired(workspaceId, contactId, contactName)
**O que faz:** registra `churn_signal` quando plano de cliente expira (não cancela, só sinaliza risco).

**Onde DEVERIA ser chamado:**
- `app/api/cron/plan-expiry/route.ts` — mesmo cron do onTrialExpired, branch para `plan_type='paid'`

**Tempo estimado fix:** 20min (junto com onTrialExpired)

---

### 5. onTrialCreated(workspaceId, conversationId, contactId, contactName)
**O que faz:** cria/atualiza opportunity com stage='trial' quando cliente começa trial.

**Status:** parcialmente integrado — worker.ts:6519 já faz UPSERT em sales_opportunities mas via lógica direta, não chama esta função.

**Decisão arquitetural:** consolidar (chamar onTrialCreated) ou deixar como está (UPSERT direto no worker)?

---

## Auto-lost cron (futuro)

**Conceito:** cron varre opportunities com `stage IN ('lead','qualified','trial')` e `stage_changed_at < NOW() - INTERVAL '90 days'` e promove a 'lost' por inatividade.

**Estado atual:** 0 opps elegíveis (pipeline tem só 5 semanas de história).

**Em ~2 meses:** ~600+ opps na faixa >60d sem ação ficarão >90d.

**Tempo estimado fix:** 1-2h (cron + tabela tracking + dashboard alert).

---

## Decisão de escopo de hoje (29/04/2026)

APLICADO: onPaymentConfirmed no webhook AmploPay + backfill 147
DEFERIDO: itens 1-5 acima

**Razão:** escopo isolado = commit limpo, risco baixo, fácil reverter se algo der errado.

Investigação completa em `/root/deep-sales-brain.md`.
