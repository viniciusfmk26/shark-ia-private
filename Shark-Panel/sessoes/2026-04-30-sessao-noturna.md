# Sessão Noturna — 2026-04-30

> Execução autônoma de 7 blocos. Tudo aplicado em produção (`app.sharkpanel.com.br`).

## Bloco 1 — Documentação da auditoria
- Subido `Shark-Panel/produto/auditoria-completa-2026-04-30.md` (já existia commit anterior)
- README do diretório atualizado com resumo + próximos passos

## Bloco 2 — Auditoria de configurações
Documento detalhado em [[auditoria-config-2026-04-30]]. Findings principais:

### Env vars
- 37 vars definidas em produção (Easypanel `wp_zapflix-web`)
- **27 vars usadas no código mas NÃO definidas em prod** — risco médio/alto
  - Críticas: `OPENAI_API_KEY`, `AMPLOPAY_PUBLIC_KEY`, `AMPLOPAY_SECRET_KEY`, `NEXT_PUBLIC_APP_URL`, `ALERT_PHONE_NUMBER`
  - Legadas: `POSTGRES_URL`, `EVOLUTION_BASE_URL`/`EVOLUTION_TOKEN`, `MIGRATE_SECRET`, `CRON_SECRET`
- ELEVENLABS api_key está hardcoded em `workspace_settings.elevenlabs.api_key` no DB — **expor como env var**

### Instâncias WhatsApp
- 30 instâncias em 6 workspaces. Shark Panel concentra 22 (13 conectadas)
- Duplicatas suspeitas em múltiplos workspaces: Lucía, cubot, Marsbaks, Samsung A30, suporte, Mayara Kook
- Limites por instância: `daily_limit=150`, `hourly_limit=20` (algumas com 30/h)

### Checkout plans
- 12 planos em 3 workspaces, **todos** server=2 (TPS)
- **Server=1 (megabox) sem nenhum plano configurado**

### Limites por plano (SaaS)
- ❌ **Não existe sistema de limites por workspace** (max_contacts, max_instances, mensagens/mês)
- Únicos: `DAILY_LIMIT=200` no warmup global, `daily_limit/hourly_limit` na instância

### Crons (correção da auditoria anterior)
- **Não existia `supercronic.cron`** — todos os crons estavam hardcoded no `Dockerfile.cron` via `printf`
- Os 26 endpoints `/api/cron/*` JÁ estavam todos agendados
- Único realmente faltando: `/api/recorrencia/sync` (fora de `/cron/`)

### Evolution API
- URL única (interna): `http://evolution-api-2:8080`
- Key única global: `429683C4C977415CAAFCCE10F7D57E11` — **sem segregação por instância**

## Bloco 3 — Backfill de subscriptions

| Métrica | Antes | Depois |
|---|---|---|
| Subscriptions ativas (workspace Uniflix) | 317 | 1.337 |
| Diferença | — | **+1.020** |

Backfill executado via SQL direto (replicando lógica de `/api/recorrencia/sync` mas removendo o filtro `created_at > NOW() - INTERVAL '3 days'`). Resultado por source:
- `payments_sync_backfill_2026-04-30`: 1.007
- `contacts_sync_backfill_2026-04-30`: 13
- (preexistente: `amplopay` 200, `contacts_sync` 64, `payments_sync` 50, `credits` 3)

Diferença vs 1.044 contatos órfãos esperados = 24 (filtrados pela regra de "tela extra"/valor baixo).

## Bloco 4 — Crons

Refactor + adição:
- Extraído `Dockerfile.cron` → arquivo dedicado `supercronic.cron` (mais fácil de auditar/editar)
- Criado `/api/cron/recorrencia-sync` que itera **todos os workspaces** com `CRON_TOKEN` auth
- Adicionado handler `recorrencia-sync` em `scripts/run-crons.sh`

Schedules ajustados conforme política nova (8 crons):
| Cron | Antes | Agora |
|---|---|---|
| pix-followup | */30 * * * * | */30 * * * * (mantido) |
| trial-followup | 0 10 * * * | 0 * * * * (de hora em hora) |
| renewal-check | 0 7 * * * | 0 9 * * * |
| recorrencia-sync | (não tinha) | 0 0 * * * (meia-noite) |
| db-retention | 0 4 * * 0 | 0 3 * * 0 |
| promote-expired-trials | 0 1 * * * | 0 * * * * (de hora em hora) |
| close-inactive | 0 3 * * * | 0 1 * * * |
| funnel-processor | * * * * * | */5 * * * * |

Commit: `41e78dd9` (4 files, +243/-30)

## Bloco 5 — Build e deploy
- `docker build -t zapflix-tech:latest .` — falhou no 1º (TS error em `logger.error` no novo route), corrigido (objeto vai 1º arg, msg 2º — pino API)
- Re-build OK
- `docker build -f Dockerfile.cron -t easypanel/wp/zapflix-cron:latest .` — OK
- `docker service update --force wp_zapflix-web` — convergiu
- `docker service update --force wp_zapflix-cron` — convergiu

## Bloco 6 — Smoke-test
| Endpoint | Status |
|---|---|
| GET /api/health | 200 ✅ |
| GET /api/auth/csrf | 200 ✅ |
| GET /api/auth/session | 200 ✅ |
| GET /api/inbox/conversations (auth) | 200 ✅ |
| GET /api/contacts (auth) | 200 ✅ |
| GET /api/automations (auth) | 200 ✅ |
| POST /api/recorrencia/sync (auth) | 405 (só POST) |
| POST /api/cron/recorrencia-sync (sem token) | 401 ✅ |
| POST /api/cron/recorrencia-sync (com CRON_TOKEN) | **200 ✅** — 0 novas (backfill já cobriu) |

`/api/me`, `/api/dashboard/metrics`, `/api/whatsapp/instances` retornaram 404 — esperado, paths não existem.

## Status do deploy
- ✅ `wp_zapflix-web` rodando com nova imagem
- ✅ `wp_zapflix-cron` rodando com novo `supercronic.cron`
- ✅ Cron `recorrencia-sync` rodará às 00:00 (próxima execução)

## Próximos passos para amanhã
1. **Definir env vars críticas no Easypanel** (OPENAI_API_KEY, AMPLOPAY_PUBLIC_KEY/SECRET_KEY, NEXT_PUBLIC_APP_URL, ALERT_PHONE_NUMBER)
2. **Mover ELEVENLABS api_key** para env var (atualmente exposto no DB)
3. **Limpar env vars legadas** do código: POSTGRES_URL, EVOLUTION_BASE_URL/TOKEN, MIGRATE_SECRET, consolidar CRON_SECRET com CRON_TOKEN
4. **Implementar plano SaaS** com limites por workspace (contatos, instâncias, mensagens/mês)
5. **Limpar duplicatas de WhatsApp instances** entre workspaces (Lucía, cubot, Marsbaks, Samsung A30, suporte, Mayara Kook)
6. **Configurar planos para server=1 (megabox)** ou desativar opção no checkout
7. **Validar primeira execução do cron `recorrencia-sync`** amanhã ~00:01 (logs do `wp_zapflix-cron`)
8. **Considerar refactor**: extrair lógica do sync para função compartilhada entre `/api/recorrencia/sync` (UI) e `/api/cron/recorrencia-sync` (cron) — hoje há código duplicado
