# Módulo: Instâncias WhatsApp

## Responsabilidade
Gerencia conexões WhatsApp via Evolution API — criação, saúde, webhook, rotação.

## Arquivos principais
```
app/api/instances/route.ts              → CRUD instâncias
app/api/instances/[id]/connect/         → conectar (QR code)
app/api/instances/[id]/health/          → status de saúde
app/api/instances/[id]/webhook/         → configurar webhook
app/api/instances/sync-evolution/       → sync com Evolution API
app/api/rotation/                       → rotação de instâncias
app/api/webhook/route.ts                → recebe eventos da Evolution
apps/worker/src/handlers/webhook.ts     → processa webhook
lib/server/instance-failover.ts         → failover automático
components/instances/
```

## Tabelas principais
- `instances` — instâncias cadastradas com `workspace_id`
- `instance_webhooks` — configuração de webhook por instância

## Fluxo de webhook
```
Evolution API → POST /api/webhook → BullMQ → Worker → processa evento
```

## Rotação de instâncias
Quando há múltiplas instâncias, o sistema rotaciona automaticamente
para distribuir carga via `app/api/rotation/`.
