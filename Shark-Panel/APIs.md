# APIs — Referência completa

> Todas as rotas seguem o padrão Next.js App Router em `app/api/<área>/<recurso>/route.ts`.
> Autenticação padrão: NextAuth session via `getWorkspaceIdSafe()`. Filtro `workspace_id` é obrigatório.

## Convenções

- Resposta de sucesso: `{ data: ..., ok: true }` ou `{ data: ... }`
- Resposta de erro: `{ error: string }` com status HTTP apropriado
- Paginação típica: `?page=1&limit=50` retorna `{ data, total, page, limit, totalPages }`

---

## CRM (novo — 2026-05-11)

### Pipelines
| Método | Rota | Body / Query |
|---|---|---|
| GET | `/api/crm/pipelines` | — |
| POST | `/api/crm/pipelines` | `{ name, stages? }` |

### Stages
| Método | Rota | Body / Query |
|---|---|---|
| GET | `/api/crm/pipelines/[id]/stages` | — |
| POST | `/api/crm/pipelines/[id]/stages` | `{ name, color?, is_won?, is_lost? }` |
| PATCH | `/api/crm/pipelines/[id]/stages` | `{ order: [stageId, …] }` |
| PATCH | `/api/crm/stages/[id]` | `{ name?, color?, is_won?, is_lost?, position? }` |
| DELETE | `/api/crm/stages/[id]` | — (bloqueia se houver deals) |

### Deals
| Método | Rota | Body / Query |
|---|---|---|
| GET | `/api/crm/deals` | `?pipeline_id&stage_id&assigned_to&status&search` |
| POST | `/api/crm/deals` | `{ title, value_cents, stage_id, contact_id?, probability?, assigned_to?, expected_close_date?, notes? }` |
| GET | `/api/crm/deals/[id]` | retorna deal + activities |
| PATCH | `/api/crm/deals/[id]` | qualquer campo (mover stage cria activity automática) |
| DELETE | `/api/crm/deals/[id]` | — |

### Activities
| Método | Rota | Body |
|---|---|---|
| GET/POST | `/api/crm/deals/[id]/activities` | `{ type, title, description?, due_at? }` |
| PATCH | `/api/crm/activities/[id]` | `{ done: true/false, title?, description?, type? }` |
| DELETE | `/api/crm/activities/[id]` | — |

### Stats
| GET | `/api/crm/stats?pipeline_id=…` | `{ by_stage, totals, by_seller, forecast_month_cents }` |

---

## Chatbot (novo — 2026-05-11)

| Método | Rota | Body |
|---|---|---|
| GET | `/api/chatbot/flows` | — |
| POST | `/api/chatbot/flows` | `{ name, description?, trigger_type, trigger_value?, instance_id? }` |
| GET | `/api/chatbot/flows/[id]` | retorna flow + recent_sessions |
| PATCH | `/api/chatbot/flows/[id]` | `{ name?, nodes?, edges?, trigger_type?, trigger_value?, status? }` |
| DELETE | `/api/chatbot/flows/[id]` | — |
| POST | `/api/chatbot/flows/[id]/publish` | valida nodes/trigger e seta `status=active` |
| POST | `/api/chatbot/engine` | `{ workspace_id, phone, message, instance_id?, contact_id? }` → `{ actions, session_id, next_node_id, completed }` |

---

## Analytics

| Método | Rota | Query |
|---|---|---|
| GET | `/api/analytics/revenue` | `?period=today/yesterday/7d/30d` |
| GET | `/api/analytics/churn` | — |
| GET | `/api/analytics/funnel` | `?period=…` |
| GET | `/api/analytics/heatmap` | `?period=…` (mensagens) |
| GET | `/api/analytics/conversion-heatmap` | `?days=30` (receita/vendas — novo) |

---

## Contatos

| Método | Rota | Notas |
|---|---|---|
| GET | `/api/contacts` | `?search,page,limit,sortBy,sortOrder,tagId,tagIds,source,role,trialStatus,plan,optedIn,no_tags,dateFrom,dateTo` |
| POST | `/api/contacts` | `{ phone (obrigatório), name, email, company, role, notes, source, opted_in, custom_fields, tags }` |
| GET/PATCH/DELETE | `/api/contacts/[id]` | |
| `/api/contacts/health-score` | | |
| `/api/contacts/tags` | | |

---

## Inbox / Conversas

`/api/inbox/conversations` (GET/POST), `/api/inbox/messages/[id]/*`, `/api/inbox/notes/*`

---

## Automações & Funis

| Rota | Conteúdo |
|---|---|
| `/api/automations/*` | CRUD automações |
| `/api/guided-funnels/*` | Funis guiados |
| `/api/templates/*` | Templates de mensagem |
| `/api/campaigns/*` | Campanhas |
| `/api/agendamentos/*` | Agendamentos |
| `/api/reengajamento/*` | Reengajamento |

---

## IA

`/api/ai/*`, `/api/ai-studio/*`, `/api/ai-assistant/*`, `/api/sales-brain/*`, `/api/knowledge/*`

---

## Crons (30 endpoints — header `x-cron-secret`)

```
abandoned-cart, check-instance-health, check-webhook-tokens, check-worker-alerts,
cleanup-audit-logs, cleanup-module-trials, close-inactive, db-retention,
drip-campaigns, drip-event-triggers, follow-up, funnel-processor,
increment-warmup-day, metrics-snapshot, monthly-payroll, pix-followup,
plan-expiry, process-bulk-send, promote-expired-trials, purge-jobs,
recorrencia-sync, renewal-check, reseller-billing, reseller-levels,
scheduled-messages, sigma-backfill-24h, sync-instance-profiles, sync-pagante-tags,
trial-followup, weekly-report
```

---

## Master (Superadmin)

`/api/master/*` — exige `requireSuperAdmin(request)`. Inclui workspaces, AI agents, marketplace, billing, etc.

---

## Webhooks externos (sem auth)

EXCLUDED_PREFIXES no middleware:
```
/api/webhooks, /api/notifications, /api/checkout, /api/cron, /api/internal,
/api/external, /api/auth/[...], /api/trial/web, /api/webchat,
/api/resellers/public, /api/cadastro, /api/r/[code], /api/pix
```
