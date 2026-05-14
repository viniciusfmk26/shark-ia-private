# Sessao Tecnica — 2026-05-01 (Parte 12 — Final)

## Resumo
Integracao dos crons HTTP ao worker via setInterval. Limpeza do inbox.

## 1. promoteExpiredTrials — commit 20a4a6e9
- Funcao implementada no worker.ts (espelha /api/cron/promote-expired-trials)
- Roda a cada 15 minutos via setInterval
- Marca promoted_at, atualiza last_message_at da conversa, move sales_opportunity para lost
- Nao duplica follow-up (ja coberto por processTrialFollowups)

## 2. closeInactiveConversations — commit 20a4a6e9
- Funcao implementada no worker.ts (espelha /api/cron/close-inactive)
- Roda a cada 60 minutos via setInterval
- Default: fecha conversas open/pending com last_message_at < NOW() - 48h
- Por workspace: respeita auto_close_days e auto_close_enabled do settings JSONB
- Se cliente responder conversa fechada: reabre automaticamente (CRM pending→open)

## 3. Limpeza do inbox
- 6960 conversas abertas ha mais de 48h sem resposta foram fechadas
- CRON_CUTOFF_DATE foi aplicado preventivamente e removido apos decisao
- A partir de agora o worker fecha automaticamente conversas inativas

## Pendencias resolvidas
- promoteExpiredTrials: era HTTP sem chamador → agora no worker
- closeInactiveConversations: era HTTP sem chamador → agora no worker
- webhook legado /api/payments/webhook: deprecated, aguarda desligamento do checkout externo

## Commits
| Hash | Descricao |
|---|---|
| 20a4a6e9 | feat(worker): promoteExpiredTrials e closeInactiveConversations via setInterval |
