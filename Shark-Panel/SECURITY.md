# SECURITY.md — Zapflix Tech

> Resultado da auditoria de segurança completa realizada em 25/04/2026.
> **Nenhuma alteração foi feita durante a auditoria — tudo ainda está aberto.**
> Use [[FIXES]] para o plano de correção. Ver infra completa em [[ARCHITECTURE]].

---

## Resumo executivo

A postura de segurança atual depende **exclusivamente** do middleware NextAuth + filtros `WHERE workspace_id` na camada Node. As três defesas em profundidade que deveriam existir (RLS no banco, role limitado para a app, isolamento de rede) **não funcionam na prática**.

**Causa raiz:** migração Supabase → NextAuth foi incompleta. Containers, schemas, roles, JWT secrets e PostgREST ficaram rodando sem manutenção, dobrando a superfície de ataque.

---

## 🔴 CRÍTICO-1 — Exploração direta da internet (sem login)

### C1.1 — Portas abertas sem firewall efetivo

UFW está configurado mas **Docker bypassa o iptables**, expondo diretamente:

| Porta | Serviço | Risco |
|-------|---------|-------|
| 5433 | PostgreSQL PRINCIPAL (user zapflix, superuser) | Brute-force → controle total do banco |
| 6379 | Redis (compartilhado com Evolution API) | Leitura/escrita de filas |
| 8000 | Supabase Kong gateway (legado) | Gateway Supabase ativo |
| 8443 | Supabase Kong TLS (legado) | Gateway Supabase ativo |
| 9000 | MinIO S3 | Brute-force → bucket total |
| 33060 | MySQL checkout (X Protocol) | Banco do checkout público |
| 3000 | Easypanel UI | Painel admin de toda infraestrutura |

**Mitigação:** adicionar regra no `DOCKER-USER` chain do iptables (UFW não é suficiente):
```bash
iptables -I DOCKER-USER -p tcp -m multiport \
  --dports 5432,5433,6379,6543,8000,8443,9000,33060,3000 -j DROP
```

### C1.2 — PostgREST público sem autenticação

URL: `https://wp-zapflix-postgrest.jomik8.easypanel.host`

Sem token JWT, cai no role `anon` que tinha SELECT em **20 tabelas críticas** incluindo:
- `nextauth_users` — email e dados de todos os usuários do sistema
- `contacts` — nome + telefone de **todos os clientes de todos os tenants**
- `messages`, `conversations` — histórico completo de conversas cross-tenant

**✅ Corrigido em 27/04/2026** — serviço `zapflix-postgrest` desligado no Easypanel.
Role `anon` eliminado da superfície de ataque junto com o serviço.

### C1.3 — PGRST_JWT_SECRET vazado → bypass total do banco

O secret do PostgREST estava visível via `docker service inspect`. Com ele era possível forjar um JWT com `role: service_role` e ter acesso irrestrito a todas as tabelas via PostgREST, ignorando RLS.

**✅ Corrigido em 27/04/2026** — eliminado junto com o desligamento do PostgREST (C1.2).

### C1.4 — GitHub PAT em texto plano no servidor

```
/root/Zapflix-Tech/.git/config:
url = https://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@github.com/viniciusfmk26/Zapflix-Tech
```

Acesso de escrita ao repositório. Qualquer pessoa com acesso ao servidor pode inserir código malicioso que será deployado no próximo CI/CD.

**Mitigação:** revogar imediatamente em `github.com/settings/tokens` e usar deploy keys ou GitHub Actions secrets.

### C1.5 — Endpoints sem autenticação

```
/api/debug/test-download?url=...   → SSRF ativo (fetch para rede interna)
/api/debug/failed-jobs             → jobs cross-tenant sem auth
/api/debug/media-check             → mídias S3 cross-tenant sem auth
/api/migrate/reset-all-data        → wipe do banco sem auth
/api/migrate/reset-admin-password  → reset de senha sem auth
/api/notifications (GET/PATCH) → ✅ auth adicionada em 27/04/2026 (commit 67ca9470)
/api/automations/funis/enroll      → spam WhatsApp sem auth
```

**Mitigação:** adicionar `requireSuperAdmin()` ou verificação de `CRON_SECRET` em todos esses endpoints.

### C1.6 — Cron secret hardcoded

```javascript
// Em 25 arquivos de cron:
const accepted = new Set([
  process.env.CRON_SECRET,
  process.env.CRON_TOKEN,
  'zapflix2026'  // ← HARDCODED
].filter(Boolean));
```

Qualquer pessoa pode disparar qualquer cron sem credencial:
```bash
curl -H "x-cron-secret: zapflix2026" \
  https://appcineflick.com.br/api/cron/monthly-payroll
```

**Mitigação:** remover o valor hardcoded e usar apenas `process.env.CRON_SECRET`.

**✅ Corrigido em 26/04/2026** — removido de 3 arquivos residuais:
- `app/api/cron/trial-followup/route.ts`
- `app/api/cron/sigma-backfill-24h/route.ts`
- `app/api/cron/promote-expired-trials/route.ts`

Commit: `239b660f` — deploy aplicado via `docker service update --force wp_zapflix-web`.

**✅ Corrigido em 27/04/2026** — `zapflix2026` também estava hardcoded no crontab do servidor em 2 entradas (`trial-followup` e `promote-expired-trials`). Substituído pelo `CRON_TOKEN` real (49 chars) via script sem exposição do valor.

### C1.7 — MinIO com credencial fraca e bucket público

```
S3_ACCESS_KEY=zapflixadmin
S3_SECRET_KEY=Zapfl1x@M1n10  (10 chars, padrão previsível)
```

Bucket `zapflix-media` é público (sem assinatura de URL). Credencial fraca permite brute-force na porta 9000.

**Mitigação:** rotacionar secret para 32+ chars aleatórios.

### C1.8 — Supabase Kong com JWT hardcoded até 2036

Container `supabase-kong` rodando com:
- `SUPABASE_SERVICE_KEY` (role=service_role, exp=2036) em texto plano
- `SUPABASE_ANON_KEY` idem
- Dashboard basic-auth: `supabase / hD3LV5X3QsP9Oyr_NijvSg`

**Mitigação:** desligar o stack Supabase legado (não há dados reais nele).

---

## 🔴 CRÍTICO-2 — Requer sessão válida para explorar

### C2.1 — IDOR analytics (12 rotas)

Rotas aceitam `?workspace_id=` da query string sem validar membership:

```typescript
// Código problemático:
const workspaceId = searchParams.get('workspace_id') || await getWorkspaceId();
```

Afetadas: `/api/analytics/churn`, `/revenue`, `/overview`, `/heatmap`, `/instances`, `/funnel`, e mais.

Qualquer usuário logado vê dados financeiros de qualquer tenant.

### C2.2 — IDOR checkout/orders/cancel

`PATCH /api/checkout/orders/[id]/cancel` não inclui `workspace_id` na query de UPDATE.

### C2.3 — handleSyncContacts (Worker)

```typescript
// Sem workspace_id no UPDATE final:
UPDATE contacts SET name=$1, avatar_url=$2
WHERE phone_e164=$3 OR phone=$4
// ← falta AND workspace_id=$5
```

Sync de instância do tenant A pode sobrescrever dados de contatos do tenant B com mesmo número.

### C2.4 — delete_duplicate_trials e delete_expired_trials

Functions com `SECURITY DEFINER` que fazem DELETE global sem filtro de workspace:

```sql
-- Problemático:
DELETE FROM iptv_trials
WHERE contact_phone = $1
AND started_at < (SELECT MAX(started_at) FROM iptv_trials WHERE contact_phone = $1);
-- ← sem AND workspace_id = $X
```

Trial do tenant A pode ser deletado se tenant B tem started_at mais recente para o mesmo telefone.

### C2.5 — RLS 100% decorativa

```sql
-- Role da aplicação:
zapflix | rolsuper=t | rolbypassrls=t
```

O role `zapflix` bypassa todas as 53 políticas RLS. Elas existem mas não protegem nada para a aplicação.

Adicionalmente, policies "boas" usam `is_workspace_member()` e `get_workspace_role()` que dependem de `auth.uid()` do Supabase — retornam NULL após a migração para NextAuth.

---

## 🟠 MÉDIO — Risco operacional

### M1 — Zero backups

Não existe nenhum backup automático de:
- PostgreSQL principal (530 MB e crescendo)
- MySQL checkout
- MinIO (mídias dos clientes)

Em caso de incidente (ransomware via portas expostas), zero recovery possível.

**✅ Corrigido em 27/04/2026** — `/root/backup.sh` criado com `pg_dump | gzip` (337 MB por execução).
Agendado via crontab: `0 3 * * *` com retenção automática de 7 dias em `/root/backups/`.
Log em `/root/backup.log`. MySQL e MinIO ainda sem backup (pendente).

### M2 — short_links com PRNG previsível

```typescript
// lib/short-url.ts:
Math.random()  // ← não-criptográfico, previsível
```

3.891 links gerados em 12 dias. `target_url` contém `?nome=<nome>&whatsapp=<celular>`. Enumeração em `appcineflick.com.br/r/XXXXXX` vaza PII de clientes (LGPD).

**Mitigação:** substituir por `crypto.randomBytes(4).toString('hex')`.

### M3 — Redis sem keyPrefix

```typescript
// lib/redis.ts:
new Redis(REDIS_URL)  // ← sem keyPrefix
```

Keyspace compartilhado com Evolution API. Comprometimento da Evolution permite leitura/escrita de filas Zapflix.

**Mitigação:** adicionar `keyPrefix: 'zapflix:'`.

### M4 — Banco crescendo sem retenção

| Tabela | Tamanho | Retenção |
|--------|---------|---------|
| audit_logs | 347 MB | Nenhuma |
| processed_events | 127 MB | Nenhuma |
| worker_runs | 44 MB | Nenhuma |

**Mitigação:** cron de limpeza para registros > 90 dias.

### M5 — automations.workspace_id com DEFAULT errado

```sql
DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
-- ↑ UUID do superadmin, não do workspace do tenant
```

Automações criadas sem workspace explícito ficam no workspace do superadmin.

### M6 — Monitor offline há 3+ semanas

`wp_zapflix-monitor` com 0/1 réplicas. Exit code 255.
Nenhum alerta de WhatsApp sendo disparado. Sistema cego operacionalmente.

### M7 — 14 containers Supabase legados rodando

```
supabase-db, supabase-kong, supabase-auth (gotrue),
supabase-storage, supabase-studio, supabase-pooler,
supabase-rest, supabase-edge-functions, supabase-imgproxy,
supabase-meta, supabase-vector, supabase-analytics,
realtime-dev, supabase-inbucket
```

Confirmado: sem dados reais. Apenas superfície de ataque e consumo de recursos.

**✅ Corrigido em 27/04/2026** — todos os 13 containers derrubados via `docker compose down` em dois passos (compose file: `/root/supabase-docker/docker/docker-compose.yml`). Banco confirmado vazio (0 rows) antes do shutdown. App respondendo HTTP 200 após o desligamento.

### M8 — MAX_PRICE_CENTS hardcoded

```typescript
const MAX_PRICE_CENTS = 20000; // R$ 200
```

Bloqueia criação de planos vitalícios acima de R$ 200.

### M9 — Migrations sem registro

- 91 arquivos no disco
- 50 registrados na tabela `_migrations`
- 41 SQLs aplicados manualmente sem registro
- Migration 091 ausente do disco

Schema sem auditabilidade. Onboarding e disaster recovery comprometidos.

---

## 🟡 BAIXO — Dívida técnica

- `worker.ts` com 7.669 linhas (monolítico)
- 579 rotas de API (5x o esperado para o escopo)
- 3 triggers duplicados em `jobs` (custo 3x nos UPDATEs)
- DDL em runtime (`ALTER TABLE` em todo request em algumas rotas)
- `lib/evolution/client.ts` dead code (URL errada, não é usado)
- `lib/queue/automation-queue.ts` dead code BullMQ
- 2 lockfiles conflitantes (npm + pnpm)
- 60+ arquivos históricos na raiz
- 127 GB Docker reclaimable
- `package.json` name ainda "my-v0-project"
- `api_key` aceito via querystring em `/api/rotation`
- Índices duplicados em `messages` e `conversations`

---

## ✅ Pontos positivos

- Middleware NextAuth protege 95%+ das rotas
- 29/29 rotas master com `requireSuperAdmin()` server-side
- `auth.ts` correto (bcrypt, bloqueio pending/rejected)
- Crons todos protegidos por CRON_TOKEN
- `copy-settings` usa transação atômica
- Validação Zod em todas as rotas tRPC do checkout
- Sigma provision com fallback correto
- Failover de instâncias implementado
- `validate_and_normalize_phone` sólido com whitelist de DDD
- supabase-db confirmado VAZIO (sem dados reais de clientes)

---

## Status dos achados

| ID | Achado | Severidade | Status |
|----|--------|------------|--------|
| C1.1 | Portas expostas sem firewall | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C1.2 | PostgREST público | 🔴 Crítico | ✅ Corrigido (27/04/2026) |
| C1.3 | PGRST_JWT_SECRET vazado | 🔴 Crítico | ✅ Corrigido (27/04/2026) |
| C1.4 | GitHub PAT em texto plano | 🔴 Crítico | ⏳ Aberto |
| C1.5 | Endpoints sem auth | 🔴 Crítico | ⚠️ Parcial — /notifications corrigido (27/04/2026); /automations/funis/enroll pendente |
| C1.6 | Cron secret hardcoded | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C1.7 | MinIO credencial fraca | 🔴 Crítico | ⏳ Aberto |
| C1.8 | Supabase Kong JWT 2036 | 🔴 Crítico | ✅ Corrigido (27/04/2026) |
| C2.1 | IDOR analytics | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C2.2 | IDOR checkout/cancel | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C2.3 | handleSyncContacts | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C2.4 | delete_*_trials cross-tenant | 🔴 Crítico | ✅ Corrigido (26/04/2026) |
| C2.5 | RLS decorativa | 🔴 Crítico | ⏳ Aberto |
| M1 | Zero backups | 🟠 Médio | ✅ Corrigido (27/04/2026) |
| M2 | short_links PRNG | 🟠 Médio | ✅ Corrigido (26/04/2026) |
| M3 | Redis sem keyPrefix | 🟠 Médio | ⏳ Aberto |
| M4 | Banco sem retenção | 🟠 Médio | ⏳ Aberto |
| M5 | automations DEFAULT errado | 🟠 Médio | ⏳ Aberto |
| M6 | Monitor offline | 🟠 Médio | ⏳ Aberto |
| M7 | Supabase legado rodando | 🟠 Médio | ✅ Corrigido (27/04/2026) |
| M8 | MAX_PRICE hardcoded | 🟠 Médio | ⏳ Aberto |
| M9 | Migrations sem registro | 🟠 Médio | ⏳ Aberto |

> Atualizar esta tabela conforme fixes são aplicados.
