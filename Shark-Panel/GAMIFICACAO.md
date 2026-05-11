# Gamificação — Documentação

> Sistema de XP / níveis / créditos / badges para engajar atendentes e revendedores.

## Tabelas

| Tabela | Conteúdo |
|---|---|
| `agent_levels` | XP, nível, créditos por usuário/workspace |
| `agent_xp_log` | Histórico de eventos de XP (motivo, valor, timestamp) |
| `agent_badges` | Conquistas (badges) dos agentes |
| `agent_performance_daily` | Snapshot diário de métricas (vendas, atendimentos, etc.) |
| `agent_daily_activity` | Atividade diária consolidada |
| `agent_commissions` | Comissões devidas/pagas |
| `gamification_config` | Configuração por workspace (XP por evento, regras) |
| `reseller_levels` | Níveis e regras para revendedores |
| `credit_store_redemptions` | Resgates da loja de créditos |
| `shop_redemptions` | Resgates da loja (versão alternativa) |
| `workspace_goals` | Metas configuradas no workspace |

## Eventos que geram XP (típicos)

| Evento | XP padrão |
|---|---|
| Mensagem enviada | +1 |
| Conversão (venda confirmada) | +50 |
| Resposta dentro de SLA | +5 |
| Resolver ticket | +10 |

Valores configuráveis em `gamification_config`. Aplicação dispara `agent_xp_log` + `UPDATE agent_levels`.

## Páginas

- `/gamification` — overview do agente (XP, nível, badges)
- `/meu-desempenho` — desempenho individual (vendas, atendimentos)
- `/redemptions` — loja de resgates
- `/metas` — metas e progresso
- `/reseller-dashboard` — dashboard de revendedor

## APIs

- `/api/gamification/*` — XP, leaderboard, badges
- `/api/redemptions/*` — resgates
- `/api/goals/*` — metas

## Crons relacionados

- `reseller-levels` — recalcula níveis de revendedores
- `metrics-snapshot` — snapshot diário em `agent_performance_daily`
- `monthly-payroll` — comissões mensais
