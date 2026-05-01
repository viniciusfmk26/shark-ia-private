# Sessão Técnica — 2026-04-30 (Parte 6)

## Resumo
Trial enforcement, guards de feature em APIs e páginas.

## 1. Trial Enforcement — commits c2bc3455 + 23bbbdbe
- isWorkspaceExpired() em workspace-limits.ts
- Dashboard layout redireciona para /upgrade se expirado
- Bypass para /configuracoes, /upgrade, /billing

## 2. Feature Guards — commit 9aec3c86
- requireFeature() e featureGuard() em lib/server/features.ts
- 137 APIs protegidas: IPTV (25), Campanhas (28), Funis (39), IA (45)
- 11 layouts server-side bloqueando acesso por URL direta

## Commits
| Hash | Descricao |
|---|---|
| c2bc3455 | feat(trial): enforcement de expiracao |
| 23bbbdbe | fix(trial): remover /upgrade standalone |
| 9aec3c86 | feat(features): guards nas APIs e paginas |

## Pendencias
1. Worker nao checa features em jobs de IA/funis
2. Tabelas duplicadas de payment/subscription
