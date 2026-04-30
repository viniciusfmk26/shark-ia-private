# Configurações e Secrets — Auditoria 2026-04-30 (sessão noturna 2)

## 1. Mapa de env vars

### Definidas em produção (Easypanel `wp_zapflix-web`): 37
ADMIN_MIGRATION_SECRET, AMPLOPAY_WEBHOOK_TOKEN, AUTH_SECRET, AUTH_TRUST_HOST, CRON_CUTOFF_DATE, CRON_TOKEN, DATABASE_URL, DEFAULT_WORKSPACE_ID, DEPLOY_TIMESTAMP, DEV_WORKSPACE_ID, EVOLUTION_API_KEY, EVOLUTION_API_URL, GIT_SHA, NEXTAUTH_SECRET, NEXTAUTH_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, NEXT_PUBLIC_SUPABASE_URL, NODE_ENV, NODE_OPTIONS, PAYMENT_WEBHOOK_SECRET, PORT, PUBLIC_WEBHOOK_BASE_URL, REDIS_HOST, REDIS_PASSWORD, REDIS_PORT, REDIS_URL, ROTATION_API_KEY, S3_ACCESS_KEY, S3_BUCKET, S3_ENDPOINT, S3_PUBLIC_BASE_URL, S3_PUBLIC_ENDPOINT, S3_SECRET_KEY, SUPABASE_SERVICE_ROLE_KEY, UNIFLIX_EXTERNAL_API_KEY, WEBHOOK_TOKEN

### Usadas no código (web+worker) mas NÃO definidas em prod (37)
**Críticas (prováveis quebras de feature):**
- `OPENAI_API_KEY` — IA (atualmente lendo do `workspace_settings.ai.openrouterApiKey` no DB)
- `AMPLOPAY_PUBLIC_KEY`, `AMPLOPAY_SECRET_KEY` — pagamento (só `AMPLOPAY_WEBHOOK_TOKEN` definido)
- `EVOLUTION_BASE_URL`, `EVOLUTION_TOKEN` — código legado, agora usa `EVOLUTION_API_URL`/`KEY`
- `POSTGRES_URL`, `POSTGRES_URL_NON_POOLING` — vestígios Supabase (usar `DATABASE_URL`)
- `MIGRATE_SECRET`, `CRON_SECRET` — duplicidade com `ADMIN_MIGRATION_SECRET`/`CRON_TOKEN`

**Health/observabilidade:**
- `HEALTHCHECK_TOKEN`, `HEALTH_DEAD_THRESHOLD`, `HEALTH_HEARTBEAT_STALE_S`
- `RATE_LIMIT_HEALTH_FULL_PER_MIN`, `RATE_LIMIT_HEALTH_PUBLIC_PER_MIN`
- `ALERT_PHONE_NUMBER`, `SUPERADMIN_WHATSAPP`, `SUPERADMIN_ID`, `NEXT_PUBLIC_SUPERADMIN_ID`

**App/checkout:**
- `APP_URL`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_CHECKOUT_URL`, `NEXT_PUBLIC_INBOX_API_BASE`
- `NEXT_PUBLIC_FORCE_MOCK`, `BUILD_TIME`, `LOG_LEVEL`

**Worker:**
- `BATCH_SIZE`, `POLL_INTERVAL`, `WORKER_ID`, `npm_package_version`

**Outras:**
- `CHATINBOX_TOKEN`, `NODE_TLS_REJECT_UNAUTHORIZED`, `ROTATION_WORKSPACE_SLUG`
- `S3_FORCE_PATH_STYLE`, `S3_INTERNAL_ENDPOINT`, `S3_REGION`
- `UNIFLIX_WORKSPACE_ID`, `WEBCHAT_DEFAULT_WORKSPACE_SLUG`

### Definidas em prod mas não usadas no código (9 — possível lixo)
`AUTH_SECRET`, `AUTH_TRUST_HOST`, `NEXTAUTH_SECRET` — usadas internamente pelo NextAuth (OK, manter)
`NODE_OPTIONS`, `PORT` — usadas pelo runtime Node/Next (OK, manter)
`DEPLOY_TIMESTAMP` — usado por dashboard (OK)
`NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` — **vestígios Supabase, podem ser removidos** (sistema migrou para Postgres direto)

## 2. Hardcoded secrets — varredura

Scan de tokens/keys em literais com 16+ chars:
- **Nenhum secret hardcoded encontrado** no código TypeScript
- Únicas matches são alfabetos para geração de IDs (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) — esperado
- ⚠️ **Achado importante (DB, não código)**: `workspace_settings.elevenlabs.api_key` = `sk_21018bd8f0f38959c8a86284ea5b36dc82769646b31bf2cc` armazenada em texto puro nos workspaces "Diario-das-Bruxas", "Shark" e "Shark Panel" — **mover para env var**

## 3. Instâncias WhatsApp — auditoria

**Total: 35 instâncias** (29 com workspace, **6 órfãs**, 14 conectadas, 21 desconectadas)

### Instâncias órfãs (sem workspace_id) — PRIORIDADE
| ID | Nome | Status | Conversas | Última msg | Ação sugerida |
|---|---|---|---|---|---|
| `482c28f3-...02ba0` | Kerolayne | connected | 49 | 2026-04-22 | Vincular ao Shark Panel (existe outra Kerolayne lá) |
| `7e86338d-...c02b2` | Kerolayne Redmi | connected | 48 | 2026-04-22 | Vincular ao Shark Panel |
| `e2029cb7-...c55b` | MayaraK | disconnected | 6 | 2026-04-18 | Vincular ao Shark Panel |
| `00000000-...0099` | Uniflix Web | disconnected | 1 | 2026-04-22 | Vincular ao Uniflix |
| `226b358f-...12d73` | Mayara j | disconnected | 0 | — | DELETE |
| `ce906056-...81597` | New | disconnected | 0 | — | DELETE |

### Duplicatas de nome entre workspaces (não-órfãs)
- `cubot`, `Marsbaks`, `Samsung A30`, `suporte` aparecem em "Fábrica" E em "Shark Panel"
- `Lucía Fernandes` em "Diario-das-Bruxas" E em "Shark Panel"
- `Mayara Kook` em "Shark" E em "Shark Panel"
- Indica migração legacy ou separação de tenants — revisar com user

### Instâncias desconectadas com 0 conversas (potencial limpeza)
14 instâncias criadas em 2026-04-30 (hoje) — provavelmente reset/teste, deixar

### Limites por instância (campos `daily_limit`/`hourly_limit`)
- Padrão: 150/dia, 20/hora
- Algumas Shark Panel: 150/dia, **30/hora**

## 4. Sistema de planos SaaS — **EXISTE** (correção da auditoria anterior)

Tabela `workspace_plans`:
- `plan` varchar (ex: 'free', 'enterprise')
- `max_instances` int (default 1)
- `monthly_messages` int (default 500)
- `ai_messages_month` int (default 0)
- `price_cents` int
- `plan_expires_at` timestamp
- `extra_agents_count` int
- `trial_started_at`, `trial_expires_at`, `trial_days`

**Estado atual: apenas 1 workspace com plano configurado:**
| workspace | plan | max_instances | monthly_messages | ai_messages | trial_days |
|---|---|---|---|---|---|
| Shark Panel (000...002) | enterprise | 999 | 999.999 | 999.999 | 7 |

Demais 4 workspaces (Fábrica, Iphone, Shark, Diario-das-Bruxas) **não têm linha em `workspace_plans`** → caem em defaults (free, max_instances=1, 500 msgs/mês).

⚠️ Mas Fábrica tem **5 instâncias**, Diario-das-Bruxas tem 1, Iphone tem 1 — limites NÃO são enforced (sem trigger/check). Sistema de planos existe estruturalmente mas não bloqueia nada.

Routes que leem `workspace_plans`:
- `/api/workspace/plan/route.ts:24`
- `/api/master/plans/route.ts:44`
- `/api/admin/ai-plans/route.ts:21,102`
- `/api/payments/amplopay-webhook/route.ts:913` (set após pagamento)
- `/api/cron/plan-expiry/route.ts:43` (downgrade quando expira)

## 5. Checkout plans (12 registros, 3 workspaces)

- Todos `server=2` (TPS) — **server=1 (megabox) sem nenhum plano configurado**
- Templates: Mensal R$17, Anual R$49,90, Vitalício R$119,90, Tela Extra R$15
- 3 workspaces com planos: Shark Panel, `a70c0dae`, `cb2544fc`

## 6. Evolution API — configuração

- **URL única (interna)**: `http://evolution-api-2:8080`
- **Key única (global)**: `429683C4C977415CAAFCCE10F7D57E11`
- Código em `lib/groups/evolution.ts` lê `EVOLUTION_API_URL` e `EVOLUTION_API_KEY` global
- **Não há key/auth segregada por instância** — todas as 35 instâncias compartilham
- Risco: vazamento de uma key compromete todas; instâncias não isoladas

## 7. Recomendações priorizadas

### 🔴 Crítico
1. Mover ELEVENLABS api_key (DB) para env var
2. Definir env vars de pagamento: `AMPLOPAY_PUBLIC_KEY`, `AMPLOPAY_SECRET_KEY`
3. Definir `OPENAI_API_KEY` em prod (atualmente caindo em fallback do DB)

### 🟡 Médio
4. Vincular 4 instâncias órfãs com conversas (Kerolayne, Kerolayne Redmi, MayaraK, Uniflix Web) ao workspace correto
5. Deletar 2 órfãs sem conversas (Mayara j, New)
6. Implementar **enforcement** dos limites em `workspace_plans` (hoje só leitura)
7. Configurar planos de checkout para `server=1` (megabox) ou desativar opção

### 🟢 Baixo
8. Limpar env vars legadas: `POSTGRES_URL`/`_NON_POOLING`, `EVOLUTION_BASE_URL`/`TOKEN`, `MIGRATE_SECRET`, `CRON_SECRET`, vestígios Supabase
9. Renomear duplicatas de instâncias entre workspaces (clarificar separação de tenant)
10. Adicionar `BUILD_TIME`, `LOG_LEVEL` em prod (não-críticos mas referenciados)
