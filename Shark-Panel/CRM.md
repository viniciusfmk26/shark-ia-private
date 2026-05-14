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
