# Sessao Tecnica — 2026-05-01 (Parte 10)

## Resumo
Modelo CRM profissional de inbox, auditoria completa de trials IPTV, aba IPTV em settings.

## 1. Modelo CRM Profissional — commit abfadfc1

### 3 status: open, pending, closed
- Banco: 26 conversas resolved migradas para closed + CHECK constraint
- ALLOWED_STATUSES atualizado
- statusCounts retorna 3 contadores
- Worker: cliente responde → pending/closed → open
- Worker: atendente humano responde → open → pending (bots nao mudam)
- Frontend: aba Pendentes (amber) entre Abertas e Fechadas
- Botoes: Clock (pending), Reabrir, Fechar

## 2. Auditoria Trial IPTV

### Descobertas
- s.trial_followup_delay_hours vem de iptv_servers (config legado por servidor)
- workspace_settings tem caminho novo: settings->'trial_followup'
- Worker usa os dois com prioridade para workspace
- Cron promote-expired-trials VIVO (ultimo promoted_at hoje 05:00)
- Zero trials com status errado no banco
- Duracao do trial vem de guided_funnel_steps.content.trial_duration (default 2h)

## 3. Aba IPTV / Trials em /settings — commit 0d4bec75

### O que foi criado
- components/settings/tabs/iptv-tab.tsx
- Toggle, delay, instancia WA, mensagem com variaveis
- Salva em workspace_settings.settings->'trial_followup'
- Protegido por feature gate iptv
- lib/types/settings.ts: interface TrialFollowupSettings
- lib/constants/default-settings.ts: defaults

## Commits
| Hash | Descricao |
|---|---|
| abfadfc1 | feat(inbox): modelo profissional CRM — status pending |
| 0d4bec75 | feat(settings): aba IPTV com configuracao de followup de trial |

## Pendencias
- Agendar promote-expired-trials no supercronic (hoje nao agendado)
- Auto-close de conversas inativas (open/pending sem resposta por X dias)
