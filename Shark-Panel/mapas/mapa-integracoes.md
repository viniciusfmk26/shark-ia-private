# Mapa de Integrações Externas — Shark Panel

> Auditoria de leitura em 2026-04-29.

---

## 1. Sigma (provisão IPTV)

### Identidade
- **URL base padrão:** `https://sharks10.top/api`
- **Credenciais por servidor** (em `sigma_servers`): `token` + `user_id` (account ID no Sigma)
- **Em prod:** 1 único servidor cadastrado
  - `name='Servidor 2'`, `display_name='UNIFLIX'` (legado, não impacta)
  - `panel_url='https://sharks10.top/api'`
  - `is_global=true`, `workspace_id=00000000-0000-0000-0000-000000000002`
  - Outros workspaces caem nesse via fallback

### Endpoints usados (cliente Shark → Sigma)

| Método | Path | Função |
|---|---|---|
| `GET`  | `/webhook/customer?note=<phone>&token=<T>&userId=<U>` | Buscar cliente por telefone (campo "note") |
| `POST` | `/webhook/customer` | Criar cliente (`{name, note, username, password, package, token, userId}`) |
| `POST` | `/webhook/renew` | Renovar (`{username, package, token, userId, note}`) |
| `GET`  | `/webhook/package?token&userId=<U>` | Listar pacotes disponíveis (usado pra catálogo manual) |

Resposta de criação/renovação:
```json
{
  "username": "...",
  "password": "...",
  "expiresAt": "DD/MM/YYYY HH:MM:SS"   // ⚠️ formato BR, parseSigmaDate() converte
}
```

### Localização no código

| Arquivo | Função |
|---|---|
| `lib/sigma/provision.ts` | Toda a lógica de comunicação |
| `lib/sigma/build-message.ts` | Template da mensagem WA com credenciais (suporta override em `workspace.settings.sigma_message`) |

Funções públicas:
- `findSigmaMapping(workspaceId, planKey)` → resolve `sigma_servers` + `sigma_plan_mapping` → `checkout_plans`
- `provisionSigmaCustomer({ workspaceId, planKey, phone, customerName })` → usado pelo webhook AmploPay (F2)
- `provisionSigmaByPackage({ serverId, packageId, customerName, phoneDigits, workspaceId })` → usado pela ativação reseller (F1, Fase 2.2). Pula `sigma_plan_mapping` legado, usa `special_iptv_plans.sigma_package_id` direto

### Catálogo Sigma "COMPLETO COM ADULTOS" (workspace Uniflix/Shark Panel)
```
1 mês   BV4D3rLaqZ   → 1 MÊS  COMPLETO COM ADULTOS 🔞   (em uso ✅ monthly)
2 meses Yen129WPEa   → 2 MESES COMPLETO COM ADULTOS 🔞
3 meses RYAWRk1jlx   → 3 MESES COMPLETO COM ADULTOS 🔞   (em uso ✅ quarterly, ❌ semiannual/annual também)
6 meses VpKDaJWRAa   → 6 MESES COMPLETO COM ADULTOS 🔞   ⭐ correto pra semiannual (B-009)
12 m    o231qzL4qz   → 1 ANO  COMPLETO COM ADULTO 🔞    ⭐ correto pra annual (B-009)
```

Variantes alternativas (sem adultos / UNITV) ver `/root/b-009-sigma-ids.md`.

### Bug ativo
- **B-009** — `annual` e `semiannual` em `special_iptv_plans` apontam pro mesmo `sigma_package_id=RYAWRk1jlx` (3 meses). SQL de fix em `/root/b-009-sigma-ids.md` (não executado).

---

## 2. Evolution API (WhatsApp)

### Identidade
- **URL interna:** `http://evolution-api-2:8080` (rede Docker Swarm)
  - Env: `EVOLUTION_API_URL=http://evolution-api-2:8080`
- **API key global:** `EVOLUTION_API_KEY=429683C4C977415CAAFCCE10F7D57E11` (header `apikey`)
- **Versão:** v2.3.7 (`evoapicloud/evolution-api`)
- **Dependências:** Postgres (`wp_evolution-api-2-db`), Redis compartilhado (`wp_evolution-api-2-redis`)

### Endpoints usados

| Método | Path | Função |
|---|---|---|
| `GET`  | `/instance/fetchInstances` | Lista instâncias |
| `POST` | `/instance/create` | Cria nova instância |
| `GET`  | `/instance/connect/<instance>` | Gera QR code |
| `DELETE` | `/instance/logout/<instance>` | Logout |
| `DELETE` | `/instance/restart/<instance>` | Restart |
| `GET`  | `/chat/findChats/<instance>` | Lista conversas |
| `GET`  | `/chat/findContacts/<instance>` | Lista contatos |
| `GET`  | `/chat/findMessages/<instance>` | Lista mensagens |
| `GET`  | `/chat/findStatusMessage/<instance>` | Status de mensagens (delivered/read) |
| `POST` | `/message/sendText/<instance>` | Enviar texto |
| `POST` | `/message/sendMedia/<instance>` | Enviar imagem/vídeo/doc |
| `POST` | `/message/sendWhatsAppAudio/<instance>` | Enviar áudio WA-style |
| `GET`  | `/webhook/find/<instance>` | Verificar webhook configurado |
| `POST` | `/webhook/set/<instance>` | Configurar webhook |
| `POST` | `/group/create/<instance>` | Criar grupo |

### Webhook (Evolution → Shark)

URL configurada em cada instância:
```
{PUBLIC_WEBHOOK_BASE_URL}/api/webhook/<...>
= https://app.sharkpanel.com.br/api/webhook/<...>
```

Eventos recebidos:
- `messages.upsert` (mensagem recebida ou enviada)
- `connection.update` (instance status mudou)
- `qrcode.updated`
- `messages.update` (status entrega)
- `chats.upsert`
- `contacts.update`

Auth: header `Authorization: Bearer $EVOLUTION_API_KEY` (validado em `app/api/webhook/route.ts`).

### Localização no código

```
app/api/webhook/route.ts                                   # recebe webhook Evolution
app/api/webhook/connection/route.ts                        # eventos connection.update
app/api/instances/...                                      # CRUD instâncias
app/api/whatsapp/instances/[id]/{logout,reconnect}/route.ts
app/api/external/instances/route.ts                        # API externa pra clientes
lib/groups/evolution.ts                                    # helpers
apps/worker/src/worker.ts                                  # send_message, send_*, sync_*
```

### Convenção de instâncias
- `whatsapp_instances.evolution_instance_id` é o nome registrado no Evolution
- `whatsapp_instances.name` é o display name (ex: "Atendimento1", "Confirmação")
- `instance_type='atendimento' | 'payment_confirmation' | 'rotation' | …`
- `is_payment_confirmation=true` flag para instância dedicada de envio de credenciais
- `is_confirmation_fallback=true` flag para fallback secundário
- `payment_confirmation_enabled` desliga envio de credenciais por essa instância sem deletar

---

## 3. AmploPay (PIX)

### Identidade
- **URL:** `https://app.amplopay.com/api/v1`
- **Credenciais:** `x-public-key` + `x-secret-key` headers
  - Por workspace: `checkout_config.value` com `key='amplopay_public_key'` e `'amplopay_secret_key'`
  - Fallback global: env `AMPLOPAY_PUBLIC_KEY` + `AMPLOPAY_SECRET_KEY` (não setados na env atual do container web)

### Endpoints usados (Shark → AmploPay)

| Método | Path | Função |
|---|---|---|
| `POST` | `/gateway/pix/receive` | Cria cobrança PIX |
| `GET`  | `/transactions/<id>` | Status (polling fallback) |
| (varia) | `/refund` | Reembolso (não confirmado nesta auditoria) |

### Webhook (AmploPay → Shark)
```
URL: https://app.sharkpanel.com.br/api/payments/amplopay-webhook
Auth: token no payload JSON (campo "token") validado contra AMPLOPAY_WEBHOOK_TOKEN
```

Eventos:
- `transaction.created`
- `transaction.paid`
- `transaction.cancelled`
- `transaction.expired`
- `transaction.refunded`

### Localização no código

```
app/api/checkout/create-pix/route.ts                       # cria PIX (proxy → AmploPay)
app/api/checkout/status/[id]/route.ts                      # polling status
app/api/payments/amplopay-webhook/route.ts                 # webhook receiver (PRINCIPAL)
app/api/payments/webhook/route.ts                          # webhook secundário (legado)
app/api/resellers/credits/purchase/route.ts                # PIX pra comprar créditos do reseller
```

### Bug ativo
- **B-AMPLOPAY-001** — `app/api/payments/amplopay-webhook/route.ts:1141` captura `sigmaResult` mas o INSERT/UPDATE em `subscriptions` (linhas 1418-1442) ignora `iptv_username/password/server/expires_at`, deixando essas colunas NULL. Credenciais ficam só no `payments.metadata` JSONB. Fix proposto em `/root/b-amplopay-001-investigation.md`.

---

## 4. MinIO (S3-compatible storage)

### Identidade
- **URL pública:** `https://wp-zapflix-minio.jomik8.easypanel.host/zapflix-media`
- **URL interna:** `http://wp-zapflix-minio:9000` (Docker network)
- **Bucket:** `zapflix-media` (público sem assinatura)
- **Credenciais:** `S3_ACCESS_KEY=zapflixadmin` / `S3_SECRET_KEY=Zapfl1x@M1n10`

### Uso
- Mídias recebidas via WhatsApp (image/video/audio/document)
- Mídias de automações (templates de áudio, imagens)
- Avatares de usuários e contatos
- Stickers, etc.

Endpoints internos:
- `/api/upload/media` — upload genérico (autenticado)
- `/api/uploads/presign` — gera URL presigned para upload direto do browser
- `/api/automations/upload` — assets de automação
- `/api/profile/avatar` — avatar de usuário
- `/api/workspace/whitelabel/logo` — logo do tenant

### SDK
`@aws-sdk/client-s3` + `@aws-sdk/s3-request-presigner` em `package.json`.

---

## 5. Redis

### Identidade
- **Host interno:** `wp-zapflix-redis:6379` (env `REDIS_URL=redis://wp-zapflix-redis:6379`)
- **Compartilhado** com Evolution API (`wp_evolution-api-2-redis`) — sem `keyPrefix` separado, riscam keyspace conflitando

### Uso
- `lib/redis.ts` — cliente ioredis singleton
- `lib/queue/redis.ts` — config para BullMQ (não usado em prod, mas presente como dep)
- Cache de mensagens para performance entre dispositivos (env-comment)
- Lock distribuído (em algumas rotas críticas)
- Redis Commander UI: `wp_evolution-api-2-redis_rediscommander`

⚠️ Sem `keyPrefix` e sem isolamento — possível conflito com keys da Evolution. Documentado em CLAUDE.md.

---

## 6. Postgres (`wp_zapflix-db`)

### Identidade
- **Versão:** PostgreSQL 17
- **Host interno:** `wp-zapflix-db:5432`
- **Porta externa:** 5433 (⚠️ exposta na internet — fechar)
- **Database:** `zapflix`, **role:** `zapflix` (superuser + BYPASSRLS)
- **Connection string:** `postgresql://zapflix:<32hex>@wp-zapflix-db:5432/zapflix`

### Uso
- App principal usa `pg` (`@types/pg`) em `lib/db.ts` (pool de conexões + `query()`/`tx()`)
- Worker usa o mesmo Postgres pra fila SKIP LOCKED
- 192 tabelas, ~228 FKs, 21 triggers, 71 functions (CLAUDE.md)
- Schema `auth.*` ainda existe (resíduo Supabase) — não usar

### PostgREST (legado, ⚠️)

Container `wp-zapflix-postgrest` (Postgres 12) ainda existe.
URL: `http://wp-zapflix-postgrest:3000`
Variáveis no container web:
```
NEXT_PUBLIC_SUPABASE_URL=http://wp-zapflix-postgrest:3000
NEXT_PUBLIC_SUPABASE_ANON_KEY=<JWT antigo>
SUPABASE_SERVICE_ROLE_KEY=<JWT antigo>
```

⚠️ Acesso direto ao banco via JWT. Documentado como vulnerabilidade em SECURITY.md ("desligar").

---

## 7. ElevenLabs (TTS — opcional)

- Configurado per-workspace em `elevenlabs_settings` + `elevenlabs_voices`
- Endpoints internos: `/api/elevenlabs/{settings,voices}` e `/api/master/elevenlabs-voices`
- Usado por `/api/automations/generate-audio`
- Auth: API key no `elevenlabs_settings.api_key` (não em env)

---

## 8. OpenAI / Anthropic (IA)

- Settings em `ai_provider_settings` (per-workspace ou global)
- Usado por `/api/ai/{chat,assistant,suggest,transcribe,generate-followup,generate-agent-prompt}`, `/api/ai-studio/*`, `/api/sales-brain/*`
- Auth: API key na tabela `ai_provider_settings`
- Env `OPENAI_API_KEY` mencionado em CLAUDE.md mas **não setado** no container web atual (provavelmente vem da tabela)

---

## 9. Checkout legado (Vite + tRPC + MySQL)

### Identidade
- Container: `wp_zapflix-checkout` (image `zapflix-checkout:latest`)
- URL pública: `checkout.appcineflick.com.br` (legado) e/ou `checkout.sharkpanel.com.br`
- Stack: Vite + React + tRPC
- Banco: `wp_zapflix-checkout-db` (MySQL 9, porta externa 33060 ⚠️)
- Admin: `wp_zapflix-checkout-db_dbgate` (DBGate UI)
- Código: `/root/Zapflix-Tech/checkout/` (961 linhas em `server/routers.ts`)

### Como o Shark Panel se integra
- `/api/checkout/*` em Next.js é proxy/cliente da API tRPC do checkout legado
- Tabelas Postgres `checkout_orders`, `checkout_plans`, `checkout_config` são da app Shark Panel — separadas do MySQL do checkout legado (parece haver duplicação/confusão; provavelmente o checkout legado escreve pro Postgres via API)

⚠️ Esta integração merece auditoria dedicada — não foi totalmente mapeada nesta rodada.

---

## 10. Outras integrações menores

| Integração | Onde |
|---|---|
| Vercel Analytics | `@vercel/analytics` no client |
| OpenTelemetry | `@opentelemetry/api` (instrumentação básica) |
| BullMQ (instalado, não usado) | Postgres SKIP LOCKED em vez |

---

## Mapa de fluxo de credenciais (resumo)

```
Reseller compra créditos      Shark Panel  →  AmploPay (api/v1/gateway/pix/receive)
                              AmploPay     →  Shark Panel webhook (creditos liberados)

Reseller ativa cliente        Shark Panel  →  Sigma (webhook/customer)
                              Shark Panel  →  Evolution (message/sendText)

Cliente compra IPTV (PIX)     Browser      →  Shark Panel /api/checkout/create-pix
                              Shark Panel  →  AmploPay
                              AmploPay     →  Shark Panel webhook
                              Shark Panel  →  Sigma + Evolution

Cliente envia msg WhatsApp    WhatsApp     →  Evolution
                              Evolution    →  Shark Panel /api/webhook
                              Shark Panel  →  jobs queue → Worker
                              Worker       →  IA (autopilot) ou agent (inbox SSE)

Mídia em mensagem             Worker       →  MinIO (download da Evolution + upload)
                              Frontend     →  MinIO direto via S3_PUBLIC_BASE_URL
```
