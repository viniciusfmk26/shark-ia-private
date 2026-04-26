# CLAUDE.md — Zapflix Tech

> Documento de referência para IAs e devs. Atualizado em 25/04/2026 após auditoria completa.
> **Leia este arquivo antes de qualquer alteração no projeto.**

---

## O que é este projeto

**Zapflix Tech** é um SaaS multi-tenant para revendedores de IPTV com automação de WhatsApp.
Cada cliente (tenant) tem seu próprio workspace isolado. A empresa operadora é a **Uniflix**
(workspace `00000000-0000-0000-0000-000000000002`).

URL principal: `https://appcineflick.com.br`
Servidor: `69.62.91.79` (Ubuntu 24, 193 GB disco, Docker Swarm via Easypanel)

---

## Stack tecnológica

```
FRONTEND + API
├── Next.js 14 (App Router, output: standalone)
├── React 19.2 + TypeScript
├── NextAuth v5 beta (Credentials provider, JWT sessions)
├── Tailwind CSS
└── Hospedagem: Docker Swarm (wp_zapflix-web)

WORKER (processamento assíncrono)
├── Node.js + TypeScript (NÃO usa BullMQ)
├── Fila via Postgres SKIP LOCKED (tabela jobs)
├── 12 tipos de job: send_message, sync_instance, process_webhook,
│   ai_response, sync_contacts, check_delivery, send_audio,
│   send_image, send_video, send_document, process_guided_funnel,
│   send_followup_trial
└── Hospedagem: Docker Swarm (wp_zapflix-worker)

BANCO DE DADOS PRINCIPAL
├── PostgreSQL 17 (wp_zapflix-db, porta 5433 externa)
├── 190 tabelas, 228 FKs, 21 triggers, 71 functions
├── Role da app: zapflix (superuser + BYPASSRLS — ver SECURITY.md)
└── Schema auth.* ainda presente (resíduo Supabase, não usar)

CHECKOUT (sistema separado)
├── Vite + React + tRPC (wp_zapflix-checkout)
├── MySQL 8 (wp_zapflix-checkout-db, porta 33060 externa)
├── URL pública: checkout.appcineflick.com.br
├── Admin interno: wp-zapflix-checkout.jomik8.easypanel.host/api/v1
└── Código: /root/Zapflix-Tech/checkout/

STORAGE
├── MinIO S3-compatible (wp_zapflix-minio)
├── Bucket: zapflix-media (público sem assinatura)
├── URL interna: http://10.11.46.253:9000
└── URL externa: minio.zapflix.shop / :9000

WHATSAPP
├── Evolution API v2 (evolution-api-2)
├── Redis compartilhado: evolution-api-2-redis
└── Sem keyPrefix separado (compartilha keyspace com Zapflix)

CRONS
├── supercronic via Docker (wp_zapflix-cron)
├── Código: /root/Zapflix-Tech/app/api/cron/
└── Auth: header x-cron-secret (valor em CRON_SECRET env)

MONITORAMENTO
├── zapflix-monitor (Flask, OFFLINE há 3+ semanas)
├── Código: /root/zapflix-monitor/app.py (788 linhas)
└── Dashboard: porta 5000 (quando rodando)
```

---

## Estrutura de diretórios

```
/root/Zapflix-Tech/
├── app/                    # Next.js App Router
│   ├── api/                # 580 rotas de API
│   │   ├── admin/          # Rotas master (requerem requireSuperAdmin)
│   │   ├── cron/           # 25 crons (requerem CRON_SECRET)
│   │   ├── debug/          # ⚠️ SEM AUTH — ver SECURITY.md
│   │   ├── migrate/        # ⚠️ SEM AUTH — ver SECURITY.md
│   │   ├── master/         # Rotas do painel master
│   │   ├── sales-brain/    # 14 rotas do Cérebro de Vendas (auth obrigatória)
│   │   └── ...             # Demais rotas de negócio
│   ├── (dashboard)/        # Páginas autenticadas (60 páginas)
│   └── master/             # Painel master (28 rotas)
├── apps/
│   └── worker/
│       └── src/
│           └── worker.ts   # ⚠️ Arquivo monolítico de 7.669 linhas
├── checkout/               # Sistema de checkout separado
│   ├── server/
│   │   └── routers.ts      # tRPC routers (961 linhas)
│   └── ...
├── lib/                    # Utilitários (75 arquivos)
│   ├── db.ts               # Conexão Postgres
│   ├── redis.ts            # Conexão Redis (sem keyPrefix)
│   ├── short-url.ts        # ⚠️ Usa Math.random() — ver SECURITY.md
│   └── server/
│       ├── audit.ts        # Log de auditoria (fire-and-forget)
│       └── webhooks.ts     # Notificações internas
├── auth.ts                 # Config NextAuth (bcrypt, bloqueio pending/rejected)
├── auth.config.ts          # Config para middleware (sem Node modules)
├── middleware.ts            # Proteção de rotas (EXCLUDED_PREFIXES)
└── CLAUDE.md               # Este arquivo
```

---

## Serviços no Easypanel (projeto: wp)

| Serviço | Tipo | URL | Status |
|---------|------|-----|--------|
| zapflix-web | Next.js | appcineflick.com.br | ✅ |
| zapflix-worker | Node.js | — | ✅ |
| zapflix-cron | supercronic | — | ✅ |
| zapflix-db | PostgreSQL 17 | :5433 (externo) | ✅ |
| zapflix-minio | MinIO | minio.zapflix.shop | ✅ |
| zapflix-postgrest | PostgREST v12 | wp-zapflix-postgrest.jomik8.easypanel.host | ✅ ⚠️ |
| zapflix-checkout | Vite+tRPC | checkout.appcineflick.com.br | ✅ |
| zapflix-checkout-db | MySQL 8 | :33060 (externo) | ✅ |
| zapflix-admin | nginx+SPA Manus.im | claw.appcineflick.com.br | ✅ |
| zapflix-monitor | Flask | — | ❌ OFFLINE |
| evolution-api-2 | Evolution API | — | ✅ |
| evolution-api-2-db | PostgreSQL | — | ✅ |
| evolution-api-2-redis | Redis | :6379 (externo) | ✅ ⚠️ |

---

## Workspaces (tenants)

| UUID | Nome | Tipo |
|------|------|------|
| 00000000-0000-0000-0000-000000000001 | Superadmin | Sistema |
| 00000000-0000-0000-0000-000000000002 | Uniflix | Operadora principal |
| (gerado) | Iphone | Teste |
| (gerado) | Shark | Teste |
| (gerado) | Diario-das-Bruxas | Teste |

---

## Usuários do sistema

| Usuário | Role | Workspace |
|---------|------|-----------|
| Vinicius | owner / superadmin | Todos |
| Denise | admin | Uniflix |
| Dudu | — | — |

---

## Autenticação e autorização

**NextAuth v5** com Credentials provider. Fluxo:
1. Login via email+senha (bcrypt)
2. JWT cookie gerado (sem sessão no banco — NextAuth usa JWT mode)
3. `middleware.ts` protege todas as rotas exceto EXCLUDED_PREFIXES
4. `requireSuperAdmin()` protege rotas master
5. `CRON_SECRET` protege rotas cron

**EXCLUDED_PREFIXES** (rotas públicas por design):
```
/api/webhooks, /api/notifications, /api/checkout,
/api/debug, /api/cron, /api/migrate, /api/internal,
/api/external, /api/auth/[...], /api/trial/web,
/api/webchat, /api/resellers/public, /api/cadastro,
/api/r/[code], /api/pix
```

⚠️ `/api/debug/*` e `/api/migrate/*` estão em EXCLUDED mas **não têm auth interna**.
Ver SECURITY.md para detalhes.

---

## Sistema de filas (Worker)

**NÃO usa BullMQ.** Usa Postgres com SKIP LOCKED.

```sql
-- Como o worker pega um job
SELECT * FROM jobs
WHERE status = 'queued' AND run_at <= NOW()
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

Fluxo: job inserido na tabela `jobs` → worker faz polling → processa → atualiza status.

Tipos de status: `queued`, `running`, `succeeded`, `failed`, `dead`, `skipped`, `archived`, `cancelled`

---

## Crons configurados no supercronic

25 endpoints em `/api/cron/`. Todos protegidos por `x-cron-secret`.

**Crons ATIVOS no supercronic:**
- check-instance-health
- purge-jobs
- sync-instances
- retry-failed-jobs

**Crons NÃO agendados (existem mas não rodam automaticamente):**
- monthly-payroll
- plan-expiry
- renewal-check
- pix-followup
- trial-followup
- drip-campaigns
- close-inactive
- promote-expired-trials

---

## Banco de dados — tabelas principais

```
CORE
├── workspaces              Tenants do sistema
├── workspace_memberships   Usuários por tenant
├── nextauth_users          Usuários (auth)
├── nextauth_accounts       Contas OAuth (vazia)
└── nextauth_sessions       Sessões (vazia — usa JWT)

WHATSAPP
├── whatsapp_instances      Instâncias Evolution API
├── conversations           Conversas
├── messages                Mensagens
├── contacts                Contatos (nome, telefone, avatar)
└── contact_tags            Tags de contato

AUTOMAÇÃO
├── automations             Fluxos de automação
├── automation_steps        Passos dos fluxos
├── guided_funnels          Funis guiados
├── guided_funnel_steps     Passos dos funis
└── jobs                    Fila de processamento

IPTV
├── iptv_trials             Testes de IPTV
├── iptv_servers            Servidores IPTV
├── sigma_servers           Servidores Sigma (painel externo)
└── subscriptions           Assinaturas ativas

FINANCEIRO
├── checkout_orders         Pedidos do checkout (PIX)
├── payments                Pagamentos
├── resellers               Revendedores
├── reseller_sales          Vendas por revendedor
└── reseller_withdrawals    Saques de revendedores

ANALYTICS
├── agent_performance_daily Performance por agente/dia
├── agent_levels            Gamificação (XP, nível, créditos)
└── audit_logs              Log de auditoria (347 MB — sem retenção)
```

---

## Padrões de código importantes

### Autenticação em rotas API
```typescript
// ✅ Correto — sempre verificar auth primeiro
const session = await auth();
if (!session?.user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

// ✅ Para rotas master
await requireSuperAdmin(request);

// ✅ Para crons
const token = request.headers.get('x-cron-secret');
if (!CRON_TOKENS.has(token)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
```

### Filtro multi-tenant obrigatório
```typescript
// ✅ SEMPRE incluir workspace_id em queries
const data = await query(
  'SELECT * FROM contacts WHERE workspace_id = $1',
  [workspaceId]
);

// ❌ NUNCA fazer sem filtro de workspace
const data = await query('SELECT * FROM contacts WHERE phone = $1', [phone]);
```

### Auditoria
```typescript
// Registrar ações destrutivas
import { logAudit } from '@/lib/server/audit';
await logAudit({ workspaceId, action: 'delete', resource: 'contact', resourceId: id });
```

---

## Variáveis de ambiente críticas

```bash
# Banco
DATABASE_URL=postgresql://zapflix:<senha>@wp_zapflix-db:5432/zapflix

# Auth
NEXTAUTH_SECRET=<secret>
NEXTAUTH_URL=https://appcineflick.com.br

# Cron (NÃO use valor hardcoded 'zapflix2026')
CRON_SECRET=<secret-forte>
CRON_TOKEN=<secret-forte>

# S3/MinIO
S3_ENDPOINT=http://69.62.91.79:9000
S3_INTERNAL_ENDPOINT=http://10.11.46.253:9000
S3_ACCESS_KEY=zapflixadmin
S3_SECRET_KEY=<senha-forte-32chars>
S3_BUCKET=zapflix-media

# Evolution API
EVOLUTION_API_URL=http://evolution-api-2:8080
EVOLUTION_API_KEY=<key>

# OpenAI
OPENAI_API_KEY=<key>

# Checkout / AmploPay
AMPLOPAY_PUBLIC_KEY=<key>
AMPLOPAY_SECRET_KEY=<key>

# PostgREST (idealmente desligar — ver SECURITY.md)
PGRST_JWT_SECRET=<secret>
```

---

## Comandos úteis

```bash
# Ver logs do app principal
docker service logs wp_zapflix-web --tail 50 -f

# Ver logs do worker
docker service logs wp_zapflix-worker --tail 50 -f

# Ver logs do cron
docker service logs wp_zapflix-cron --tail 50 -f

# Conectar no banco
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix

# Ver jobs na fila
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c \
  "SELECT type, status, count(*) FROM jobs GROUP BY type, status ORDER BY status, count DESC;"

# Ver containers rodando
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

# Forçar redeploy de um serviço
docker service update --force wp_zapflix-web
```

---

## O que NÃO fazer

```
❌ Não usar BullMQ — o projeto usa Postgres SKIP LOCKED
❌ Não fazer queries sem WHERE workspace_id = $X
❌ Não usar Math.random() para gerar tokens/códigos
❌ Não confiar em RLS do Postgres (role zapflix bypassa tudo)
❌ Não commitar credenciais no .env.example
❌ Não usar o schema auth.* (resíduo Supabase, quebrado)
❌ Não usar is_workspace_member() ou get_workspace_role() no banco
   (dependem de auth.uid() do Supabase, retornam NULL)
❌ Não rodar ALTER TABLE em produção via código (DDL em runtime)
❌ Não usar o cron secret hardcoded 'zapflix2026'
```

---

## Arquivos que precisam de atenção especial

| Arquivo | Problema | Prioridade |
|---------|----------|------------|
| `apps/worker/src/worker.ts` | 7.669 linhas — monolítico | Baixa (funciona) |
| `lib/short-url.ts` | Math.random() — PRNG previsível | Média |
| `lib/redis.ts` | Sem keyPrefix | Média |
| `app/api/debug/*/route.ts` | Sem autenticação | 🔴 Alta |
| `app/api/migrate/*/route.ts` | Sem autenticação | 🔴 Alta |
| `app/api/notifications/route.ts` | Sem autenticação | 🔴 Alta |

---

## Projetos relacionados

| Projeto | Path | Stack | Status |
|---------|------|-------|--------|
| App principal | /root/Zapflix-Tech | Next.js 14 | ✅ Ativo |
| Monitor | /root/zapflix-monitor | Flask+psycopg2 | ❌ Offline |
| Admin checkout | claw.appcineflick.com.br | Manus.im SPA | ✅ Ativo |
| Legado Supabase | /root/supabase-docker | Docker compose | ⚠️ Desligar |

---

## Próximos passos (ver FIXES.md para detalhes)

1. Fechar portas expostas (5433, 6379, 9000, 33060, 8000, 8443)
2. Adicionar auth em `/api/debug/*` e `/api/migrate/*`
3. Rotacionar todas as credenciais expostas
4. Desligar stack Supabase legado (14 containers)
5. Configurar backups automáticos
6. Reativar zapflix-monitor com env vars corretas
