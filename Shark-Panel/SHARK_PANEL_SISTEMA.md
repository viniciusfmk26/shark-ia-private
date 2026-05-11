# Shark Panel — Documentação Técnica Completa

> Atualizado: 2026-05-11. Documento mestre do Zapflix Tech / Shark Panel — multi-tenant SaaS para revendedores de IPTV com automação WhatsApp.

## Arquitetura

Multi-tenant com isolamento por `workspace_id`. Cada cliente (revendedor / operadora) tem seu próprio workspace.

```
┌─────────────────────────────────────────────────────┐
│  appcineflick.com.br  (Next.js 16 — wp_zapflix-web) │
└─────────────────────────────────────────────────────┘
              │                       │
              ▼                       ▼
   ┌──────────────────┐      ┌──────────────────┐
   │  Postgres 17      │      │  Evolution API v2 │
   │  (wp_zapflix-db)  │      │  (whatsapp gateway)│
   │  + tabela `jobs`  │      └──────────────────┘
   └──────────────────┘              │
              ▲                       ▼
              │             ┌──────────────────┐
              │             │  Redis (compart.) │
              │             └──────────────────┘
   ┌──────────────────┐
   │  Worker (Node)    │ — polling SKIP LOCKED na fila `jobs`
   │  (wp_zapflix-…)  │
   └──────────────────┘
              │
              ▼
   ┌──────────────────┐
   │  MinIO S3         │ — mídia
   └──────────────────┘
```

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend + API | Next.js 16 (App Router, output=standalone) + React 19 + TypeScript |
| Auth | NextAuth v5 beta (Credentials, JWT) |
| DB principal | PostgreSQL 17 (190+ tabelas, role `zapflix` superuser) |
| Worker | Node.js + TypeScript, fila Postgres SKIP LOCKED |
| Crons | supercronic + 30 endpoints `/api/cron/*` (header `x-cron-secret`) |
| Storage | MinIO S3-compatible (bucket `zapflix-media` público) |
| WhatsApp | Evolution API v2 + Redis compartilhado |
| Checkout | Vite + tRPC, MySQL 8 (sistema separado) |
| Orquestração | Docker Swarm via Easypanel |

## Workspaces & usuários

| Workspace | UUID | Tipo |
|---|---|---|
| Superadmin | `00000000-0000-0000-0000-000000000001` | Sistema |
| Uniflix | `00000000-0000-0000-0000-000000000002` | Operadora principal |
| Iphone / Shark / Diario-das-Bruxas | (gerados) | Teste |

Usuários principais: **Vinicius** (owner/superadmin), **Denise** (admin Uniflix), **Dudu**.

## Banco de Dados (tabelas-chave por área)

### Core
- `workspaces`, `workspace_memberships`, `nextauth_users`
- `contacts` (id, workspace_id, phone, name, email, company, role, source, custom_fields jsonb, tags)
- `contact_tags`, `contact_tag_assignments`
- `conversations`, `messages` (direction `in`/`out`, `from_me`)

### WhatsApp / Atendimento
- `whatsapp_instances`
- `iptv_trials`, `iptv_servers`, `sigma_servers`

### Automação / IA
- `automations`, `automation_steps`, `automation_flow_sessions`
- `guided_funnels`, `guided_funnel_steps`
- `ai_agents`, `ai_followup_*`, `ai_interrupt_*`
- `chatbot_flows`, `chatbot_sessions` — **CHATBOT NOVO**
- `jobs` (fila de processamento)

### CRM (NOVO)
- `crm_pipelines`, `crm_stages`, `crm_deals`, `crm_activities`

### Financeiro
- `checkout_orders` + `checkout_utm`
- `payments` (status confirmed/pending/refunded)
- `resellers`, `reseller_sales`, `reseller_withdrawals`

### Campanhas
- `followup_campaigns` (+ `media_url`, `media_type`)

### Analytics / Gamificação
- `agent_performance_daily`, `agent_levels`
- `link_clicks`, `audit_logs`

## APIs (rotas principais)

Estrutura: `app/api/<área>/<recurso>/route.ts`

### CRM (novo)
- `GET/POST /api/crm/pipelines`
- `GET/POST /api/crm/pipelines/[id]/stages`, `PATCH/DELETE /api/crm/stages/[id]`
- `GET/POST /api/crm/deals`, `GET/PATCH/DELETE /api/crm/deals/[id]`
- `GET/POST /api/crm/deals/[id]/activities`, `PATCH/DELETE /api/crm/activities/[id]`
- `GET /api/crm/stats?pipeline_id=…`

### Chatbot (novo)
- `GET/POST /api/chatbot/flows`
- `GET/PATCH/DELETE /api/chatbot/flows/[id]`
- `POST /api/chatbot/flows/[id]/publish`
- `POST /api/chatbot/engine` (engine runtime — usado pelo worker)

### Analytics (heatmap de conversões — novo)
- `GET /api/analytics/conversion-heatmap?days=30` — matrix 7x24 receita por dia/hora

### Existentes
- `/api/contacts`, `/api/inbox`, `/api/campaigns`, `/api/automations`, `/api/guided-funnels`
- `/api/ai/*`, `/api/ai-studio/*`, `/api/master/*` (superadmin)
- `/api/cron/*` (30 jobs)

## Features implementadas (alto nível)

| Área | Status |
|---|---|
| Inbox multi-canal WhatsApp | ✅ |
| Kanban de contatos | ✅ |
| Funis (Automações + Funil Guiado) | ✅ |
| **CRM com pipeline kanban** | ✅ Bloco 1 (2026-05-11) |
| **Heatmap de conversões** | ✅ Bloco 2 (2026-05-11) |
| **Chatbot visual** | ✅ Bloco 3 (2026-05-11) |
| Campanhas + grupos + agendamento | ✅ |
| Agentes IA + Studio + Cérebro de Vendas | ✅ |
| Portal do cliente + revendedor | ✅ |
| Financeiro / checkout / PIX / AmploPay | ✅ |
| Gamificação (XP, níveis, créditos) | ✅ |
| Analytics (receita, churn, funil, heatmap) | ✅ |
| Trials IPTV (Sigma, Megabox, TPS) | ✅ |

## Padrões de código

- `getWorkspaceIdSafe()` em toda API
- `query()` de `@/lib/db`
- Auditoria via `logAudit({ workspaceId, action, resource })`
- Filtro multi-tenant obrigatório: `WHERE workspace_id = $1`
- Worker usa Postgres SKIP LOCKED, NUNCA BullMQ

## Deploy

```bash
# Type-check (recomendado antes de commitar)
pnpm tsc --noEmit
# Push para main → Easypanel rebuilda
git push origin main
# Forçar redeploy
docker service update --force wp_zapflix-web
docker service update --force wp_zapflix-worker
```

Veja também: `CRM.md`, `CHATBOT.md`, `GAMIFICACAO.md`, `FINANCEIRO.md`, `APIs.md`.
