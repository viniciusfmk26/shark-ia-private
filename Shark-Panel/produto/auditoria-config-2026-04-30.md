---
name: Auditoria de configurações Zapflix 2026-04-30
description: Env vars, instâncias, planos, limites, crons, Evolution API
type: audit
date: 2026-04-30
---

# Auditoria de Configurações — Zapflix-Tech (2026-04-30 noite)

## 1. ENV VARS

### Definidas em produção (Easypanel — wp_zapflix-web): 37
ADMIN_MIGRATION_SECRET, AMPLOPAY_WEBHOOK_TOKEN, AUTH_SECRET, AUTH_TRUST_HOST, CRON_CUTOFF_DATE, CRON_TOKEN, DATABASE_URL, DEFAULT_WORKSPACE_ID, DEPLOY_TIMESTAMP, DEV_WORKSPACE_ID, EVOLUTION_API_KEY, EVOLUTION_API_URL, GIT_SHA, NEXTAUTH_SECRET, NEXTAUTH_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, NEXT_PUBLIC_SUPABASE_URL, NODE_ENV, NODE_OPTIONS, PAYMENT_WEBHOOK_SECRET, PORT, PUBLIC_WEBHOOK_BASE_URL, REDIS_HOST, REDIS_PASSWORD, REDIS_PORT, REDIS_URL, ROTATION_API_KEY, S3_ACCESS_KEY, S3_BUCKET, S3_ENDPOINT, S3_PUBLIC_BASE_URL, S3_PUBLIC_ENDPOINT, S3_SECRET_KEY, SUPABASE_SERVICE_ROLE_KEY, UNIFLIX_EXTERNAL_API_KEY, WEBHOOK_TOKEN

### Usadas no código mas NÃO definidas em produção (27 — risco médio/alto)
- **Críticas (provavelmente quebram features)**:
  - OPENAI_API_KEY — IA (pode estar lendo do workspace_settings.ai.openrouterApiKey)
  - AMPLOPAY_PUBLIC_KEY / AMPLOPAY_SECRET_KEY — pagamentos AmploPay (só webhook_token está set)
  - EVOLUTION_BASE_URL / EVOLUTION_TOKEN — provável legado, código novo usa EVOLUTION_API_URL/KEY
  - POSTGRES_URL / POSTGRES_URL_NON_POOLING — legado Supabase, hoje usa DATABASE_URL
- **Health/observabilidade**:
  - HEALTHCHECK_TOKEN, HEALTH_DEAD_THRESHOLD, HEALTH_HEARTBEAT_STALE_S
  - RATE_LIMIT_HEALTH_FULL_PER_MIN, RATE_LIMIT_HEALTH_PUBLIC_PER_MIN
  - ALERT_PHONE_NUMBER, SUPERADMIN_WHATSAPP
- **App/checkout**:
  - APP_URL, NEXT_PUBLIC_APP_URL, NEXT_PUBLIC_CHECKOUT_URL
  - BUILD_TIME (não-crítico, é display)
- **Outras**:
  - CHATINBOX_TOKEN, CRON_SECRET (mas CRON_TOKEN existe), MIGRATE_SECRET (mas ADMIN_MIGRATION_SECRET existe)
  - NODE_TLS_REJECT_UNAUTHORIZED, ROTATION_WORKSPACE_SLUG, S3_INTERNAL_ENDPOINT, S3_REGION
  - UNIFLIX_WORKSPACE_ID, WEBCHAT_DEFAULT_WORKSPACE_SLUG

### Hardcoded scan
- `uniflix2026` já corrigida (sessão anterior)
- ELEVENLABS api_key está em workspace_settings.elevenlabs.api_key (DB, não env) — `sk_21018bd8f0f38959c8a86284ea5b36dc82769646b31bf2cc` — **EXPOSTA**, sem env var

## 2. INSTÂNCIAS WHATSAPP (30 total em 6 workspaces)

| Workspace | Total | Conectadas | Disparo | Atendimento |
|---|---|---|---|---|
| Diario-das-Bruxas | 1 | 1 | 0 | 1 |
| Fábrica | 5 | 1 | 0 | 5 |
| Iphone | 1 | 0 | 0 | 1 |
| Shark | 1 | 1 | 0 | 1 |
| Shark Panel | 22 | 13 | 2 (Bruninhahh, Gabriele Garcia) | 20 |
| Superadmin Sistema | 0 | - | - | - |

- **daily_limit padrão = 150 / hourly_limit = 20** (algumas Shark Panel com 30/h)
- **DUPLICATAS suspeitas**: Lucía Fernandes, cubot, Marsbaks, Samsung A30, suporte, Mayara Kook aparecem em múltiplos workspaces — provável legado de migração

## 3. CHECKOUT PLANS (12 registros, 3 workspaces)

- Apenas `server=2` (TPS) — **server=1 (megabox) não tem nenhum plano configurado**
- Workspaces com planos: 00..02 (Shark Panel), a70c0dae, cb2544fc
- Templates: Mensal R$17, Anual R$49,90, Vitalício R$119,90, Tela Extra R$15

## 4. LIMITES / QUOTAS

- **NÃO existe sistema de planos do SaaS por workspace** (sem max_contacts, max_instances, max_messages)
- Únicos limites encontrados:
  - `app/api/rotation/_shared.ts: DAILY_LIMIT = 200` (warmup global)
  - `whatsapp_instances.daily_limit / hourly_limit` (anti-ban por instância)
- **Risco**: workspace pode crescer ilimitadamente — tenant pode esgotar recursos do servidor

## 5. CRONS — ESTADO REAL (CORREÇÃO DA AUDITORIA)

**Auditoria anterior estava ERRADA** ao dizer "21 de 25 crons não agendados". Não existe arquivo `supercronic.cron`. Os crons são definidos diretamente em `Dockerfile.cron` (linhas 36-64) via `printf` para `/etc/crontab.supercronic`.

### Crons agendados (27): TODOS os 26 routes em /api/cron/ + `metrics-snapshot-daily`
scheduled-messages, metrics-snapshot, purge-jobs, weekly-report, funnel-processor, check-webhook-tokens, check-worker-alerts, sync-instance-profiles, check-instance-health, process-bulk-send, db-retention, pix-followup, abandoned-cart, follow-up, drip-campaigns, trial-followup, promote-expired-trials, drip-event-triggers, close-inactive, plan-expiry, renewal-check, increment-warmup-day, monthly-payroll, reseller-billing, reseller-levels, sigma-backfill-24h

### Crons faltando (1): `recorrencia/sync`
- Endpoint `/api/recorrencia/sync` existe mas não tem entrada no Dockerfile.cron
- Justifica os 1.307 pagamentos órfãos sem subscription

## 6. EVOLUTION API

- **URL única (interna Docker)**: `http://evolution-api-2:8080`
- **Key única (global)**: `429683C4C977415CAAFCCE10F7D57E11`
- **NÃO há key por instância** — todas as 30 instâncias usam a mesma global key
- Webhook recebe em: `https://app.sharkpanel.com.br/api/webhook/evolution`
- WEBHOOK_TOKEN em produção: `e81de01fbb23ad3748d40c1239a6b965a20ecea10eba9f3d40e368b659ecebaf`

## RECOMENDAÇÕES

1. **Definir env vars críticas no Easypanel**: OPENAI_API_KEY, AMPLOPAY_PUBLIC_KEY, AMPLOPAY_SECRET_KEY, NEXT_PUBLIC_APP_URL, ALERT_PHONE_NUMBER
2. **Mover ELEVENLABS api_key para env var** (atualmente exposta no workspace_settings)
3. **Limpar env vars legadas do código**: POSTGRES_URL, POSTGRES_URL_NON_POOLING, EVOLUTION_BASE_URL, EVOLUTION_TOKEN, MIGRATE_SECRET, CRON_SECRET (consolidar com CRON_TOKEN)
4. **Adicionar `recorrencia/sync` ao Dockerfile.cron** — única lacuna real no scheduling
5. **Implementar plano SaaS** com limites por workspace (contatos, instâncias, mensagens/mês)
6. **Limpar duplicatas de instâncias** (Lucía, cubot, Marsbaks, Samsung A30, suporte, Mayara Kook)
7. **Configurar planos para server=1 (megabox)** ou desativar opção
