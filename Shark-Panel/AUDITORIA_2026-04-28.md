# AUDITORIA 2026-04-28 — Sincronia roadmap × estado real

> Comparação entre o que `roadmap.md` e `FIXES.md` afirmam e o que está rodando no servidor `/root/Zapflix-Tech` em 28/04/2026.
> Relacionado: [[FIXES]] | [[roadmap]] | [[bugs]]

---

## TL;DR

- **8 itens** estavam marcados ⏳ Pendente em `roadmap.md` mas já estavam concluídos no servidor — `roadmap.md` estava 2 dias atrasado em relação ao `FIXES.md`.
- **1 item** (Fix 3.5 — monitor) estava marcado ✅ no `FIXES.md` mas regrediu: o serviço voltou a falhar há ~34 horas.
- **1 item** (Fix 1.4 — MinIO) estava marcado ✅ no `FIXES.md` mas a credencial não foi rotacionada de fato.
- **2 itens** seguem pendentes de verdade: Fix 3.6 (parcial) e F-001 afiliados.

---

## Verificação item por item

### Fix 1.4 — Rotacionar credenciais expostas — ⚠️ PARCIAL

| Credencial | `FIXES.md` | Estado real |
|---|---|---|
| GitHub PAT | ✅ | ✅ Token novo `ghp_WQfKMK…` em uso no remote |
| CRON_SECRET / CRON_TOKEN | ✅ | ✅ Hex 49 chars no env de `wp_zapflix-web` |
| MinIO `S3_SECRET_KEY` | ✅ | ❌ **Ainda é `Zapfl1x@M1n10`** (a senha original do documento, não 32 chars aleatórios). `MINIO_ROOT_PASSWORD` idem. |

**Ação requerida:** rotacionar MinIO de fato (gerar 32 chars hex e atualizar em `wp_zapflix-minio`, `wp_zapflix-web`, `wp_zapflix-worker`, `wp_zapflix-cron`).

### Fix 1.5 — Auth /api/notifications — ✅ FEITO

`app/api/notifications/route.ts` já valida `await auth()` e retorna 401 sem `session.user.id`. Roadmap estava errado.

### Fix 2.1 — IDOR analytics — ✅ FEITO

Todas as 6 rotas (`churn`, `revenue`, `overview`, `heatmap`, `instances`, `funnel`) usam `getWorkspaceId()` (sessão), não `?workspace_id=`. Roadmap estava errado.

### Fix 2.2 — handleSyncContacts com workspace_id — ✅ FEITO

`apps/worker/src/worker.ts:5685` — UPDATE com `AND workspace_id = $…`. Roadmap estava errado.

### Fix 2.5 — Backups Postgres — ✅ FEITO

- Script `/root/backup.sh` executável
- Crontab `0 3 * * * /root/backup.sh`
- `/root/backups/` com 4 dumps recentes (26, 27, 28/04 + snapshot pré-refactor)

### Fix 3.1 — Supabase legado — ✅ DESLIGADO

`/root/supabase-docker/` existe no disco mas sem `docker-compose.yml` válido; nenhum container Supabase em `docker ps -a`.

### Fix 3.2 — PostgREST — ✅ DESLIGADO

`wp_zapflix-postgrest` em `0/0` réplicas. Endpoint público retorna 502.

### Fix 3.3 — short-url crypto — ✅ FEITO

`lib/short-url.ts` usa `randomBytes` do Node crypto (linha 1). Roadmap estava errado.

### Fix 3.4 — Redis keyPrefix — ✅ FEITO

`lib/redis.ts:54` → `keyPrefix: 'shark:'`. Roadmap estava errado.

### Fix 3.5 — zapflix-monitor — ❌ REGRESSÃO

`FIXES.md` declara concluído em 26/04 com `--user root`, mas hoje:

```
wp_zapflix-monitor   replicated   0/1
.1   Shutdown   Failed 34 hours ago   "task: non-zero exit (255)"
.1   Shutdown   Failed 36 hours ago
.1   Shutdown   Failed 37 hours ago
```

Serviço continua configurado com `User: root`, mas o container exita com 255 logo após subir. Causa raiz a investigar (provavelmente env var faltando, image quebrada após rebuild, ou Postgres/Docker socket inacessível). **Reaberto.**

### Fix 3.6 — Crons supercronic — ⚠️ PARCIAL

`/etc/crontab.supercronic` no container `wp_zapflix-cron.1` agenda 12 crons:

```
scheduled-messages, metrics-snapshot, purge-jobs, metrics-snapshot-daily,
weekly-report, funnel-processor, check-webhook-tokens, check-worker-alerts,
sync-instance-profiles, check-instance-health, process-bulk-send, db-retention
```

**Existem como rota mas NÃO estão agendados:**

- `plan-expiry`
- `renewal-check`
- `pix-followup`
- `trial-followup`
- `drip-campaigns`
- `close-inactive`
- `promote-expired-trials`
- `abandoned-cart`
- `follow-up`
- `drip-event-triggers`
- `increment-warmup-day`
- `monthly-payroll`
- `reseller-billing`
- `reseller-levels`
- `sigma-backfill-24h`

(Existe `app/api/cron/<nome>/route.ts` para todos, mas o supercronic nunca dispara.)

### F-001 — Sistema de afiliados — ⏳ NÃO COMEÇOU

Existem páginas de **cadastro de revendedor** (`/registro-revendedor`, `/(public)/cadastro-revendedor`) e fluxo de revendedor já consolidado em `/reseller` (BUG-014), mas **não há sistema de link de afiliação**: `referral_code` aparece nas APIs de revendedores mas é o código do próprio revendedor, não link público de indicação com comissão automática no checkout.

---

## O que estava errado

### 8 itens marcados pendentes em `roadmap.md` mas já feitos

| Fix | Marcado roadmap | Real |
|-----|-----------------|------|
| 1.5 — Auth /api/notifications | ⏳ | ✅ |
| 2.1 — IDOR analytics | ⏳ | ✅ |
| 2.2 — handleSyncContacts | ⏳ | ✅ |
| 2.5 — Backups | ⏳ | ✅ |
| 3.1 — Supabase | ⏳ | ✅ |
| 3.2 — PostgREST | ⏳ | ✅ |
| 3.3 — short-url crypto | ⏳ | ✅ |
| 3.4 — Redis keyPrefix | ⏳ | ✅ |

`FIXES.md` já refletia tudo isso (com data + mensagem); só `roadmap.md` (que tem `Atualizado em 26/04/2026`) ficou para trás.

### 2 itens marcados ✅ no `FIXES.md` mas com problema

- **Fix 1.4 MinIO** — alegado rotacionado (32 chars), real ainda é `Zapfl1x@M1n10`.
- **Fix 3.5 monitor** — alegado reativado em 26/04, hoje está derrubado há ~34h.

---

## Pendências reais (28/04/2026)

1. **Fix 1.4 (parcial)** — Rotacionar de fato a credencial MinIO
2. **Fix 3.5 (regressão)** — Investigar por que `wp_zapflix-monitor` voltou a falhar (exit 255) e reativar
3. **Fix 3.6 (parcial)** — Agendar os 7+ crons que existem como rota mas não estão no `crontab.supercronic`
4. **F-001** — Decidir escopo do sistema de afiliados (link público de indicação + comissão no checkout)

---

## Próximo passo sugerido

Atacar **Fix 3.5 (monitor)** primeiro — é regressão silenciosa e o sistema fica operacionalmente cego (mesmo problema descrito em BUG-008). Depois Fix 3.6 (crons faltantes — `plan-expiry`, `renewal-check`, `pix-followup`, `trial-followup` são receita direta) e Fix 1.4 MinIO (segurança).

F-001 fica para depois das pendências de segurança/operacional, conforme convenção do roadmap (Prioridade 1 → 2 → 3).
