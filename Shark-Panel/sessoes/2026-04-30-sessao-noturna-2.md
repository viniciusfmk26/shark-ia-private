# Sessão Noturna 30/04 → 01/05/2026 — Parte 2

> Execução autônoma de 10 blocos. Tudo aplicado em produção (`app.sharkpanel.com.br`).
> Continuação da [[2026-04-30-sessao-noturna]] (parte 1).

## O que foi executado

### Bloco 1 — Documentação
- ✅ Vault clonado, `auditoria-completa-2026-04-30.md` confirmado, README atualizado com resumo + 8 próximos passos priorizados.

### Bloco 2 — Auditoria de Configurações
**Doc gerado**: [[configuracoes-e-secrets]]
- **Env vars usadas no código**: 64 (web + worker)
- **Definidas em prod**: 37
- **Faltando em prod (37)**: críticas — `OPENAI_API_KEY`, `AMPLOPAY_PUBLIC_KEY/SECRET_KEY`, `EVOLUTION_BASE_URL/TOKEN` (legacy), `POSTGRES_URL` (legacy), `MIGRATE_SECRET`, `CRON_SECRET` (duplicidade)
- **Definidas mas nunca usadas (9)**: `NEXT_PUBLIC_SUPABASE_*`, `SUPABASE_SERVICE_ROLE_KEY` — vestígios Supabase
- **Hardcoded secrets no código**: 0 (zero) — apenas alfabetos para gerar IDs
- **Hardcoded no DB (achado)**: ELEVENLABS api_key (`sk_21018bd8f...`) em `workspace_settings.elevenlabs.api_key` em 3 workspaces
- **Instâncias órfãs (sem workspace_id)**: 6 (4 com conversas: Kerolayne, Kerolayne Redmi, MayaraK, Uniflix Web; 2 vazias: Mayara j, New)
- **Evolution API**: URL única `http://evolution-api-2:8080`, key global `429683C4...` — sem key por instância
- **Sistema de planos SaaS (CORREÇÃO)**: existe — tabela `workspace_plans` com `max_instances/monthly_messages/ai_messages_month/trial_days`. Apenas 1 workspace configurado (Shark Panel = enterprise 999/999999/999999). Demais 4 workspaces usam defaults (free, max_instances=1) **sem enforcement** (limites não bloqueiam nada).

### Bloco 3 — Crons
- Estado já estava bom da parte 1; ajustadas 3 frequências:
  - `purge-jobs`: 6h → **2h** (madrugada limpa antes do tráfego)
  - `follow-up`: a cada 4h → **a cada hora**
  - `monthly-payroll`: dia 1 1h → **dia 1 10h** (horário comercial)
- Commit: `77992ef6`

### Bloco 4 — Backfill de Subscriptions
- **Antes (início da sessão)**: 1.337 ativas (parte 1 já tinha feito o backfill)
- **Após sync UI**: 0 novas
- **Após cron recorrencia-sync (todos workspaces)**: 0 novas
- **Restantes 33 pagamentos órfãos**: todos são "tela extra" / valor < 2000 com palavra "tela" — **filtrados intencionalmente** pelo regex de `recorrencia/sync`. Backfill completo.

### Bloco 5 — Dados Inconsistentes
- **Pagamentos sem contact_id**: 94 → 92 (vinculados 2 via phone match)
- **Conversas sem contact_id**: 2 (Fernando Oliveira `11954490107`, xoxolaleite `5522997370741`) — sem contato correspondente em `contacts`. Não vinculados (criar contact dispararia triggers).
- **Instâncias órfãs**: 6 — **NÃO mexidas** (decisão precisa de confirmação humana sobre qual workspace é o destino).
- **Conversas com status `resolved`**: 2.149 (legado) — **NÃO normalizadas** (alto risco sem confirmação).

### Bloco 6 — Retenção de Dados
- `audit_logs`: **706 MB** (1.47M registros em abril, 152k em março) — cron `db-retention` já configurado (>90d), próxima execução dom 03:00
- `processed_events`: 134 MB (268k registros) — cron deleta >30d
- `worker_runs`: cron deleta >14d
- `jobs`: 11k succeeded recentes — cron `purge-jobs` (24h/7d/3d por status) já agendado
- **Disco**: 72G/193G (38% usado)
- **Build cache reclamável**: 34.86 GB (`docker builder prune` — não executado, pode ser feito amanhã)

### Bloco 7 — Segurança Adicional
- ✅ Todas as **3 rotas /api/debug/** têm `requireSuperAdmin()`
- ✅ Todas as **~70 rotas /api/migrate/** têm `requireSuperAdmin()` (CLAUDE.md está desatualizado nessa parte)
- **CORS aberto (`*`)**: `/api/trial/*`, `/api/rotation/*`, `/api/webchat/*` — endpoints públicos por design (esperado, mas considerar restringir origins)
- **Rate limiting**: existe `lib/rateLimit.ts`, aplicado apenas em `/api/health/*`. Demais rotas públicas (`/trial`, `/rotation`, `/webchat`) **sem rate limit**
- **SQL injection**: nenhum risco real encontrado. Templates `${table}`/`${fields}` em queries são variáveis internas/whitelist (workspaces delete cascata, checkout-admin update fields, migrate DDL controlada)

### Bloco 8 — Refatoração: customer-lifecycle.ts
- ✅ Criado `lib/server/customer-lifecycle.ts` (289 linhas)
- Funções centralizadas:
  - `activateCustomer({contactId, workspaceId, planType, durationMonths|expiresAt})`
  - `createSubscription({contactId, workspaceId, planName, amountCents, billingCycle?, paymentId?})` — **idempotente** (não cria duplicata se já existe ativa)
  - `expireCustomer(contactId, workspaceId)`
  - `getCustomerStatus(contactId, workspaceId)` → `{status: 'lead'|'trial'|'active'|'expired'|'churned', planType, planExpiresAt, activeSubscriptionId, trialActive}`
  - `recordPayment(...)` — entrada de alto nível: insere payment + activate + createSubscription
- Helpers: `inferBillingCycle(name, cents)`, `computeNextBilling(date, cycle)`
- **Compatibilidade**: módulo coexiste com call sites legados (amplopay-webhook, iptv/trials/activate). Adoção gradual.
- Commit: `ddf96905`

### Bloco 9 — Build/Deploy/Smoke-test
- ✅ Build `zapflix-tech:latest` OK
- ✅ Build `easypanel/wp/zapflix-cron:latest` OK
- ✅ `docker service update --force wp_zapflix-web` convergiu
- ✅ `docker service update --force wp_zapflix-cron` convergiu
- **Smoke-test 18 endpoints**: **18/18 = 200** ✅✅✅
  - auth/session, instances, inbox/conversations, contacts, iptv/trials, recorrencia/subscriptions, instances/health, analytics/overview, analytics/revenue, dashboard/overview, iptv/favorites, knowledge/bases, workspace/buy-credits, metrics/snapshot, metrics/weekly-report, workspace/activate-module, admin/payouts, analytics/heatmap

## Problemas encontrados (sem bloqueio)
- 2 conversas órfãs (sem contact correspondente) — criar contacts pode disparar triggers, deixado para revisão manual
- 6 instâncias WhatsApp órfãs (sem workspace_id) — vincular ao workspace correto requer decisão humana sobre destino
- 2.149 conversas com status legado `resolved` — normalização para `closed` pode quebrar UI/relatórios, deixado para revisão
- ELEVENLABS api_key exposta no DB — mover para env var
- Sistema de planos SaaS existe mas não enforce limites (max_instances/monthly_messages só leitura)

## Próximos passos para amanhã (priorizados)
1. **🔴 Mover ELEVENLABS api_key para env var** (atualmente em texto puro no DB)
2. **🔴 Definir env vars críticas em prod**: `OPENAI_API_KEY`, `AMPLOPAY_PUBLIC_KEY`, `AMPLOPAY_SECRET_KEY`, `NEXT_PUBLIC_APP_URL`
3. **🟡 Validar primeira execução do cron `recorrencia-sync`** (00:00) — `docker service logs wp_zapflix-cron --tail 100 -f`
4. **🟡 Decidir destino das 6 instâncias órfãs** + executar UPDATE em lote
5. **🟡 Implementar enforcement** de limites em `workspace_plans` (max_instances etc) — hoje só leitura
6. **🟢 Adotar `customer-lifecycle.ts`** em call sites legados (amplopay-webhook, iptv/trials/activate, recorrencia/sync) — refactor gradual
7. **🟢 Limpar env vars legadas**: vestígios Supabase (`NEXT_PUBLIC_SUPABASE_*`, `SUPABASE_SERVICE_ROLE_KEY`), `POSTGRES_URL`, `EVOLUTION_BASE_URL/TOKEN`, `MIGRATE_SECRET`, `CRON_SECRET`
8. **🟢 Configurar planos checkout para `server=1` (megabox)** ou desativar opção
9. **🟢 Rate limiting** em `/trial`, `/rotation`, `/webchat` (rotas públicas sem limite)
10. **🟢 `docker builder prune`** — recuperar 34.86 GB

## Commits desta sessão (parte 2)
| Hash | Mensagem |
|---|---|
| `77992ef6` | feat(cron): ajustar follow-up hourly, monthly-payroll dia 1 às 10h, purge-jobs às 2h |
| `ddf96905` | refactor: centralizar ciclo de vida do cliente em lib/server/customer-lifecycle.ts |

(commits da parte 1: `41e78dd9`, `45064bcb`)

## Estado final do sistema
- Web: rodando com nova imagem (`zapflix-tech:latest`)
- Cron: rodando com novo `supercronic.cron` (28 jobs agendados, incluindo `recorrencia-sync` à 00:00)
- DB: 1.337 subscriptions ativas (era 317 no início), 706 MB audit_logs sob retenção 90d
- Smoke-test: 18/18 endpoints OK
- 4 commits pushed para `viniciusfmk26/Zapflix-Tech` main
