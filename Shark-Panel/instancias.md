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

## Troubleshooting Cloud API (API oficial Meta) — 21/09/2026

**Sintoma clássico:** "vinculei instância + app + API oficial com token de system user, mas nunca funciona". Instâncias aparecem `connected`, mas 0 mensagens, 0 `processed_events`, 0 jobs `process_webhook`.

**Diagnóstico passo a passo (workspace Shark2, BUG-018):**
1. **Não é o workspace.** O verify token do webhook é gerado pelo painel (`cloud_webhook_verify_token` tem `DEFAULT gen_random_uuid()`) e funciona: `GET /api/webhook/cloud?hub.verify_token=<token da instância>&hub.challenge=X` → HTTP 200.
2. **O suspeito é o `cloud_access_token` da instância.** Testar direto na Meta:
   ```bash
   curl "https://graph.facebook.com/v21.0/me?access_token=$TOKEN"
   ```
   - Erro `code 190 subcode 460` ("session invalidated because the user changed their password") = token morto. É o caso típico: o app foi cadastrado com um token VÁLIDO (`meta_apps`), mas a instância foi criada colando OUTRO token de system user que a Meta já havia revogado.
3. **Conferir o token do app** (`meta_apps`): deve ser `SYSTEM_USER`, `expires_at: 0`, com scopes `whatsapp_business_management` + `whatsapp_business_messaging` + `whatsapp_business_manage_events`:
   ```bash
   curl "https://graph.facebook.com/v21.0/debug_token?input_token=$APP_TOKEN&access_token=$APP_TOKEN"
   ```
4. **Fix (opção A, sem recriar):** atualizar `whatsapp_instances.cloud_access_token` com o token do `meta_apps` (mesmo workspace):
   ```sql
   UPDATE whatsapp_instances wi
   SET cloud_access_token = ma.access_token, updated_at = now()
   FROM meta_apps ma
   WHERE ma.id = '<app_id>' AND wi.workspace_id = ma.workspace_id
     AND wi.id IN ('<instance_id_1>','<instance_id_2>');
   ```
5. **Validar pós-fix:** `/me` responde (id/nome) e `GET /<phone_number_id>?fields=display_phone_number,verified_name` enxerga o número da instância.
