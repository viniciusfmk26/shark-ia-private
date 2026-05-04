# Zapflix-Tech — Sessão 4+5 (2026-05-04)

## Contexto
- VPS: 69.62.91.79, EasyPanel + Docker Swarm
- Repo: github.com/viniciusfmk26/Zapflix-Tech
- Workspace teste: shark-panel (00000000-0000-0000-0000-000000000002)

## Commits deployados

| Commit | Feature |
|---|---|
| 77b6660b | Simplificar Meu Negócio |
| cea7d913 | Foto WhatsApp via Evolution |
| f1e102ac | Card "Pedidos hoje" no dashboard |
| e4953de6 | Restaurar Horário de Atendimento |
| 97f7da69 | Pedidos adaptado ao nicho |
| c4b1a9be | NICHO_CONFIG alinhado + infoproduto + produto_fisico |
| 94008e42 | Upload mídia S3 no campo imagem |
| 41c9706b | Toggle canal de suporte por instância |
| 07d9e49f | Feature gating completo no sidebar |
| f6d8152e | Tabela module_trials + getWorkspaceFeatures com UNION |
| 92496e69 | API master GET/POST/DELETE module-trials |
| d0aa5a83 | UI master — aba Módulos & Trials |
| 7b8d42ad | Badge Trial no sidebar + cron cleanup |
| 2145e9bb | Nicho salvo dispara applyDefaultFeatures |
| d2e0eebd | Filtros de status dinâmicos pelo nicho |
| 25da4ccc | Foto WhatsApp corrigida (4 bugs) |

## Arquitetura implementada

### Feature Gating
- workspace_features: módulos permanentes por workspace
- module_trials: módulos temporários com expires_at
- getWorkspaceFeatures faz UNION das duas tabelas
- Workspace nova nasce com inbox + instances apenas
- Nicho salvo chama applyDefaultFeatures automaticamente

### Module Trials (master)
- POST /api/master/module-trials → concede trial por X dias
- DELETE /api/master/module-trials → revoga imediatamente
- Badge "Xd" no sidebar quando trial ≤ 7 dias
- Cron /api/cron/cleanup-module-trials → limpa expirados

### Créditos (mapeamento)
- Créditos IPTV: R$5,00/crédito → 1 ativação = 1 mês
- Créditos workspace: pacotes para IA, ElevenLabs, etc
- São dois sistemas separados

## Backlog próxima sessão
- Whitelabel no checkout (logo/cores do cliente)
- Onboarding guiado (tutorial workspace nova)
- Portal de suporte público
- Ticket automático por compra (fulfillment)
- Corrigir DEFAULT_FEATURES_BY_NICHO se necessário

## Decisões de produto
- Nicho não libera módulo pago automaticamente
- Módulos extras: trial via master ou plano pago
- Toggle "Canal de suporte" por instância WA
- Ticket automático só em instâncias marcadas como suporte
- model_trials: 1 trial por módulo, upsert ao renovar

## Commits adicionais (pós-sessão)

| Commit | Feature |
|---|---|
| 33b22d20 | fix(sidebar): remover exceção ai_studio sempre visível |
| 5b4f149e | fix(settings): gate IPTV no payments + traduzir Segurança e Webhooks |

## Problemas identificados em /settings
- Templates IPTV apareciam para todos os nichos → corrigido
- Seções em inglês (Segurança, Webhooks) → traduzidas
- Estúdio IA aparecia sem feature gate → corrigido
