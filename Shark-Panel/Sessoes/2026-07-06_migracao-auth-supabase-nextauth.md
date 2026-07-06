# 2026-07-06 — Migração Auth Supabase → NextAuth (FASE A-B-C Completa)

**Data:** 6 de julho de 2026  
**Tema principal:** Migração completa de autenticação Supabase legada para NextAuth + limpeza total do resíduo RLS/PostgREST

---

## Resumo Executivo

Concluída migração **IRREVERSÍVEL** de Supabase para NextAuth em 3 fases rigorosas (A: investigação, B: migração dados + code, C: limpeza resíduo). Sistema funcionando 100% sem dependências Supabase. **20 usuários legados** preservados em backup, **81 RLS policies** dropadas (28 Hermes preservadas), **4 roles** removidas, **schema auth** completamente eliminado.

---

## FASE A — Investigação e Auditoria (Pré-execução)

### Descobertas Críticas
1. **FK legada:** `workspace_memberships.user_id` apontava para `auth.users` (Supabase)
2. **Dual insert:** 6 endpoints inseriam em `auth.users` E `nextauth_users` simultaneamente
3. **20 usuários legados:** Apenas em `auth.users`, nunca migraram para NextAuth
4. **81 RLS policies:** 53 Supabase legadas + 28 Hermes (agent-gate)
5. **Type mismatch:** `nextauth_users.id` era TEXT, precisava ser UUID

### Decisão Arquitetural
- **Source of truth:** `nextauth_users` (Supabase vira resíduo morto)
- **Migration em 3 fases:** A (auditoria) → B (dados+code) → C (limpeza)
- **Rollback preparado:** Backup completo antes de cada DROP destrutivo

---

## FASE B — Migração de Dados e Código

### B1: Conversão nextauth_users.id TEXT → UUID
**Problema:** FK `workspace_memberships.user_id` era UUID, mas `nextauth_users.id` era TEXT.

**Solução:**
```sql
-- Migration reversível em transação
BEGIN;
ALTER TABLE nextauth_users ALTER COLUMN id TYPE UUID USING id::uuid;
COMMIT;
```

**Validação:** 0 erros, 48 usuários convertidos.

### B2: Migrar FK workspace_memberships.user_id
**Antes:** `REFERENCES auth.users(id)`  
**Depois:** `REFERENCES nextauth_users(id)`

**Steps:**
1. Drop FK antiga: `fk_workspace_memberships_user_id`
2. Criar FK nova: `REFERENCES nextauth_users(id) ON DELETE CASCADE`
3. Validar: 13 memberships intactos

### B3: Parar de Inserir em auth.users (6 Endpoints)
**Endpoints alterados:**
1. `/api/workspaces/members/create` — Criação de membros
2. `/api/workspaces/members` — Adicionar usuário existente
3. `/api/resellers/register` — Registro de revendedores
4. `/api/auth/signup` — Signup público (self-service) ⚠️
5. `/api/master/users` — Criação via master panel
6. `/api/admin/pending-users` — Aprovação de pendentes

**Mudança:**  
Remover blocos `INSERT INTO auth.users` + `ON CONFLICT DO NOTHING`.  
Manter apenas `INSERT INTO nextauth_users`.

**Bug crítico descoberto e corrigido:**  
`/api/auth/signup` tinha parâmetro `$4` (initialStatus) duplicado na mesma query → erro PostgreSQL "inconsistent types TEXT vs VARCHAR".

**Fix:**
```typescript
// ANTES (BUGADO):
VALUES ($1, $2, $3, $4, CASE WHEN $4 = 'approved' THEN NOW() ELSE NULL END)
params: [name, email, password, initialStatus]

// DEPOIS (CORRIGIDO):
VALUES ($1, $2, $3, $4, CASE WHEN $5 = 'approved' THEN NOW() ELSE NULL END)
params: [name, email, password, initialStatus, initialStatus]
```

**Validação end-to-end:**
- Signup automático: ✅ (status='approved', approved_at preenchido)
- Signup manual: ✅ (status='pending', approved_at NULL)
- auth.users: **49 → 49** (nenhum INSERT novo)

### B4: Correção ::text Casts Residuais
**Problema:** Queries antigas com `u.id::text` após conversão UUID quebravam.

**Arquivos corrigidos:** 7 adicionais (além dos 3 iniciais)
- `app/(dashboard)/my-stats/page.tsx`
- `app/(dashboard)/team/[userId]/page.tsx`
- `app/api/webhooks/amplopay/route.ts`
- `app/api/master/users/[id]/route.ts`
- `app/(dashboard)/funcionarios/page.tsx`
- `app/(dashboard)/analytics/overview/page.tsx`
- `app/api/iptv/trials/analytics/route.ts`

**Commit:** `9b2f9428`  
**Validação:** 0 erros "operator does not exist: uuid = text" após deploy.

---

## FASE C — Limpeza do Resíduo Supabase

### C1: REVOKE de Privileges
**Executado:**
```sql
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
REVOKE ALL ON ALL SEQUENCES/FUNCTIONS FROM anon, authenticated, service_role;
```

**Validação:**
- App funcionando ✅
- `anon` NÃO consegue mais ler nextauth_users/contacts ✅
- Nenhum grant restante ✅

### C2: Desligar Authenticator
```sql
ALTER ROLE authenticator NOLOGIN;
```

**Validação:**
- App funcionando ✅
- Authenticator bloqueado ✅

### C3: Remover Serviço PostgREST
**Verificações:**
- Logs últimos 30 dias: **0 linhas** (serviço morto)
- Código: **Nenhuma referência** a `wp_zapflix-postgrest.jomik8.easypanel.host`
- Réplicas: **0/0**

**Executado:**
```bash
docker service rm wp_zapflix-postgrest
```

### C4: DROP de 81 RLS Policies (preservando Hermes)
**Backup gerado:**  
`migrations/20260706_FASE_C_backup_policies_antes_drop.sql` (18KB, 146 linhas)

**DROP executado:**
```sql
-- 53 policies Supabase legadas (script gerado dinamicamente)
DROP POLICY IF EXISTS audit_logs_select ON public.audit_logs;
DROP POLICY IF EXISTS conversations_select ON public.conversations;
-- ... 51 outras
```

**Resultado:**
- **81 policies** → **28 policies** (só Hermes)
- **0 policies legadas** restantes ✅

**Validação agent-gate:**
- Workspace correto: 26.671 contacts ✅
- Cross-workspace: 0 contacts (bloqueado por RESTRICTIVE) ✅

### C5: DROP de 4 Roles Supabase
**Dependências encontradas:** 3 (grants em `auth.users`)

**REVOKE pré-DROP:**
```sql
REVOKE ALL ON auth.users FROM anon, authenticated, service_role;
```

**DROP executado:**
```sql
DROP ROLE authenticator;
DROP ROLE anon;
DROP ROLE authenticated;
DROP ROLE service_role;
```

**Validação:**
- App funcionando ✅
- Roles removidas ✅

### C6: DROP SCHEMA auth CASCADE
**Backup gerado:**  
`/root/backups/auth_schema_backup_20260706_202809.dump` (9.0KB, PostgreSQL custom dump)

**Backup copiado para MinIO:**  
`s3://zapflix-media/backups/auth_schema_backup_20260706_202809.dump` ✅

**Verificações pré-DROP:**
- FKs apontando para auth.*: **0** ✅

**DROP executado:**
```sql
DROP SCHEMA auth CASCADE;
```

**CASCADE removeu:**
- Tabela `auth.users` (20 usuários legados)
- Function `auth.uid()`
- Function `auth.role()`

**Validação end-to-end:**
- `/api/version`: 200 OK ✅
- contacts: 29.194 ✅
- workspace_memberships: Dados OK ✅
- Signup funcionando ✅
- `auth.users` NÃO EXISTE MAIS ✅

---

## Infraestrutura

### Deploy Automation
**Descoberta:** `wp_zapflix-web` NÃO auto-deploya via Easypanel git push.

**Solução:** Script `deploy-web.sh` criado:
```bash
#!/bin/bash
git pull
docker build -t zapflix-tech:latest --build-arg GIT_SHA=$(git rev-parse HEAD) .
docker service update --image zapflix-tech:latest --force wp_zapflix-web
# Polling /api/version até SHA bater (timeout 180s)
```

**Validação:** SHA em `/api/version` confirmado após cada deploy.

### Deploy Watchdog
**Feature:** Monitor automático de deploy + alertas Telegram por escopo.

**Funcionamento:**
- A cada 15s: verifica `/api/version`
- Compara SHA esperado (do git) vs SHA real (da API)
- Alerta Telegram se divergir por >5min

---

## Migrations Criadas

```sql
-- 20260706_FASE_C_backup_policies_antes_drop.sql
-- Backup de todas 81 policies (28 Hermes + 53 legadas)

-- auth_schema_backup_20260706_202809.dump
-- Backup completo do schema auth (PostgreSQL custom dump)
```

---

## Decisões Arquiteturais Críticas

1. **Source of truth:** nextauth_users (irreversível)
2. **Backup antes de DROP:** Sempre (policies, schema auth)
3. **Validação entre fases:** App + queries + agent-gate em CADA passo
4. **Preservar Hermes:** 28 policies agent-gate intocadas
5. **CASCADE consciente:** Confirmar 0 FKs antes de DROP SCHEMA

---

## Bugs Críticos Descobertos e Corrigidos

1. **Signup parameter duplication:** `$4` usado 2x na mesma query → tipo inconsistente
2. **::text casts residuais:** 7 arquivos com casts antigos após UUID conversion
3. **Cache de config:** `signup_approval_required` cached por 5min → restart necessário
4. **Deploy não automático:** wp_zapflix-web não auto-deploya → script manual criado

---

## Pendências em Aberto

**Nenhuma.** Migração 100% completa. Sistema rodando sem Supabase.

---

## Comandos Importantes

### Confirmar que auth.users não existe mais
```sql
SELECT * FROM auth.users;
-- ERROR: relation "auth.users" does not exist
```

### Restore backup (se necessário)
```bash
docker exec -i $(docker ps -q --filter "name=wp_zapflix-db") \
  pg_restore -U zapflix -d zapflix < /root/backups/auth_schema_backup_20260706_202809.dump
```

### Deploy manual
```bash
./scripts/deploy-web.sh
```

---

## Métricas Finais

- **auth.users:** 49 → **DROPADO** (0 inserts na Fase B3)
- **nextauth_users:** 48 (source of truth)
- **Policies:** 81 → 28 (só Hermes)
- **Roles:** 4 → 0 (Supabase eliminado)
- **Schema auth:** DROPADO ✅
- **Backup:** 9.0KB (seguro em MinIO + local)

---

## Conclusão

Migração **IRREVERSÍVEL e BEM-SUCEDIDA**. Sistema 100% NextAuth. Resíduo Supabase completamente eliminado. Rollback disponível via backup (mas não necessário — tudo funcionando).
