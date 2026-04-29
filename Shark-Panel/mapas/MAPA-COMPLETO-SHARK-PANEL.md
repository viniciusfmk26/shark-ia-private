# 🦈 MAPA COMPLETO — Shark Panel

> Documentação exaustiva do sistema, gerada em **2026-04-29** após auditoria de leitura.
> Nenhuma alteração de código ou dado foi feita. Apenas leitura.
>
> **Arquivos auxiliares:**
> - [`mapa-rotas.md`](./mapa-rotas.md) — frontend + APIs backend
> - [`mapa-banco.md`](./mapa-banco.md) — schema completo + relações
> - [`mapa-permissoes.md`](./mapa-permissoes.md) — RBAC + matriz role × ações
> - [`mapa-fluxos.md`](./mapa-fluxos.md) — fluxos críticos E2E
> - [`mapa-integracoes.md`](./mapa-integracoes.md) — Sigma, AmploPay, Evolution

---

## Sumário

- [Seção 1 — Arquitetura geral](#seção-1--arquitetura-geral)
- [Seção 2 — Mapa de páginas frontend](./mapa-rotas.md#frontend)
- [Seção 3 — Sidebar e menus por papel](#seção-3--sidebar-e-menus-por-papel)
- [Seção 4 — APIs backend](./mapa-rotas.md#backend)
- [Seção 5 — Schema de banco](./mapa-banco.md)
- [Seção 6 — Integrações externas](./mapa-integracoes.md)
- [Seção 7 — Sistema de permissões](./mapa-permissoes.md)
- [Seção 8 — Workspaces](#seção-8--workspaces-multi-tenant)
- [Seção 9 — Features ativas](#seção-9--features-ativas-em-produção)
- [Seção 10 — Fluxos críticos](./mapa-fluxos.md)
- [Seção 11 — Crons](#seção-11--cron-jobs--background-tasks)
- [Seção 12 — Segurança e auditoria](#seção-12--segurança-e-auditoria)
- [Seção 13 — Bugs](#seção-13--bugs-conhecidos)
- [Seção 14 — Roadmap](#seção-14--roadmap)
- [Seção 15 — Deploy](#seção-15--como-o-sistema-é-deployado)
- [Seção 16 — Cheatsheet](#seção-16--vinicius-cheat-sheet)
- [Seção 17 — Glossário](#seção-17--glossário)

---

## Seção 1 — Arquitetura geral

### 1.1 — Stack

**Frontend / API (Next.js 16 standalone)**
- Next.js **16.0.10** (App Router)
- React **19.2.0**, TypeScript 5
- NextAuth **5.0.0-beta.30** — Credentials provider, JWT sessions, `@auth/pg-adapter`
- Tailwind CSS 4 + Radix UI + lucide-react
- Server-side: `pg` 8 (Postgres driver), `bcryptjs`, `pino` (logger)
- Async: `bullmq` instalado mas **não usado** — fila real é Postgres `SKIP LOCKED` na tabela `jobs`
- IO: `ioredis`, `@aws-sdk/client-s3`, `swr` (data fetching), `react-hook-form` + `zod`

**Worker (assíncrono)**
- Imagem **separada** `easypanel/wp/zapflix-worker:latest` (Dockerfile.worker)
- Polling em Postgres com SKIP LOCKED (não BullMQ)
- 12 tipos de job: `send_message`, `sync_instance`, `process_webhook`, `ai_response`, `sync_contacts`, `check_delivery`, `send_audio`, `send_image`, `send_video`, `send_document`, `process_guided_funnel`, `send_followup_trial`

**Cron (supercronic)**
- Imagem `easypanel/wp/zapflix-cron:latest` (Dockerfile.cron, debian:bookworm-slim)
- supercronic v0.2.43 — 26 entradas em `/etc/crontab.supercronic`
- Cada job: `curl` para `/api/cron/<name>` autenticado por `CRON_TOKEN`

**Banco**
- PostgreSQL 17 (`wp_zapflix-db`)
- **192 tabelas** no schema `public` (CLAUDE.md cita 190 — diferença de migrations recentes)
- Role `zapflix` é `superuser` + `BYPASSRLS` — políticas RLS estão definidas mas não enforced
- Schema `auth.*` ainda existe (resíduo Supabase) — não usar

**Storage**
- MinIO (`wp_zapflix-minio`), bucket `zapflix-media`, URL pública `https://wp-zapflix-minio.jomik8.easypanel.host/zapflix-media`

**WhatsApp**
- Evolution API v2 (`wp_evolution-api-2`, v2.3.7)
- Postgres dedicado (`wp_evolution-api-2-db`) e Redis compartilhado (`wp_evolution-api-2-redis`)

**Checkout (sistema legado, Vite + tRPC + MySQL)**
- `wp_zapflix-checkout` (image `zapflix-checkout:latest`)
- MySQL 8 em `wp_zapflix-checkout-db`
- DBGate em `wp_zapflix-checkout-db_dbgate`
- **Dependência cruzada:** o app principal Shark Panel acessa o banco do checkout via `/api/checkout/*` proxy

**Landing**
- `wp_shark-landing` — nginx estático, domínio `sharkpanel.com.br` (pendente)

**Containers em execução (verificado 29/04/2026):**
```
wp_zapflix-web                 → zapflix-tech:latest         (Next.js)
wp_zapflix-worker              → easypanel/wp/zapflix-worker:latest
wp_zapflix-cron                → easypanel/wp/zapflix-cron:latest
wp_zapflix-db                  → postgres:17
wp_zapflix-minio               → minio/minio:latest
wp_zapflix-checkout            → zapflix-checkout:latest     (Vite/tRPC)
wp_zapflix-checkout-db         → mysql:9
wp_zapflix-checkout-db_dbgate  → dbgate/dbgate:6.0.0
wp_zapflix-admin               → easypanel/wp/zapflix-admin:latest (Manus.im SPA)
wp_zapflix                     → 4ab2bb5a3f8c (legado/desconhecido)
wp_evolution-api-2             → evoapicloud/evolution-api:v2.3.7
wp_evolution-api-2-db          → postgres:17
wp_evolution-api-2-redis       → redis:7
wp_evolution-api-2-redis_rediscommander → ghcr.io/joeferner/redis-commander:0.9.0
wp_shark-landing               → shark-landing:latest
easypanel + easypanel-traefik  → orquestração + reverse proxy
```

### 1.2 — Domínios e ambientes

| Domínio | Container/serviço | Quem acessa | Auth |
|---|---|---|---|
| `app.sharkpanel.com.br` | `wp_zapflix-web` (Next.js) | Donos/admins de workspace, agents, resellers | NextAuth (login `/login`) |
| `admin.sharkpanel.com.br` | mesmo container; rotas `/master/*` | Superadmin | NextAuth + `requireSuperAdmin()` (login `/master-login`) |
| `sharkpanel.com.br` | `wp_shark-landing` | Público (landing) | — |
| `wp-zapflix-minio.jomik8.easypanel.host` | MinIO | Mídias públicas | nenhuma (bucket público) |
| `wp-zapflix-checkout.jomik8.easypanel.host` | Checkout Vite | Cliente final (PIX) | — (público) |

`NEXTAUTH_URL=https://app.sharkpanel.com.br` (env do container web).
`PUBLIC_WEBHOOK_BASE_URL=https://app.sharkpanel.com.br` — webhooks Evolution chegam aqui.

> **⚠️ CLAUDE.md desatualizado:** ele cita `appcineflick.com.br` como URL principal. A produção atual usa `sharkpanel.com.br`. Comentário no webhook AmploPay (`route.ts:107`) ainda menciona o domínio antigo.

### 1.3 — Variáveis de ambiente (extraídas do container `wp_zapflix-web`)

**Críticas:**
```
DATABASE_URL=postgresql://zapflix:<redacted>@wp-zapflix-db:5432/zapflix
NEXTAUTH_URL=https://app.sharkpanel.com.br
NEXTAUTH_SECRET=<64-hex>
AUTH_SECRET=zapflix-super-secret-key-2026     # legado
AUTH_TRUST_HOST=true
EVOLUTION_API_URL=http://evolution-api-2:8080
EVOLUTION_API_KEY=429683C4C977415CAAFCCE10F7D57E11
REDIS_URL=redis://wp-zapflix-redis:6379
REDIS_HOST=wp-zapflix-redis
PUBLIC_WEBHOOK_BASE_URL=https://app.sharkpanel.com.br
WEBHOOK_TOKEN=<64-hex>
PAYMENT_WEBHOOK_SECRET=<64-hex>
AMPLOPAY_WEBHOOK_TOKEN=i8rz0ljm
CRON_TOKEN=<48-hex>
ROTATION_API_KEY=zapflix_<32-hex>
ADMIN_MIGRATION_SECRET=zapflix-migration-2026
```

**Storage / S3:**
```
S3_PUBLIC_ENDPOINT=https://wp-zapflix-minio.jomik8.easypanel.host
S3_PUBLIC_BASE_URL=https://wp-zapflix-minio.jomik8.easypanel.host/zapflix-media
S3_ACCESS_KEY=zapflixadmin
S3_SECRET_KEY=Zapfl1x@M1n10
```

**Resíduos Supabase (não devem ser usados):**
```
NEXT_PUBLIC_SUPABASE_URL=http://wp-zapflix-postgrest:3000
NEXT_PUBLIC_SUPABASE_ANON_KEY=<JWT>
SUPABASE_SERVICE_ROLE_KEY=<JWT>
```

> ⚠️ Várias secrets têm baixa entropia ou são valores estáticos comprometidos (`AUTH_SECRET`, `ADMIN_MIGRATION_SECRET`, `S3_SECRET_KEY`). Rotação está pendente — ver SECURITY.md em `/root/Zapflix-Tech`.

---

## Seção 3 — Sidebar e menus por papel

Definidos em `components/layout/sidebar-nav.tsx` (workspace) e `components/layout/master-sidebar.tsx` (master).

A constante `NAV_CATEGORIES` é a única fonte de verdade do sidebar do workspace. Cada item carrega:
- `roles?: string[]` → quem vê (default = todos os logados)
- `module?: keyof ModulesSettings` → gating por plano
- `permissionKey?: string` → gating por `feature_access`
- `superAdminOnly?: boolean` → só superadmin
- `badge?: 'inbox' | 'trials' | 'redemptions'` → contador na lateral

### 3.1 — Sidebar do workspace (`/...`)

| Categoria | Item | Rota | Roles | Módulo |
|---|---|---|---|---|
| **Atendimento** | Dashboard | `/` | todos | — |
| | Inbox | `/inbox` | todos | — |
| | Contatos | `/contacts` | todos | — |
| | Tickets | `/tickets` | todos | — |
| | Blacklist | `/blacklist` | owner, admin | — |
| **Canais** | Instâncias WhatsApp | `/whatsapp-instances` | owner, admin | — |
| | Webchat | `/webchat-settings` | owner, admin | `webchat` |
| **Vendas** | Vitrine | `/netflix-store` | owner, admin | — |
| | Catálogo | `/products` | owner, admin | — |
| | Cupons | `/coupons` | owner, admin | — |
| | Pedidos | `/pedidos` | owner, admin | — |
| | Recorrência | `/recorrencia` | owner, admin | — |
| | Faturamento | `/billing` | owner, admin | — |
| **IPTV** | Trials IPTV | `/trials` | owner, admin | `iptv_trials` |
| | Apps IPTV | `/iptv-apps` | owner, admin | `iptv_trials` |
| | Planos IPTV | `/iptv-plans` | owner, admin | `iptv_trials` |
| **Automação** | Grupos & Massa | `/groups` | owner, admin | `groups_bulk` |
| | Campanhas | `/campaigns` | owner, admin | `campaigns` |
| | Automações | `/automations` | owner, admin | `campaigns` |
| | Funil Guiado | `/guided-funnels` | owner, admin | `guided_funnel` |
| | Templates | `/templates` | owner, admin | — |
| | Agendamentos | `/agendamentos` | owner, admin | `campaigns` |
| **IA** | IA & Agentes | `/ai` | owner, admin | `ai_agents` |
| | Estúdio IA | `/ai-studio` | owner, admin | `ai_studio` |
| | Assistente IA | `/ai-assistant` | owner, admin | — |
| | Cérebro de Vendas | `/sales-brain` | owner, admin | `ai_agents` |
| | Conhecimento (RAG) | `/knowledge` | owner, admin | `ai_agents` |
| **Minha Conta** | Minha Performance | `/gamification` | agent | — |
| | Meu Perfil | `/profile` | agent | — |
| **Analytics** | Visão Geral | `/analytics` | owner, admin | — |
| | Instâncias | `/analytics/instances` | owner, admin | — |
| | Monitoramento | `/monitoring` | owner, admin | — |
| **Equipe** | Performance | `/gamification` | owner, admin | — |
| | Usuários & Permissões | `/users` | owner, admin | — |
| **Revendedor** | Painel Revendedor | `/reseller` | todos (gated por `resellers.user_id`) | — |
| | Créditos | `/reseller/creditos` | reseller | — |
| | **Meus Clientes** ⭐ | `/reseller/clientes` | reseller | — (Fase 2.2 — 29/04) |
| | Meus Revendedores | `/resellers` | owner, admin | — |
| **Configurações** | Configurações | `/settings` | owner, admin | — |
| | Meu Plano | `/meu-plano` | owner | — |
| | Meu Setup | `/meu-setup` | owner, admin, agent | — |
| | Loja de Módulos | `/store` | owner, admin | — |
| | Ajuda | `/help` | todos | — |
| **Desenvolvedor** | API & Tokens | `/api-tokens` | owner, admin | — |
| | Webhooks | `/webhooks` | owner, admin | — |
| | Logs de Auditoria | `/audit-log` | owner, admin | — |
| **Interno** | Painel Master | `/master` | superadmin | — |
| | Mapa de Workspaces | `/workspaces-map` | superadmin | — |
| | Sigma | `/sigma` | superadmin | `iptv_trials` |

### 3.2 — Sidebar Master (`/master/*`)

Definida em `components/layout/master-sidebar.tsx`. Acesso bloqueado server-side em `app/(master)/layout.tsx` por `isSuperAdmin()` (redireciona pra `/`).

```
Dashboard          /master
Workspaces         /master/workspaces
Pessoas            /master/pessoas         (Clientes / Funcionários / Revendedores)
Revendedores       /master/revendedores
Financeiro         /master/financeiro
Planos             /master/planos
Monitoramento      /master/monitoramento
Tickets            /master/tickets
Trials             /master/trials
Jobs               /master/jobs
Blacklist Global   /master/blacklist
Agentes IA         /master/ai-agents
Configurações      /master/configuracoes
```

### 3.3 — Layouts e shells

```
app/layout.tsx                          # root (auth provider)
app/(dashboard)/layout.tsx              # SWRProvider + WorkspaceProvider + WhitelabelProvider + AppShell
app/(master)/layout.tsx                 # gated por isSuperAdmin() → MasterShell
```

`AppShell` está em `components/layout/app-shell.tsx`. Top-bar em `app-topbar.tsx` e `top-bar.tsx`. Painel lateral de notas em `workspace-notes-panel.tsx`. Header de página reutilizável em `page-header.tsx` / `page-template.tsx`.

---

## Seção 8 — Workspaces multi-tenant

### 8.1 — Workspaces existentes em prod (29/04/2026)

| UUID | Slug | Nome | Membros | Criado |
|---|---|---|---|---|
| `00000000-0000-0000-0000-000000000001` | `superadmin-sistema` | Superadmin Sistema | 0 | 2026-04-28 |
| `00000000-0000-0000-0000-000000000002` | `shark-panel` | **Shark Panel** | 3 | 2026-02-21 |
| `4e437249-b2cb-4572-a4ff-44f3f89d24d0` | `fabrica` | Fábrica | 1 | 2026-03-30 |
| `09711328-25e0-4d06-94f1-5b1afc42e070` | `iphone` | Iphone | 1 | 2026-04-02 |
| `21461c56-3f40-40d2-8c42-00c6b1ba4c5f` | `shark` | Shark | 1 | 2026-04-17 |
| `625bb524-7a8e-4e95-b3e7-6718fd8b216a` | `diario-das-bruxas` | Diario-das-Bruxas | 2 | 2026-04-23 |

> **Mudança importante:** o workspace principal **`00000000…0002` foi renomeado de "Uniflix" para "Shark Panel"** (slug `shark-panel`). O CLAUDE.md ainda cita "Uniflix" — desatualizado.
> O `display_name` do `sigma_servers` ainda é `UNIFLIX` (legado, não impacta funcionamento).

### 8.2 — Como o isolamento funciona

- Praticamente toda tabela tem coluna `workspace_id uuid` com FK para `workspaces.id` ON DELETE CASCADE (algumas com `SET NULL`).
- Resolver workspace ativo: helper `getActiveWorkspaceId()` / `getWorkspaceIdSafe()` em `lib/auth/getActiveWorkspaceId.ts` — combina sessão + cookie + lookup em `workspace_memberships`.
- Superadmin tem bypass: `getAuthContext()` em `lib/auth/rbac.ts` força `role='owner', plan='enterprise'` para qualquer workspace.
- Há políticas RLS antigas em algumas tabelas (`workspaces_select_member`, etc.) que dependem de funções `is_workspace_member()` e `get_workspace_role()` — mas a role `zapflix` tem `BYPASSRLS`, então não enforced. **Não confiar em RLS.** Usar sempre `WHERE workspace_id = $X` na aplicação.

### 8.3 — Recursos por workspace

- `workspace_settings` (JSONB chave-valor) — settings genéricos
- `workspace_settings/<area>` — endpoints dedicados (auto-close, payment-messages, receipt-template, etc.)
- `workspace_plans` + `workspace_plan_payments` + `workspace_subscriptions` — billing do tenant
- `workspace_memberships` — usuários com `role` (owner/admin/agent/viewer)
- `whitelabel_settings` (logo, cores, domínio próprio)
- `sigma_servers` per-workspace — porém em prod só existe **1 servidor global** (workspace `…0002`, `is_global=true`)
- `special_iptv_plans` per-workspace (planos do reseller via créditos)
- `checkout_plans` per-workspace (key suffix `-<workspaceId[:8]>`) — fonte canônica em `00000000…0002`, replicado pra outros tenants

---

## Seção 9 — Features ativas em produção

### F-001 — Sistema de Afiliados / Revendedores

| Fase | Status | Data |
|---|---|---|
| **Fase 1** — Cadastro de reseller, dashboard básico, comissões em centavos | ✅ Live | — |
| **Fase 2** — Compra de créditos via PIX (AmploPay) | ✅ Live | — |
| **Fase 2.2** — Reseller ativa cliente IPTV via crédito (`POST /api/resellers/clients/activate`) | ✅ **Live 29/04/2026** | F-001 Fase 2.2 |
| Fase 3+ | 🟡 Não definida | — |

**Tabelas:** `resellers`, `reseller_credit_ledger`, `reseller_commissions`, `reseller_sales`, `reseller_withdrawals`, `reseller_levels`, `reseller_adjustments`, `commission_settings`, `special_iptv_plans`.

**Rotas principais:**
- Página: `/reseller`, `/reseller/creditos`, `/reseller/clientes`
- API: `/api/resellers/clients`, `/api/resellers/clients/activate`, `/api/resellers/credits/{balance,ledger,purchase}`, `/api/resellers/{me,my-sales,withdraw,register,public-signup,lookup,list}`

**Ledger:** `reseller_credit_ledger` é imutável. Cada movimento grava `kind ('purchase'|'usage'|'adjust'…), amount (signed), balance_after, special_plan_id, months_sigma_activated, performed_by`. Saldo está em `resellers.iptv_credits` (lock `FOR UPDATE` antes de débito) e `resellers.balance_cents` (comissão saca-vel em real).

### F-002 — Manual estilo Netflix
- Status: **Specado** (em backlog)
- Tempo estimado: 3-4h
- Sem pré-requisitos

### F-003 — Landing + Quiz Whitelabel
- Status: **Specado** em `/root/spec-f003-landing-quiz.md`
- Tempo: ~12-15h (MVP) — 6 tabelas novas, 5 perfis de cliente, algoritmo de detecção
- Pré-requisito: F-001 Fase 2.2 ✅

### Inbox / WhatsApp
- Conversas, mensagens, status (sent/delivered/read), tags, ai-mode por conversa, ai-suggestion, archive/block/mute/pin/favorite, transferência entre agentes/instâncias, schedule message, send-product, charge-pix, summarize, typing, SSE em `/api/sse/inbox`.
- Tabelas: `conversations`, `messages`, `contacts`, `contact_tags`, `tags`, `quick_replies`, `conversation_funnels_sent`, `conversation_transfers`.

### Checkout público
- Página: `/comprar?ref=<referral_code>` → cria order → AmploPay PIX → polling `/api/checkout/status/[id]`
- Webhook: `/api/payments/amplopay-webhook` (recebe direto da AmploPay, autenticado por `AMPLOPAY_WEBHOOK_TOKEN` no payload)
- Provisão: `provisionSigmaCustomer()` por `planKey` (lookup em `sigma_plan_mapping`)

### Automações
- Triggers (texto, quick, programados), funis guiados (`xyflow/react`), drip campaigns, follow-up, cancel-funnel, generate-audio.
- Tabelas: `automations`, `automation_steps`, `automation_triggers`, `text_triggers`, `quick_trigger_config`, `guided_funnels`, `guided_funnel_steps`, `guided_funnel_sessions`, `drip_campaigns`, `drip_campaign_steps`, `drip_campaign_enrollments`.

### IA
- Agentes, app-flow, knowledge bases (`knowledge_bases`, `knowledge_chunks`, `knowledge_documents`, `knowledge_items`), assistente, transcribe, vision/analyze.
- Provider settings em `ai_provider_settings` + ElevenLabs em `elevenlabs_settings`/`elevenlabs_voices`.

### Gamification
- XP, badges, levels, leaderboard.
- Tabelas: `agent_levels`, `agent_xp_log`, `agent_badges`, `agent_performance_daily`, `agent_commissions`.

### Outras features ativas
- Tickets internos (`tickets`, `ticket_messages`, `ticket_resolution_config`)
- Workspace Notes (`workspace_notes`)
- Internal chat (`internal_messages`, `internal_credits_transactions`)
- Webchat público (widget Lovable) — `/api/webchat/*`, `webchat_settings`, `webchat_sessions`, `webchat_blocked_ips`, `webchat_plans`
- Trial web público (`/trial/web`) → cria iptv_trial sem auth, CORS aberto
- Short links (`short_links`, `lib/short-url.ts`) — ⚠️ usa `Math.random()`, PRNG previsível

---

## Seção 11 — Cron jobs / background tasks

**Definição:** `Dockerfile.cron` → `/etc/crontab.supercronic`. Cada linha chama `/usr/local/bin/run-crons.sh <name>` que faz `curl` para `/api/cron/<name>` com header `x-cron-secret`.

**Auth:** todas as rotas em `/api/cron/*` checam header `x-cron-secret` contra `CRON_TOKEN` env. Excluídas do middleware NextAuth (em `EXCLUDED_PREFIXES`).

### 11.1 — Crons agendados (rodando)

| Cadência | Endpoint | Função |
|---|---|---|
| `* * * * *` (cada min) | `scheduled-messages` | Dispara mensagens agendadas |
| `* * * * *` | `funnel-processor` | Avança steps de funis guiados |
| `* * * * *` | `process-bulk-send` | Processa envios em massa |
| `*/5 * * * *` | `check-webhook-tokens` | Audita tokens de webhook Evolution |
| `*/5 * * * *` | `check-worker-alerts` | Alerta se worker travou |
| `*/5 * * * *` | `drip-event-triggers` | Dispara drips por evento |
| `*/15 * * * *` | `check-instance-health` | Health-check por instância WhatsApp |
| `*/15 * * * *` | `drip-campaigns` | Avança steps de drip campaigns |
| `*/30 * * * *` | `pix-followup` | Follow-up de PIX não pago |
| `0 * * * *` | `metrics-snapshot` | Snapshot horário de métricas |
| `0 */2 * * *` | `abandoned-cart` | Carrinho abandonado |
| `0 */4 * * *` | `follow-up` | Follow-up genérico |
| `30 0 * * *` | `increment-warmup-day` | Avança dia de warmup das instâncias |
| `0 1 * * *` | `promote-expired-trials` | Promove trials vencidos a clientes |
| `0 3 * * *` | `sync-instance-profiles` | Sincroniza profile_pic/name das instâncias |
| `0 3 * * *` | `close-inactive` | Fecha conversas inativas |
| `0 5 * * *` | `sigma-backfill-24h` | Backfill últimas 24h Sigma |
| `0 6 * * *` | `purge-jobs` | Limpa jobs concluídos antigos |
| `15 6 * * *` | `metrics-snapshot-daily` (não há rota — usa `metrics-snapshot`) | Snapshot diário |
| `0 7 * * *` | `renewal-check` | Verifica renovações pendentes |
| `0 8 * * *` | `plan-expiry` | Notifica plans expirando |
| `0 10 * * *` | `trial-followup` | Follow-up dos trials |
| `0 4 * * 0` | `db-retention` | Retenção de logs no banco |
| `0 9 * * 1` | `weekly-report` | Relatório semanal |
| `0 3 * * 0` | `reseller-levels` | Recalcula níveis dos resellers |
| `0 1 1 * *` | `monthly-payroll` | Folha mensal |
| `0 2 1 * *` | `reseller-billing` | Cobrança mensal de plano dos resellers |

### 11.2 — Crons existentes mas NÃO agendados

Endpoints presentes em `/api/cron/*` mas sem entrada no Dockerfile.cron:
- `/api/cron/abandoned-cart` (existe rota, está no crontab — OK)
- `/api/cron/check-instance-health` (idem)

(Cross-check: todos os 26 endpoints listados em `/tmp/api-routes.txt` `cron/*` aparecem no crontab; nenhum órfão detectado nesta auditoria.)

### 11.3 — Worker (não-cron, processa fila Postgres)

`apps/worker/src/worker.ts` (~7.669 linhas, monolítico). Loop:

```sql
SELECT * FROM jobs
WHERE status='pending' AND run_at <= NOW()
FOR UPDATE SKIP LOCKED LIMIT 1;
```

Status transitions: `pending → running → succeeded | failed | dead`. Após N tentativas (`max_attempts`, default 3) → `dead`.

**Tipos de job (12):** ver Seção 1.1.

---

## Seção 12 — Segurança e auditoria

### 12.1 — `audit_logs`

Tabela com **1.459.260 linhas** (~347 MB, sem retenção configurada — cron `db-retention` existe mas não tem regra para `audit_logs`).

Colunas notáveis: `workspace_id`, `user_id`, `user_name`, `user_email`, `action`, `entity_type`, `entity_id`, `summary`, `level (info/warn/error)`, `payload jsonb`, `details jsonb`, `ip_address inet`, `user_agent`, `timestamp`.

**Quem grava:** helper `logAudit()` em `lib/server/audit.ts` é fire-and-forget. Chamado por:
- Rotas master (qualquer `/api/admin/*` e `/api/master/*` que muda estado)
- Reseller activate (`clients.activate.requested`, `clients.activate.failed`, `clients.activate.success`)
- Login / signup / reset-password
- Workspace ações destrutivas (deletar contato, instância, etc.)

### 12.2 — Senhas

- Hash: **bcrypt** via `bcryptjs`, cost = **12** (signup, change-password, reset-password)
- Política atual: **mínimo 6 caracteres**, sem checagem de complexidade
- Implementada em 4 lugares (sem helper centralizado):
  - `app/api/auth/signup/route.ts:33`
  - `app/api/profile/route.ts:54` (campo `new_password`)
  - `app/api/resellers/register/route.ts:21`
  - `app/registro/page.tsx:23`
- Reset flow: `/esqueci-senha` → `password_reset_tokens` (TTL típico 1h) → `/resetar-senha?token=…`
- ⚠️ Política proposta para upgrade: 10 chars + 1 maiúscula + 1 número (spec em `/root/password-policy.md`)

### 12.3 — Tokens de sessão

- **JWT mode** do NextAuth v5 — sem registros em `nextauth_sessions` (vazia em prod)
- Cookie `__Secure-authjs.session-token` (HTTP-only, SameSite=lax, Secure em prod)
- Expiração: padrão NextAuth (30 dias)
- Renovação: silent refresh em cada request via callback `jwt({ token, user, trigger })` (re-busca dados do banco em `update`)
- `AUTH_TRUST_HOST=true` (necessário atrás de proxy reverso Traefik)

### 12.4 — Tokens / secrets sensíveis no banco

| Tabela | Coluna | Conteúdo | Como protegido |
|---|---|---|---|
| `sigma_servers` | `token`, `user_id` | Credenciais do painel Sigma | **Plaintext.** Visível para qualquer query com role `zapflix` |
| `whatsapp_instances` | (sem token; auth feita por `EVOLUTION_API_KEY` global) | — | Header `apikey` configurado no app |
| `checkout_config` | `value` (rows `amplopay_public_key`, `amplopay_secret_key`) | Credenciais AmploPay por workspace | **Plaintext** |
| `api_tokens` | `token_hash` | Tokens de API externa | Hash (sha256) |
| `password_reset_tokens` | `token` | Token de reset | Plaintext + TTL curto |
| `nextauth_users` | `password` | Hash bcrypt | OK |

> **Risco:** quem ganha acesso de leitura ao banco lê tokens Sigma e AmploPay direto. Documentado em SECURITY.md.

### 12.5 — Endpoints sem autenticação (em `EXCLUDED_PREFIXES`)

Muitos protegidos por header próprio (token na rota), mas dois grupos são `EXCLUDED` E não têm auth interna em alguns endpoints:

⚠️ **Risco alto:**
- `/api/debug/*` — sem auth
- `/api/migrate/*` — sem auth (apesar de `/api/migrate/run-migration` exigir `x-admin-secret`, vários sub-endpoints não)
- `/api/notifications` — sem auth (CLAUDE.md flagged)

**Protegidos por header:**
- `/api/admin/run-migration`, `/api/admin/audit`, `/api/admin/job-analysis`, `/api/admin/test-*`, `/api/admin/media-debug`, `/api/admin/requeue-dead-jobs` → `x-admin-secret` = `ADMIN_MIGRATION_SECRET`
- `/api/cron/*` → `x-cron-secret` = `CRON_TOKEN`
- `/api/external/*` → `x-api-key` (per-token em `api_tokens`)
- `/api/internal/*` → `x-internal-token` = `CRON_TOKEN`
- `/api/notifications` → `x-internal-token`
- `/api/rotation/*` → `ROTATION_API_KEY`
- `/api/payments/webhook` → `PAYMENT_WEBHOOK_SECRET`
- `/api/payments/amplopay-webhook` → token no payload JSON (`AMPLOPAY_WEBHOOK_TOKEN`)

---

## Seção 13 — Bugs conhecidos

### 13.1 — Resolvidos recentemente

| ID | Descrição | Resolvido em |
|---|---|---|
| **B-PARSER-001** | Sigma retorna data `DD/MM/YYYY HH:MM:SS`, Postgres TIMESTAMPTZ rejeitava — fix `parseSigmaDate()` em `lib/sigma/provision.ts` | 29/04/2026 |
| **B-001 a B-005** | (sessões anteriores — ver `/root/auditoria-noturna.md`) | — |
| **D-WA-003** | Bruninhahh (não detalhado) | 29/04/2026 |
| **INSERT subscription engolia erros** | `try/catch` com `console.warn` — fix: agora retorna 500 com creds no payload pra backfill manual | 29/04/2026 |

### 13.2 — Abertos com prioridade

| ID | Descrição | Prioridade | Localização |
|---|---|---|---|
| **B-009** | `annual` e `semiannual` em `special_iptv_plans` apontam pro mesmo `sigma_package_id=RYAWRk1jlx` (3 meses) → clientes anual/semestral recebem 3m de IPTV | **MÉDIA** | `/root/b-009-sigma-ids.md` (SQL pronto, não executado) |
| **B-AMPLOPAY-001** | Webhook AmploPay grava credenciais Sigma só no `payments.metadata` JSONB; `subscriptions.iptv_username/password/server/expires_at` ficam NULL | **MÉDIA-ALTA** | `app/api/payments/amplopay-webhook/route.ts:1141, 1418-1442` |
| **B-006** | 3 rotas AmploPay legadas | ALTA | (não detalhado nesta auditoria) |
| **B-008** | `buildSigmaMessage` duplicado | BAIXA | — |
| **B-004-rest** | 4 callers restantes do bug B-004 | BAIXA | — |
| **D-WA-001 / D-WA-002** | Colunas WhatsApp latentes | MÉDIA | — |
| **D-SIGMA-painel** | Visibilidade do reseller no painel admin Sigma | BAIXA | — |
| **BUG-001 a BUG-008** | Cross-tenant sync, triggers (CLAUDE.md) | — | — |

### 13.3 — Em investigação

- **Painel admin sharks10.top vs token Zapflix** — Vinicius vê cliente "real" sob reseller `adm-shark`, mas o sistema marca cliente teste como `super-sharkstreaming`. Possível mismatch de sub-conta no token de `sigma_servers`.

---

## Seção 14 — Roadmap

### F-001 Afiliados
- Fase 1 ✅ — cadastro reseller, dashboard, comissões
- Fase 2 ✅ — compra de créditos via PIX (AmploPay)
- Fase 2.2 ✅ — ativação cliente IPTV via crédito (29/04/2026)
- Fase 3 — proposta em aberto
- Fase 4-6 — não definidas

### F-002 — Manual estilo Netflix
- Status: SPECADO (sem arquivo confirmado nesta auditoria)
- Tempo: 3-4h
- Pré-requisito: nenhum

### F-003 — Landing + Quiz
- Status: SPECADO em `/root/spec-f003-landing-quiz.md`
- Tempo: 12-15h versão completa, 12h MVP Uniflix hardcoded
- 6 tabelas (`landing_pages`, `quizzes`, `quiz_questions`, `quiz_answers`, `quiz_profiles`, `quiz_responses`)
- 5 perfis de cliente (Maratonista, Esportista, Família, Curioso, Testador)
- Pré-requisito: F-001 Fase 2.2 ✅

### Outros itens em backlog
- Política senha forte (10 chars + 1 maiúscula + 1 número) — spec em `/root/password-policy.md` (~30-45min)
- Aplicar fixes B-009, B-AMPLOPAY-001 — depende de aprovação
- Promover `reseller_levels.level` para enum nativo (opcional — coluna varchar já existe)
- Fechar portas expostas (5433, 6379, 9000, 33060, 8000, 8443) — CLAUDE.md
- Adicionar auth em `/api/debug/*`, `/api/migrate/*`, `/api/notifications`
- Rotacionar credenciais expostas
- Desligar stack Supabase legado (`supabase-docker`)
- Configurar backups automáticos (existe `backup.sh` em `/root`, mas precisa scheduling)
- Reativar `zapflix-monitor` (Flask, OFFLINE há 3+ semanas)

---

## Seção 15 — Como o sistema é deployado

### 15.1 — Build process

```bash
cd /root/Zapflix-Tech
docker build -t zapflix-tech:latest . > /tmp/build.log 2>&1
```

- Dockerfile principal: `next build` com `output: 'standalone'`
- Worker tem Dockerfile separado (`Dockerfile.worker`) — imagem `easypanel/wp/zapflix-worker:latest` é construída pelo Easypanel build pipeline (não pelo Vinicius local)
- Cron tem Dockerfile separado (`Dockerfile.cron`) — imagem `easypanel/wp/zapflix-cron:latest`

### 15.2 — Deploy process

```bash
# Force redeploy do serviço web (com a imagem nova local)
docker service update --force --image zapflix-tech:latest wp_zapflix-web

# Worker (Easypanel rebuild via UI ou):
docker service update --force wp_zapflix-worker

# Cron
docker service update --force wp_zapflix-cron
```

### 15.3 — Health checks

- `GET /api/health` — público (sem auth), retorna `{ ok: true, ts }`
- `GET /api/health/full` — protegido por session OU `x-api-key`, valida DB, Redis, Evolution API

```bash
curl https://app.sharkpanel.com.br/api/health
```

### 15.4 — Logs

```bash
docker service logs wp_zapflix-web    --follow --tail 50
docker service logs wp_zapflix-worker --follow --tail 50
docker service logs wp_zapflix-cron   --follow --tail 50
```

Logger: `pino` (JSON estruturado) em `lib/logger.ts`. Sem retenção persistente — só stdout do container Docker.

### 15.5 — Rollback

```bash
docker service update --rollback wp_zapflix-web
```

---

## Seção 16 — Vinicius cheat sheet

```bash
# Ver containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Logs em tempo real
docker service logs wp_zapflix-web --follow --tail 50

# Health check público
curl https://app.sharkpanel.com.br/api/health

# psql interativo
docker exec -it $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix

# Top tabelas por tamanho
docker exec $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix -c "
  SELECT relname, pg_size_pretty(pg_total_relation_size(oid))
  FROM pg_class WHERE relkind='r' AND relnamespace=2200
  ORDER BY pg_total_relation_size(oid) DESC LIMIT 20;"

# Jobs status
docker exec $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix -c "
  SELECT type, status, count(*) FROM jobs GROUP BY type, status
  ORDER BY status, count DESC;"

# Build + deploy do web
cd /root/Zapflix-Tech
docker build -t zapflix-tech:latest . > /tmp/build.log 2>&1
docker service update --force --image zapflix-tech:latest wp_zapflix-web

# Rollback
docker service update --rollback wp_zapflix-web

# Backup do Postgres (script existe)
/root/backup.sh
ls -la /root/backups/

# Recriar dotenv local (não usado em prod)
cp /root/Zapflix-Tech/.env.example /root/Zapflix-Tech/.env.local

# Listar rotas /api
find /root/Zapflix-Tech/app/api -name route.ts | sed 's|.*/api/||;s|/route.ts$||' | sort
```

---

## Seção 17 — Glossário

| Termo | Significado |
|---|---|
| **workspace** | Tenant isolado (Shark Panel, Iphone, Fábrica, Shark, Diario-das-Bruxas, Superadmin) |
| **owner** | Dono do workspace (role na `workspace_memberships`) |
| **admin** | Admin do workspace (acesso quase total, exceto destruir o workspace) |
| **agent** | Atendente — só vê inbox, contatos, tickets, sua performance |
| **viewer** | Ainda inferior a agent (definido em `ROLE_HIERARCHY`, raramente usado) |
| **superadmin** | Role global em `nextauth_users.role`. Bypass total. Acessa `/master/*`. UUID legado: `00000000-0000-0000-0000-000000000001` |
| **reseller** | `resellers.type='reseller'` — vende IPTV pra clientes finais usando créditos |
| **affiliate** | `resellers.type='affiliate'` — variação que também ativa clientes |
| **subscription** | `subscriptions` row — assinatura IPTV ativa de um cliente |
| **contact** | `contacts` row — pessoa com quem se conversa (chave: workspace_id + phone_e164) |
| **conversation** | `conversations` row — thread WhatsApp/webchat com 1 contact, 1 instance |
| **whatsapp_instance** | Número WA conectado via Evolution. Tem `instance_type` (atendimento/payment_confirmation/etc.), `warmup_day`, `daily_limit` |
| **sigma_server** | Servidor Sigma cadastrado pra provisão IPTV (em prod só há 1, global). `panel_url=https://sharks10.top/api`, auth por `token + user_id` |
| **special_iptv_plans** | Planos disponíveis pra reseller comprar e ativar com créditos. 4 slugs: `monthly`, `quarterly`, `semiannual`, `annual` |
| **iptv_credits** | Saldo de créditos do reseller (`resellers.iptv_credits`, integer). 1 crédito ≈ ativação de 1 mês na maioria dos planos |
| **balance_cents** | Saldo de comissão do reseller em centavos (`resellers.balance_cents`). Saca-vel via `reseller_withdrawals` |
| **ledger** | `reseller_credit_ledger` — histórico imutável de débitos/créditos |
| **trial** | Cliente IPTV com plano grátis (2H, 6H, 1D) — `iptv_trials` |
| **package** | Pacote Sigma (1m, 2m, 3m, 6m, 12m). ID nas requisições é `sigma_package_id` |
| **note** | Campo Sigma usado pra busca por phone (`/webhook/customer?note=<phone>`) |
| **m3u** | URL de playlist IPTV pra player externo |
| **Evolution instance** | Identificador no Evolution API (`whatsapp_instances.evolution_instance_id`) |
| **panel admin** | Interface admin externa do Sigma — `https://sharks10.top` (não nossa) |
| **plan_key** | Identificador único de plano de checkout: `<base>-<workspaceId[:8]>` (ex: `mensal-s1-cb2544fc`). Strip do sufixo via `baseKey()` |
| **whitelabel** | Configuração de branding por workspace (`whitelabel_settings`): logo, cores, domínio próprio |
| **module** | Feature gated por plano (em `lib/auth/rbac.ts`). Ex: `iptv_trials`, `campaigns`, `ai_agents` |
| **feature_access** | Tabela com permissões granulares por workspace (gating mais fino que `module`) |
| **EXCLUDED_PREFIXES** | Lista em `middleware.ts` de rotas que NextAuth não protege (webhooks, cron, públicas) |
| **legacy SUPERADMIN_ID** | UUID `00000000-0000-0000-0000-000000000001` — fallback do `isSuperAdmin()` quando `nextauth_users.role` não diz `superadmin` |
