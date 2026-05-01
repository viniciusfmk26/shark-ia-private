# Sessão Técnica — 2026-04-30 (Parte 8 — Final)

## Resumo
Novas features de gating, FK entre pagamento e assinatura SaaS.

## 1. Novas Features — commit 14e04d56

### Features adicionadas
| Feature | trial/free | pro/enterprise |
|---|---|---|
| resellers | false | true |
| analytics | false | true |
| api_access | false | true |
| webhooks | false | true |

### O que foi feito
- Banco: 28 linhas inseridas em workspace_features
- lib/server/features.ts: 4 novas FeatureKeys + labels + defaults por plano
- hooks/use-features.ts: tipo ampliado
- Sidebar: gates em /resellers, /analytics, /api-tokens, /webhooks
- Layouts de bloqueio: resellers/, api-tokens/, webhooks/

## 2. FK payment→subscription — commit 14e04d56

- ALTER TABLE workspace_plan_payments ADD COLUMN workspace_subscription_id UUID REFERENCES workspace_subscriptions(id)
- Webhook: apos confirmar PIX, faz UPSERT em workspace_subscriptions e grava subscription.id em workspace_plan_payments

## Commits
| Hash | Descricao |
|---|---|
| 14e04d56 | feat(features): novas features + FK payment subscription |

## Estado final do sistema de feature gating

### 11 features no total
inbox, instances, iptv, ai_responses, funnels, campaigns, webchat, resellers, analytics, api_access, webhooks

### Por plano
| Plano | Features |
|---|---|
| trial | inbox, instances |
| free | inbox, instances |
| pro | tudo exceto enterprise |
| enterprise | tudo |

### Camadas de proteção
1. Sidebar some (frontend visual)
2. Layout server-side redireciona para / por URL direta (14 layouts)
3. 137 APIs retornam 403 por feature desabilitada (backend real)
4. Worker pula jobs skipped se feature desabilitada

## Pendencias restantes (futuro)
- Nenhuma critica — sistema completo
- Possivel: adicionar mais granularidade de features conforme produto evoluir
