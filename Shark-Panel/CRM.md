# CRM — Documentação

> Implementado em 2026-05-11. Pipeline kanban arrastável com deals, atividades, forecast e estatísticas.

## Visão geral

Sistema CRM completo onde cada workspace pode criar múltiplos pipelines, cada um com stages customizáveis. Os deals percorrem os stages até serem fechados (ganhos ou perdidos).

## Tabelas

### `crm_pipelines`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| workspace_id | uuid FK workspaces | ON DELETE CASCADE |
| name | text | |
| is_default | boolean | um por workspace |
| created_at | timestamptz | |

### `crm_stages`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| pipeline_id | uuid FK | ON DELETE CASCADE |
| workspace_id | uuid | denormalizado |
| name | text | |
| color | text | hex (`#06b6d4`) |
| position | integer | ordem horizontal |
| is_won | boolean | stage de ganho |
| is_lost | boolean | stage de perda |

### `crm_deals`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| workspace_id | uuid FK | |
| pipeline_id | uuid FK | |
| stage_id | uuid FK | |
| contact_id | uuid FK contacts | NULL permitido |
| title | text | |
| value_cents | integer | em centavos |
| probability | integer | 0-100, default 50 |
| assigned_to | text | email/id do vendedor |
| expected_close_date | date | |
| notes | text | |
| status | text | `open` / `won` / `lost` |
| lost_reason | text | quando status=lost |
| won_at, lost_at | timestamptz | |
| stage_changed_at | timestamptz | recalcula dias no stage |
| created_at, updated_at | timestamptz | |

### `crm_activities`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| deal_id | uuid FK | ON DELETE CASCADE |
| workspace_id | uuid | |
| type | text | `note` / `call` / `task` / `email` / `system` |
| title | text | |
| description | text | |
| due_at | timestamptz | para tasks |
| done_at | timestamptz | NULL = pendente |
| created_at | timestamptz | |

## Endpoints

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/crm/pipelines` | Lista pipelines com stages e contagens |
| POST | `/api/crm/pipelines` | Cria pipeline (com stages padrão se não passar) |
| GET | `/api/crm/pipelines/[id]/stages` | Lista stages do pipeline |
| POST | `/api/crm/pipelines/[id]/stages` | Cria stage |
| PATCH | `/api/crm/pipelines/[id]/stages` | Reordena `{order: [stageId, …]}` |
| PATCH | `/api/crm/stages/[id]` | Atualiza stage |
| DELETE | `/api/crm/stages/[id]` | Deleta (bloqueia se houver deals) |
| GET | `/api/crm/deals` | `?pipeline_id, stage_id, assigned_to, status, search` |
| POST | `/api/crm/deals` | Cria deal |
| GET | `/api/crm/deals/[id]` | Detalhe + atividades |
| PATCH | `/api/crm/deals/[id]` | Atualiza (mover stage cria atividade automática) |
| DELETE | `/api/crm/deals/[id]` | Deleta deal |
| GET/POST | `/api/crm/deals/[id]/activities` | Atividades do deal |
| PATCH/DELETE | `/api/crm/activities/[id]` | Marcar feita / deletar |
| GET | `/api/crm/stats?pipeline_id=…` | Stats: by_stage, totals, by_seller, forecast |

## Página `/crm`

Localização: `app/(dashboard)/crm/page.tsx`

### Componentes
- **Cards de resumo (topo):** Pipeline, Ganhos mês, Forecast mês, Conversão, Tempo médio
- **Seletor de pipeline** + busca + filtro por vendedor
- **Toggle Kanban / Lista**
- **Kanban:** colunas por stage com drag and drop nativo (HTML5)
  - Card: título, contato, valor, probabilidade, dias no stage, data prevista, vendedor
  - Mover deal: PATCH `stage_id` + atividade `system`
  - Stage `is_won` → status=won; `is_lost` → status=lost
- **Lista:** tabela ordenável + botão **Export CSV**
- **Modal "+ Novo Deal":** form com busca de contato pelo telefone
- **Modal de deal:** edição inline (blur dispara PATCH), atividades com checklist, botões "Ganhar"/"Perder"

## Forecast

`SUM(value_cents × probability / 100)` para deals com `expected_close_date` no mês corrente e `status='open'`.

## Sidebar

Item adicionado em **Atendimento** após "Funil de Vendas": `{ title: 'CRM', href: '/crm', icon: Briefcase, permissionKey: 'contacts' }`.
