# Módulo: CRM

## Responsabilidade
Gestão de contatos, deals, pipelines, tags, kanban e health score.

## Arquivos principais
```
app/api/contacts/route.ts              → CRUD contatos
app/api/contacts/[id]/tags/route.ts    → tags por contato
app/api/contacts/tags/route.ts         → gerenciar tags
app/api/contacts/health-score/         → score de saúde
app/api/crm/deals/route.ts             → deals/oportunidades
app/api/crm/pipelines/route.ts         → pipelines
app/api/crm/stages/[id]/route.ts       → etapas do pipeline
app/api/kanban/contacts/route.ts       → visão kanban
components/contacts/
```

## Tabelas principais
- `contacts` — contatos com `workspace_id`
- `contact_tags` — relação contato ↔ tag
- `tags` — tags do workspace
- `crm_deals` — oportunidades
- `crm_pipelines` — funis de vendas
- `crm_stages` — etapas

## Regra de tags
Tags são sincronizadas das conversas via:
`POST /api/contacts/tags/sync-from-conversations`

## Estado 2026-07-11 — CRM replanejado (5 fases NO AR)
Fonte única de verdade: **view `client_360`** (1 linha/contato; plan_status por datas = GREATEST(next_billing_at, iptv_expires_at, plan_expires_at); LTV; churn_risk = vence ≤7d).

```
migrations/20260711_client_360_view.sql       → view (migration manual)
app/api/clientes/route.ts + [id]/route.ts     → lista + ficha
app/(dashboard)/clientes/                     → Fase 1-2 (lista + ficha)
apps/worker/src/lib/crm-sync.ts               → Fase 3: Sales Brain → crm_deals (sync 10min,
                                                 opportunity_id UNIQUE, stale-out 30d, write-back won/lost)
app/(dashboard)/atendimento/ + api/atendimento→ Fase 4: gestão de atendimento (fila honesta,
                                                 produtividade, CSAT, claim, recuperação de abandonados)
app/(dashboard)/ciclo-de-vida/ + api/ciclo-de-vida → Fase 5: buckets, ROI da régua, winback manual
```
Tabelas novas: `winback_outcomes`; colunas novas: `crm_deals.opportunity_id`, `conversations.{abandoned_at,close_reason,claimed_at,abandoned_followup_at}`, `csat_responses.agent_user_id`.
⚠️ A definição de "cliente" da tela /contacts continua na regra antiga (custom_fields.iptv_plan) — migração futura. Detalhes: [[2026-07-11_crm-completo-5-fases]].
