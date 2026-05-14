# Deep Dives — Automações

## Módulos documentados
- `deep-automations.md` → fluxos de automação (triggers + steps)
- `deep-drip.md` → campanhas drip (sequência de mensagens)
- `deep-followup-scheduled.md` → follow-up agendado
- `deep-funnels.md` → funis guiados
- `deep-ia.md` → IA autônoma e copiloto
- `deep-knowledge.md` → base de conhecimento / RAG
- `deep-sales-brain.md` → Sales Brain (análise de conversas)
- `deep-webchat-recorrencia.md` → webchat e recorrência

## Arquivos principais de automação
```
app/api/guided-funnels/               → funis guiados
app/api/followup/                     → follow-up
app/api/followups/                    → follow-ups agendados
app/api/cron/                         → todos os crons
apps/worker/src/handlers/funnel.ts    → processamento de funil
apps/worker/src/handlers/followup.ts  → processamento follow-up
lib/chatbot/engine.ts                 → motor do chatbot
components/automations/               → UI de automações
```

## Worker (processo separado)
O worker roda em `apps/worker/` e processa jobs via BullMQ/Redis.
Handlers: ai, background, chatbot, delivery, flow, followup, funnel, media, sync, webhook.
