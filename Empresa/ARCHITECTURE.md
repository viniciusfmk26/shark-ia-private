# ARCHITECTURE.md — Zapflix Tech

> Mapa completo de infraestrutura, serviços e fluxos de dados.
> Relacionado: [[CLAUDE]] | [[RUNBOOK]]
> Atualizado em 25/04/2026.

---

## Visão geral

```
INTERNET
    │
    ▼
[Traefik / Easypanel]  ← reverse proxy com TLS automático
    │
    ├──► appcineflick.com.br          → wp_zapflix-web (Next.js)
    ├──► checkout.appcineflick.com.br → wp_zapflix-checkout (Vite+tRPC)
    ├──► claw.appcineflick.com.br     → wp_zapflix-admin (SPA Manus.im)
    ├──► minio.zapflix.shop           → wp_zapflix-minio (MinIO)
    └──► wp-zapflix-postgrest.*       → wp_zapflix-postgrest (PostgREST) ⚠️

REDE INTERNA DOCKER SWARM (10.11.x.x)
    │
    ├── wp_zapflix-web
    │     └──► wp_zapflix-db (Postgres :5432 interno)
    │     └──► wp_zapflix-minio (:9000 interno)
    │     └──► evolution-api-2 (:8080)
    │
    ├── wp_zapflix-worker
    │     └──► wp_zapflix-db (polling de jobs)
    │     └──► evolution-api-2-redis (Redis)
    │     └──► evolution-api-2 (envio de mensagens)
    │     └──► wp_zapflix-minio (upload de mídia)
    │
    ├── wp_zapflix-cron
    │     └──► wp_zapflix-web (HTTP calls para /api/cron/*)
    │
    └── wp_zapflix-checkout
          └──► wp_zapflix-checkout-db (MySQL :3306 interno)
          └──► AmploPay API (externo)
```

---

## Fluxo de autenticação

```
USUÁRIO
  │
  ▼
POST /api/auth/signin (NextAuth)
  │
  ▼
nextauth_users (SELECT email + bcrypt compare)
  │
  ├── status = 'pending' → Erro PENDING_APPROVAL
  ├── status = 'rejected' → Erro ACCOUNT_REJECTED
  └── status = 'active' → JWT gerado
                              │
                              ▼
                         Cookie httpOnly
                              │
                              ▼
                     middleware.ts (verifica JWT)
                              │
                    ┌─────────┴─────────┐
                    │                   │
               EXCLUDED_PREFIXES    Rotas protegidas
               (públicas)          (requerem sessão)
```

---

## Fluxo de mensagem WhatsApp

```
CONTATO (WhatsApp)
  │ mensagem
  ▼
Evolution API
  │ webhook
  ▼
POST /api/webhooks/evolution/[instanceId]
  │
  ├──► INSERT jobs (type='process_webhook')
  │
  ▼
wp_zapflix-worker (polling SKIP LOCKED)
  │
  ├── Verificar automações ativas → INSERT jobs (send_message)
  ├── Verificar funis guiados → INSERT jobs (process_guided_funnel)
  ├── Verificar AI agent → INSERT jobs (ai_response)
  └── Registrar em conversations + messages
```

---

## Fluxo de checkout (PIX)

```
CLIENTE FINAL (browser)
  │
  ▼
checkout.appcineflick.com.br (Vite SPA)
  │ tRPC mutation: checkout.createPix
  ▼
wp_zapflix-checkout (Node.js tRPC server)
  │
  ├──► INSERT checkout_orders (MySQL)
  ├──► POST AmploPay API /gateway/pix/receive
  └──► Retorna QR Code PIX
              │
              │ cliente paga
              ▼
        AmploPay webhook
              │
              ▼
        POST /api/webhooks/amplopay
              │
              ├──► UPDATE checkout_orders SET status='paid'
              └──► notifyChatInbox (sino no app)
```

---

## Banco de dados — relacionamentos principais

```
workspaces
  │
  ├── workspace_memberships ──► nextauth_users
  ├── whatsapp_instances
  │     └── conversations
  │           └── messages
  ├── contacts
  │     ├── contact_tags (via contact_tag_assignments)
  │     ├── iptv_trials
  │     └── subscriptions
  ├── automations
  │     ├── automation_steps
  │     └── automation_triggers
  ├── guided_funnels
  │     └── guided_funnel_steps
  ├── jobs (fila de processamento)
  ├── resellers
  │     ├── reseller_sales
  │     └── reseller_withdrawals
  └── agent_levels (gamificação)
        └── agent_performance_daily
```

---

## Variáveis de ambiente por serviço

### wp_zapflix-web (Next.js)
```
DATABASE_URL
NEXTAUTH_SECRET
NEXTAUTH_URL
CRON_SECRET / CRON_TOKEN
S3_ENDPOINT / S3_INTERNAL_ENDPOINT
S3_ACCESS_KEY / S3_SECRET_KEY / S3_BUCKET
EVOLUTION_API_URL / EVOLUTION_API_KEY
OPENAI_API_KEY
PGRST_JWT_SECRET (remover quando desligar PostgREST)
AMPLOPAY_PUBLIC_KEY / AMPLOPAY_SECRET_KEY
```

### wp_zapflix-worker
```
DATABASE_URL
REDIS_URL
S3_INTERNAL_ENDPOINT
S3_ACCESS_KEY / S3_SECRET_KEY / S3_BUCKET
EVOLUTION_API_URL / EVOLUTION_API_KEY
OPENAI_API_KEY
```

### wp_zapflix-cron
```
CRON_SECRET
APP_URL=http://wp_zapflix-web:3000
```

### wp_zapflix-checkout
```
DATABASE_URL (MySQL)
AMPLOPAY_PUBLIC_KEY / AMPLOPAY_SECRET_KEY
ADMIN_PASSWORD
```

### wp_zapflix-monitor (quando ativo)
```
DATABASE_URL (Postgres)
DOCKER_SOCKET=/var/run/docker.sock
REFRESH_INTERVAL=30
MONITOR_PASSWORD
EVOLUTION_ALERT_KEY
EVOLUTION_ALERT_URL
EVOLUTION_ALERT_INSTANCE
ALERT_PHONE
APP_HEALTH_URL
SECRET_KEY
```

---

## Portas e endpoints internos

| Serviço | Porta interna | Porta externa | Observação |
|---------|--------------|--------------|------------|
| zapflix-web | 3000 | 80/443 (Traefik) | Principal |
| zapflix-db | 5432 | 5433 ⚠️ | Postgres principal |
| zapflix-minio | 9000 | 9000 ⚠️ | MinIO API |
| zapflix-minio | 9001 | — | MinIO Console |
| zapflix-checkout | 3001 | 80/443 (Traefik) | Checkout |
| zapflix-checkout-db | 3306 | 33060 ⚠️ | MySQL X Protocol |
| zapflix-postgrest | 3000 | 80/443 (Traefik) | PostgREST ⚠️ |
| evolution-api-2 | 8080 | — | Interno |
| evolution-api-2-redis | 6379 | 6379 ⚠️ | Redis |
| supabase-kong | 8000 | 8000 ⚠️ | Legado |
| supabase-kong | 8443 | 8443 ⚠️ | Legado TLS |

⚠️ = porta exposta para internet (risco — ver SECURITY.md)

---

## Domínios configurados

| Domínio | Serviço | TLS |
|---------|---------|-----|
| appcineflick.com.br | zapflix-web | ✅ |
| checkout.appcineflick.com.br | zapflix-checkout | ✅ |
| claw.appcineflick.com.br | zapflix-admin | ✅ |
| minio.zapflix.shop | zapflix-minio | ✅ |
| wp-zapflix-postgrest.jomik8.easypanel.host | zapflix-postgrest | ✅ |
| wp-zapflix-checkout.jomik8.easypanel.host | zapflix-checkout | ✅ |

---

## Decisões de arquitetura

| Decisão | Escolha | Motivo |
|---------|---------|--------|
| Fila de jobs | Postgres SKIP LOCKED | Sem dependência extra (BullMQ removido) |
| Auth | NextAuth v5 JWT | Migrado de Supabase (migração incompleta) |
| Storage | MinIO | S3-compatible auto-hospedado |
| WhatsApp | Evolution API v2 | Multi-instância, webhook-based |
| Checkout | Sistema separado | Isolamento de responsabilidades |
| Cron | supercronic | Compatível com Docker Swarm |

---

## Decisões pendentes (débito técnico)

| Item | Situação | Impacto |
|------|---------|---------|
| PostgREST | Rodando sem uso | Superfície de ataque |
| Supabase legado | 14 containers sem dados | Recursos + surface |
| worker.ts monolítico | 7.669 linhas | Manutenção difícil |
| RLS no banco | Ineficaz (role superuser) | Sem defesa em profundidade |
| Backups | Não configurados | Risco total de perda de dados |
| Monitor | Offline há 3 semanas | Sistema operacionalmente cego |
