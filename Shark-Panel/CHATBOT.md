# Módulo: Inbox / Atendimento

## Responsabilidade
Gerencia conversas WhatsApp em tempo real — listagem, envio, recebimento, AI, tags, status.

## Arquivos principais
```
app/api/inbox/conversations/[id]/     → ações por conversa (send, archive, assign, tags...)
app/api/inbox/conversations/route.ts  → listagem com filtros
app/api/inbox/send/route.ts           → envio direto
app/api/sse/inbox/route.ts            → stream de eventos em tempo real
components/inbox/conversation-list.tsx
components/inbox/chat-view.tsx
components/inbox/composer.tsx
components/inbox/ai-assistant/       → copiloto e modo autônomo de IA
```

## Fluxo de mensagem recebida
1. Evolution API → `POST /api/webhook/route.ts`
2. Worker processa via `apps/worker/src/handlers/webhook.ts`
3. SSE notifica frontend via `lib/sse-manager.ts`
4. Frontend atualiza via `hooks/usePollingMessages.ts` ou SSE

## Modos de IA
- `manual` → humano responde, IA sugere
- `copilot` → IA sugere, humano aprova
- `autonomous` → IA responde sozinha

## Regras importantes
- Conversas filtradas por `workspace_id` sempre
- Permissões de instância via `lib/auth/getAllowedInstances.ts`
- Tags sincronizadas via `/api/contacts/tags/sync-from-conversations`
