# 04 — Pendências, Bugs e Roadmap

> Auditoria baseada em `ROADMAP.md` (commit `80c95596`, 2026-05-16)  
> Atualizado: 2026-05-20

---

## P0 — Crítico (resolver imediatamente)

### 🔴 Bug #1 — Webhook de pagamento atribui ao workspace errado
- **Arquivo:** `app/api/payments/webhook/route.ts:124-133`
- **Problema:** Se `transaction_id` não encontra `checkout_orders`, atribui ao **primeiro workspace criado** (`SELECT id FROM workspaces ORDER BY created_at ASC LIMIT 1`). Em SaaS multi-tenant = catastrófico.
- **Correção:** Substituir o fallback por `return NextResponse.json({ error: 'workspace not found' }, { status: 422 })`
- **Esforço:** 5 min

### 🔴 Bug #2 — Divergência de planos entre `rbac.ts` e `features.ts`
- **Arquivos:** `lib/auth/rbac.ts:11` vs `lib/server/features.ts:114`
- **Problema:** `rbac.ts` tem 4 planos; `features.ts` tem 6. Workspace com `plan='business'` é tratada como `free` silenciosamente.
- **Correção:** Criar `lib/plans/definitions.ts` com 6 planos canônicos e importar nos dois lados.
- **Esforço:** 30 min

### 🔴 Bug #3 — Plano `reseller` não declarado em nenhuma lista
- **Problema:** `workspace_subscriptions` tem 1 linha com `plan='reseller'` — não existe em `PLAN_HIERARCHY`. Workspace tratada como `free`.
- **Correção:** Adicionar `reseller` à hierarquia ou migrar para plano correto.
- **Esforço:** 20 min

### 🔴 Bug #18/19 — 72 rotas `/api/migrate/*` expostas sem verificação clara de auth
- **Arquivo:** `app/api/migrate/*`
- **Problema:** Rotas como `reset-all-data`, `cleanup-zapvoice` ainda no código. `/api/migrate/reset-all-data` apaga todos os dados operacionais. Middleware pode não estar protegendo corretamente.
- **Ação imediata:** Auditar cada rota, confirmar que requerem `ADMIN_MIGRATION_SECRET` e idealmente deletar as não utilizadas.
- **Esforço:** 4 h

### 🔴 Bug #20 — `workspace_plans.price_cents=0` para planos pagos
- **Problema:** Workspace `Fábrica` está em `plan='pro'` com `price_cents=0` → nunca cobrou.
- **Correção:** `UPDATE workspace_plans SET price_cents = <valor_correto> WHERE plan IN ('starter','pro','business','enterprise')`
- **Esforço:** 1 h

### 🔴 Feature crítica — Cobrança SaaS recorrente não funciona
- **Problema:** Webhook Amplo Pay não ativa `workspace_subscriptions` ao receber pagamento de plano. Cron `plan-expiry` existe mas não bloqueia workspace vencida. Cobrança é PIX one-shot, não subscription.
- **Arquivos:** `app/api/workspace/plan/subscribe/route.ts`, `app/api/payments/amplopay-webhook/route.ts`, `app/api/cron/plan-expiry/route.ts`
- **O que implementar:**
  - [ ] Webhook detectar `payment_type='workspace_plan'` e ativar subscription
  - [ ] Cron bloqueando/alertando workspace vencida
  - [ ] UI de cancelamento/downgrade
  - [ ] Cobrança recorrente automática (Amplo Pay subscriptions)
- **Esforço:** 10 h
- **Impacto:** Sem isso, receita SaaS = R$ 0 automatizado

---

## P1 — Alta prioridade (resolver esta semana)

### 🟠 Bug #4 — `getActiveWorkspaceId.ts` cria Pool próprio (vazamento)
- **Arquivo:** `lib/auth/getActiveWorkspaceId.ts:5-8`
- **Problema:** Cria novo `Pool` em vez de usar singleton de `lib/db.ts`. Dobra conexões.
- **Correção:** `import { query } from '@/lib/db'` e remover Pool local.
- **Esforço:** 15 min

### 🟠 Bug #5 — Cast `::uuid` em campo `text` no mesmo arquivo
- **Arquivo:** `lib/auth/getActiveWorkspaceId.ts:30,44`
- **Problema:** `user_id = $2::uuid` mas coluna é `text`. Pode falhar em IDs não-UUID.
- **Correção:** Remover cast `::uuid`.
- **Esforço:** 30 min

### 🟠 Bug #6 — Atribuição de comissão incorreta em `/api/iptv/payments`
- **Arquivo:** `app/api/iptv/payments/route.ts:100`
- **Problema:** `sellerUserId = trial.sold_by_user_id || session.user.id` — atribui comissão ao admin logado quando `sold_by_user_id` é null.
- **Correção:** `sellerUserId = trial.sold_by_user_id ?? null` — sem fallback para sessão.
- **Esforço:** 5 min

### 🟠 Bug #7 — `audit_logs` com 2.4M linhas sem retenção (~1 GB)
- **Problema:** Cron existe mas tabela cresceu descontrolada.
- **Ação:** `DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '90 days'` (em batches de 100k) + confirmar cron ativo + `VACUUM ANALYZE`
- **Esforço:** 1 h

### 🟠 Bug #13 — Webhook legado `/api/payments/webhook` ainda ativo
- **Problema:** DEPRECADO mas ainda exposto e processando — risco de double-processing com `amplopay-webhook`.
- **Ação:** Verificar quem ainda chama; retornar `410 Gone` ou deletar.
- **Esforço:** 1 h

### 🟠 Bug #14 — Extensão `pgvector` quebrada
- **Problema:** `could not access file "$libdir/vector"` — toda feature de RAG/Knowledge falha silenciosamente.
- **Ação:** Trocar imagem Postgres para `pgvector/pgvector:pg16`; `CREATE EXTENSION IF NOT EXISTS vector;`; reindexar.
- **Esforço:** 1 h

### 🟠 Feature — Enforcement de limites por plano
- **Problema:** `lib/server/workspace-limits.ts` tem as funções mas não estão aplicadas nas rotas.
- **O que implementar:**
  - [ ] `checkInstanceLimit` em POST `/api/instances`
  - [ ] `checkContactLimit` em POST `/api/contacts` e import
  - [ ] `checkMonthlyMessageLimit` no worker antes de enviar
- **Esforço:** 4 h

---

## P2 — Média prioridade (próximas 2 semanas)

### 🟡 Bug #8,9,10 — Tabelas de log sem retenção
- `webhook_token_audit` (250k): cron diário deletando > 30 dias
- `processed_events` (391k): deletar > 7 dias  
- `worker_runs` (383k): deletar > 30 dias
- Adicionar ao cron `db-retention` já existente
- **Esforço total:** 30 min

### 🟡 Bug #11 — `iptv/trials` executa UPDATE em cada GET
- **Arquivo:** `app/api/iptv/trials/route.ts:36`
- **Problema:** Cada listagem faz `batch_update_expired_trials($1)` na tabela inteira.
- **Correção:** Confiar no cron `promote-expired-trials`; remover UPDATE síncrono.
- **Esforço:** 30 min

### 🟡 Bug #15 — `iptv_active_trials` é VIEW lenta
- **Ação:** Converter para MATERIALIZED VIEW com refresh a cada 5 min.
- **Esforço:** 1 h

### 🟡 Bug #16 — `console.log` em `auth.ts` vazando PII em produção
- **Arquivo:** `auth.ts:28,46`
- **Correção:** `logger.debug` + gate por `NODE_ENV !== 'production'`
- **Esforço:** 5 min

### 🟡 Feature — Marketplace de Agentes IA
- Tabelas e rotas prontas; falta curadoria de conteúdo (5+ agentes) + conectar cobrança ao webhook
- **Esforço:** 12 h

### 🟡 Feature — API externa v1 (monetizável)
- 0 tokens emitidos; UI de gestão funciona? Verificar; adicionar rate limit + docs OpenAPI
- **Esforço:** 6 h

### 🟡 Feature — Webchat embed
- Gerar snippet `<script>` para embed externo + analytics
- **Esforço:** 6 h

### 🟡 Feature — NPS automatizado
- Cron disparando NPS X dias após conversão; UI de configuração de gatilho
- **Esforço:** 4 h

### 🟡 Feature — CRM: importar leads e drag-drop
- 1 pipeline e 6 stages criados; 0 deals. Importar de conversas + drag-drop + métricas de funil
- **Esforço:** 8 h

### 🟡 Feature — Afiliados
- Só landing/signup. Falta comissionamento, painel de afiliado, rastreamento de conversão
- **Esforço:** 8 h

---

## P3 — Baixa prioridade / Roadmap IA

### 🟢 Score de Lead (0-100)
- Calcular probabilidade de fechar por conversa com base em comportamento
- Arquivo novo: `apps/worker/src/handlers/score-lead.ts`
- **Esforço:** 4 h

### 🟢 Resumo automático ao abrir conversa antiga
- `/summarize` existe on-demand; tornar automático e cacheado
- **Esforço:** 2 h

### 🟢 Análise de sentimento em tempo real
- Marcar conversa como `frustrated/happy/neutral/curious` na sidebar
- **Esforço:** 4 h

### 🟢 A/B test de mensagens nas automações
- `automation_steps.variants jsonb[]` + router de variantes
- **Esforço:** 6 h

### 🟢 Predição de churn (recorrência)
- Prever cancelamento 7 dias antes da renovação
- `churn_alerts` (33 linhas) já existe
- **Esforço:** 8 h

### 🟢 Voice-note auto-resposta
- Cliente manda áudio → transcreve → IA responde com áudio (ElevenLabs)
- Componentes existem isolados; falta orquestração no worker
- **Esforço:** 8 h

### 🟢 SaaS Tickets (suporte ao cliente do SaaS)
- Schema + rotas prontas; 0 tickets. Falta UI para abrir ticket, notificação, SLA.
- **Esforço:** 6 h

---

## Plano de planos sugerido (para implementar junto com monetização)

| Plano | Preço | Diferencial |
|-------|-------|-------------|
| **Starter** | R$ 97/mês | 2 instâncias, 2k contatos, inbox + automações básicas |
| **Pro** | R$ 197/mês | 5 instâncias, 10k contatos, IPTV + IA + Recorrência |
| **Business** | R$ 397/mês | 10 instâncias, 100k contatos, Sales Brain + Knowledge + API |
| **Enterprise** | R$ 997/mês | Ilimitado + Whitelabel + Multi-workspace + CRM completo |

**Add-ons:**
- Instância extra: R$ 49/mês
- +10k contatos: R$ 39/mês
- Pacote IA 1.000 msg: R$ 49 one-time
- Agente IA Premium: R$ 19-99/mês

---

## Checklist de monetização (sequência recomendada)

- [ ] Corrigir Bug #2 e #3 (planos)
- [ ] Corrigir Bug #20 (price_cents zerado)
- [ ] Implementar webhook ativando workspace_subscriptions
- [ ] Implementar enforcement de limites
- [ ] Implementar cron de bloqueio por vencimento
- [ ] Testar fluxo end-to-end: assinar → pagar PIX → workspace ativada
- [ ] Colocar em produção a cobrança de "Fábrica" (pro R$197) e "Eduardo" (free → trial)
- [ ] Implementar UI de upgrade no `/meu-plano`

---

*Veja também: [[00-visao-geral]] | [[01-modulos]] | [[05-fluxos-principais]]*
