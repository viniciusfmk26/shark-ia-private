# FIXES.md — Plano de Execução

> Plano priorizado com prompts prontos para o Claude Code executar.
> **Cada semana é independente — pode ser executada separadamente.**
> Antes de qualquer fix: fazer snapshot do servidor no painel do provedor.
> Relacionado: [[SECURITY]] | [[RUNBOOK]]

---

## Como usar este documento

1. Abrir Claude Code no servidor (`/root/Zapflix-Tech`)
2. Copiar o prompt da seção desejada
3. Colar no Claude Code e aguardar execução
4. Verificar resultado antes de passar para o próximo

---

## SEMANA 1 — Segurança crítica (sem downtime)

### Fix 1.1 — Fechar portas expostas via DOCKER-USER

**Risco se não corrigir:** qualquer pessoa na internet pode se conectar ao Postgres, Redis, MinIO e MySQL.

```
Executar no servidor (não é código do projeto):

# Fechar portas críticas sem derrubar serviços
iptables -I DOCKER-USER -p tcp -m multiport \
  --dports 5433,6379,8000,8443,9000,33060,3000 \
  -j DROP

# Verificar se regra foi aplicada
iptables -L DOCKER-USER -n --line-numbers

# Persistir regra (Ubuntu)
apt-get install -y iptables-persistent
netfilter-persistent save

# Testar que serviços internos ainda funcionam
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix -c "SELECT 1;"
```

### Fix 1.2 — Adicionar auth nos endpoints /api/debug/* e /api/migrate/*

```
Tarefa para Claude Code:

Adicionar requireSuperAdmin() no início de TODAS as rotas
dentro de /root/Zapflix-Tech/app/api/debug/ e
/root/Zapflix-Tech/app/api/migrate/.

Para cada arquivo route.ts nessas pastas:
1. Importar: import { requireSuperAdmin } from '@/lib/auth/admin'
2. Adicionar no início de cada handler GET/POST/PUT/DELETE:
   await requireSuperAdmin(request);
3. Envolver em try/catch retornando 401 se lançar erro

Verificar que /api/debug/test-download (SSRF) também foi protegido.
Listar todos os arquivos modificados ao final.
```

### Fix 1.3 — Remover cron secret hardcoded

```
Tarefa para Claude Code:

Em /root/Zapflix-Tech/app/api/cron/ existem 25 arquivos route.ts.
Todos têm este padrão problemático:

const accepted = new Set([
  process.env.CRON_SECRET,
  process.env.CRON_TOKEN,
  'zapflix2026'  // ← REMOVER ESTA LINHA
].filter(Boolean));

Remover a string 'zapflix2026' de todos os arquivos.
Não alterar mais nada.
Listar os arquivos modificados.
```

### Fix 1.4 — Rotacionar credenciais expostas

**Fazer manualmente no Easypanel + GitHub:**

```
1. GitHub PAT:
   - Ir em github.com/settings/tokens
   - Revogar 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
   - Criar novo token com escopo mínimo (só repo)
   - Atualizar no Easypanel (env do zapflix-web)

2. MinIO:
   - Easypanel → zapflix-minio → Environment
   - S3_SECRET_KEY: gerar 32 chars aleatórios
     python3 -c "import secrets; print(secrets.token_hex(16))"
   - Atualizar em zapflix-web, zapflix-worker, zapflix-cron

3. CRON_SECRET:
   - Gerar novo: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
   - Atualizar em zapflix-web (env) e zapflix-cron (env)

4. Senha Postgres (opcional — requer downtime):
   - Agendar para manutenção planejada
```

### Fix 1.5 — Proteger /api/notifications

```
Tarefa para Claude Code:

Arquivo: /root/Zapflix-Tech/app/api/notifications/route.ts

Adicionar verificação de autenticação no início de cada handler
(GET, POST, PATCH, DELETE):

const session = await auth();
if (!session?.user?.id) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
}

Importar auth de '@/auth'.
Não alterar lógica de negócio existente.
```

### Fix 1.6 — Auth em /api/automations/funis/enroll ✅ 26/04/2026

**Concluído.** `POST /api/automations/funis/enroll` não tinha verificação de autenticação — qualquer pessoa na internet podia inscrever números de telefone em funis de WhatsApp, gerando spam massivo.

`import { auth }` já estava presente mas a verificação de sessão estava ausente no handler POST.

**Correção:** adicionado no início do handler:
```typescript
const session = await auth();
if (!session?.user?.id) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
}
```

Arquivo alterado: `app/api/automations/funis/enroll/route.ts`

---

## SEMANA 2 — Dados e banco

### Fix 2.1 — Corrigir IDOR analytics

```
Tarefa para Claude Code:

Nas seguintes rotas, o parâmetro ?workspace_id= é aceito sem validar
que o usuário logado pertence ao workspace:

app/api/analytics/churn/route.ts
app/api/analytics/revenue/route.ts
app/api/analytics/overview/route.ts
app/api/analytics/heatmap/route.ts
app/api/analytics/instances/route.ts
app/api/analytics/funnel/route.ts

Para cada arquivo:
1. Obter workspaceId da sessão (session.user.workspaceId) em vez da query string
   OU validar que o workspace_id da query está na lista de workspaces do usuário
2. Padrão correto:
   const session = await auth();
   const workspaceId = session.user.workspaceId; // vem do token

Não aceitar workspace_id arbitrário da query string sem validação.
```

### Fix 2.2 — Corrigir handleSyncContacts no worker

```
Tarefa para Claude Code:

Arquivo: /root/Zapflix-Tech/apps/worker/src/worker.ts
Função: handleSyncContacts (buscar por esse nome)

O UPDATE final de contacts não inclui workspace_id:
UPDATE contacts SET name=$1, avatar_url=$2
WHERE phone_e164=$3 OR phone=$4

Corrigir para:
UPDATE contacts SET name=$1, avatar_url=$2
WHERE (phone_e164=$3 OR phone=$4)
AND workspace_id=$5

Garantir que workspace_id está disponível no contexto da função
(vem do payload do job ou da instância).
```

### Fix 2.2b — Corrigir IDOR checkout/orders/cancel ✅ 26/04/2026

**Concluído.** `POST /api/checkout/orders/[id]/cancel` não filtrava por `workspace_id` no UPDATE.

Qualquer owner/admin autenticado podia cancelar pedidos de outros tenants conhecendo o ID.

**Correção:** `workspaceId` resolvido via `getWorkspaceIdSafe()` fora do bloco de permissão
e adicionado ao `WHERE id = $1 AND workspace_id = $2` do UPDATE.

Arquivo alterado: `app/api/checkout/orders/[id]/cancel/route.ts`

### Fix 2.3 — Corrigir functions do banco cross-tenant

```
Tarefa para Claude Code:

Conectar no banco e corrigir as functions:

1. delete_duplicate_trials — adicionar filtro workspace_id
2. delete_expired_trials — adicionar filtro workspace_id

Verificar o código atual de cada function:
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix -c "
  SELECT proname, pg_get_functiondef(oid)
  FROM pg_proc
  WHERE proname IN ('delete_duplicate_trials', 'delete_expired_trials')
  AND pronamespace = 'public'::regnamespace;"

Depois gerar o ALTER FUNCTION com workspace_id no WHERE.
Aplicar via migration (criar arquivo 095_fix_trial_functions.sql).
```

### Fix 2.4 — Criar política de retenção do banco ✅ 26/04/2026

**Concluído.** Migration executada e cron implantado.

Resultados da limpeza inicial:
- `processed_events`: 248.988 registros removidos
- `worker_runs`: 121.715 registros removidos
- `audit_logs`: 0 (dados recentes, < 90 dias)
- `jobs`: 0 (dados recentes)

Arquivos criados:
- `migrations/096_retention_policy.sql` — limpeza inicial
- `app/api/cron/db-retention/route.ts` — cron semanal (domingo 4h)

Política ativa:
- `audit_logs` → 90 dias
- `processed_events` → 30 dias
- `worker_runs` → 14 dias
- `jobs` (succeeded/failed/dead) → já tratado pelo purge-jobs

### Fix 2.5 — Configurar backups automáticos

```
Executar no servidor:

# Criar script de backup
cat > /root/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/root/backups
mkdir -p $BACKUP_DIR

# Backup Postgres
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  pg_dump -U zapflix zapflix | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Manter apenas os últimos 7 dias
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup concluído: $DATE"
EOF

chmod +x /root/backup.sh

# Adicionar ao crontab (diário às 3h)
(crontab -l 2>/dev/null; echo "0 3 * * * /root/backup.sh >> /root/backup.log 2>&1") | crontab -

# Testar
/root/backup.sh
```

---

## SEMANA 3 — Operacional e manutenção

### Fix 3.1 — Desligar stack Supabase legado

```
Executar no servidor (confirmar antes que não há dependências):

# Listar containers Supabase
docker ps | grep supabase

# Parar containers (NÃO são Swarm services — são docker compose)
cd /root/supabase-docker
docker compose down

# Verificar que app principal continua funcionando
curl -s https://appcineflick.com.br/api/health | head -5

# Se OK, remover volumes (CUIDADO — irreversível)
# docker compose down -v  ← só depois de confirmar que está tudo ok
```

### Fix 3.2 — Desligar PostgREST

```
Executar no Easypanel:

1. Easypanel → wp → zapflix-postgrest
2. Clicar em "Disable" ou reduzir réplicas para 0
3. Verificar que app principal continua funcionando
4. Se OK, deletar o serviço

OU (via docker):
docker service scale wp_zapflix-postgrest=0
```

### Fix 3.3 — Corrigir short-url.ts ✅ 26/04/2026

**Concluído.** `Math.random()` substituído por `randomBytes` do Node crypto.

ALPHABET original preservado (`'abcdefghijkmnpqrstuvwxyz23456789'`, 32 chars = 2^5)
— `bytes[i] % 32` é uniforme em 0-255, sem bias modular.

Arquivo alterado: `lib/short-url.ts`

### Fix 3.4 — Adicionar keyPrefix no Redis ✅ 26/04/2026

**Concluído.** `keyPrefix: 'shark:'` adicionado na configuração do cliente ioredis em `lib/redis.ts`.

Todas as chaves geradas pelo Zapflix agora ficam prefixadas como `shark:messages:*`, isolando o keyspace do Evolution API que compartilha o mesmo Redis.

Arquivo alterado: `lib/redis.ts`

### Fix 3.5 — Reativar zapflix-monitor ✅ 26/04/2026

**Concluído.** Monitor estava offline com `PermissionError: [Errno 13] Permission denied` ao tentar acessar o Docker socket — o Dockerfile usa `appuser` (uid=1000) mas o socket `srw-rw----` exige pertencer ao grupo `docker`.

**Correção:** `docker service update --user root wp_zapflix-monitor` — serviço agora roda como root e acessa o socket normalmente.

**Status atual:**
- Flask respondendo `/api/health` com `{"status":"ok"}`
- Docker metrics: 63 containers monitorados (status `connected`)
- DB metrics: pool ativo, cache_hit_ratio 85%, 1572 MB
- `/api/metrics` retornando dados completos

### Fix 3.6 — Agendar crons faltantes

```
Tarefa para Claude Code:

Verificar o arquivo de crontab do supercronic:
cat /root/Zapflix-Tech/apps/cron/crontab

Adicionar os crons que não estão agendados:
- plan-expiry (verificar vencimentos diariamente)
- renewal-check (verificar renovações)
- pix-followup (follow-up de PIX pendentes)
- trial-followup (follow-up de trials)

Formato: 0 */6 * * * curl -s -H "x-cron-secret: $CRON_SECRET" \
  http://wp_zapflix-web:3000/api/cron/<nome>

Confirmar frequência adequada para cada cron antes de adicionar.
```

---

## SEMANA 4 — Qualidade e performance

### Fix 4.1 — Corrigir automations.workspace_id DEFAULT ✅ 27/04/2026

Migration aplicada: `migrations/097_fix_automations_workspace_default.sql`
`ALTER TABLE automations ALTER COLUMN workspace_id DROP DEFAULT;`
Verificado: 0 automações com o UUID do superadmin (sem contaminação de dados).

### Fix 4.2 — Remover triggers duplicados em jobs ✅ 27/04/2026

A tabela jobs tinha 3 triggers fazendo a mesma coisa (todos UPDATE BEFORE, funções idênticas):
- `jobs_updated_at` → `update_updated_at()` ← **mantido** (canônico, usado em 6 tabelas)
- `jobs_updated_at_trigger` → `update_updated_at_column()` ← removido
- `trg_jobs_updated_at` → `set_updated_at()` ← removido

Migration: `migrations/098_remove_duplicate_triggers.sql`
Aplicado em produção em 27/04/2026. Tabela jobs ficou com 1 trigger apenas.

### Fix 4.3 — Limpar arquivos históricos da raiz ✅ 27/04/2026

**Concluído.** 9 arquivos históricos movidos de `/root/` para `/root/archive/` (não deletados):

- `all_migrations.sql` (139 KB, Fev/2026)
- `iptv_migration.sql` (12 KB, Fev/2026)
- `missing_rpcs.sql` (1,1 KB, Fev/2026)
- `missing_tables.sql` (18 KB, Fev/2026)
- `zapflix-monitor.tar.gz` (22 KB, Fev/2026)
- `=`, `brand_logo_url`, `brand_name`, `team_note_categories:` (vazios/artefatos)

Preservados no lugar: `backup.sh` (ativo, Abr/2026), `superz_key` / `superz_key.pub` (chaves SSH).

### Fix 4.4 — 4 fixes de limpeza de código ✅ 27/04/2026

**Concluído.** 4 commits sem rebuild intermediário, 1 rebuild único no final.

**Fix 4.4a — api_key via querystring removido de /api/rotation**
- `app/api/rotation/_shared.ts`: função `isAuthorized` aceitava `?api_key=` na URL além do header `x-api-key`.
- Removido `fromQuery` — somente header é aceito agora. Evita vazamento de credencial em logs de acesso HTTP.

**Fix 4.4b — Lockfile conflitante removido**
- `package-lock.json` (14.472 linhas) coexistia com `pnpm-lock.yaml`. O Dockerfile prioriza `pnpm-lock.yaml`.
- `package-lock.json` deletado. Build usa exclusivamente pnpm.

**Fix 4.4c — package.json name corrigido**
- `"name": "my-v0-project"` (resíduo do gerador v0) → `"name": "shark-panel"`.

**Fix 4.4d — Dead code BullMQ removido**
- `lib/evolution/client.ts` — cliente HTTP para Evolution API em duplicata da implementação em `lib/groups/evolution.ts`. Zero importadores externos.
- `lib/queue/automation-queue.ts` — fila BullMQ (o projeto usa Postgres SKIP LOCKED, não BullMQ).
- `scripts/test-worker.ts` — script de teste que importava `automation-queue`; também removido.

Commits: `0a760e32`, `7de6b24a`, `1ea89237`, `52a3ff2f`, `9397dff1`

---

### Fix M9 — Registrar migrations históricas na tabela _migrations ✅ 27/04/2026

**Contexto:** A tabela `_migrations` já existia com estrutura diferente da planejada (coluna `name` em vez de `filename`, mais coluna `executed_at`). Havia 50 registros de 95 arquivos — 45 migrations aplicadas manualmente sem registro.

**Ação:**
- Verificado schema real: `id`, `name` (UNIQUE), `applied_at`, `executed_at`
- Inseridos 71 registros faltantes via `INSERT ... ON CONFLICT DO NOTHING`
- Total final: 121 registros (50 originais + 71 novos — inclui entradas legadas sem `.sql`)
- Todos os 95 arquivos `.sql` do disco confirmados como registrados

Operação exclusivamente no banco (sem alteração de código no repositório).

---

## Checklist de conclusão por semana

### Semana 1 — Segurança crítica
- [x] Portas fechadas via DOCKER-USER (26/04/2026)
- [x] /api/debug/* com requireSuperAdmin (26/04/2026)
- [x] /api/migrate/* com requireSuperAdmin (26/04/2026)
- [x] Cron secret hardcoded removido do código (26/04/2026)
- [x] Cron secret hardcoded removido do crontab do servidor (27/04/2026)
- [x] GitHub PAT revogado e renovado
- [x] MinIO secret rotacionado (32 chars)
- [x] CRON_SECRET rotacionado
- [x] /api/notifications com auth (27/04/2026)
- [x] /api/automations/funis/enroll com auth (26/04/2026)

### Semana 2 — Dados e banco
- [x] IDOR analytics corrigido (26/04/2026)
- [x] IDOR checkout/cancel corrigido (26/04/2026)
- [x] handleSyncContacts com workspace_id (26/04/2026)
- [x] delete_*_trials corrigidas (26/04/2026)
- [x] Política de retenção criada (26/04/2026)
- [x] Backups automáticos configurados (27/04/2026)

### Semana 3 — Operacional
- [x] Stack Supabase desligado (27/04/2026)
- [x] PostgREST desligado (27/04/2026)
- [x] short-url.ts usando crypto (26/04/2026)
- [x] Redis com keyPrefix (26/04/2026)
- [x] Monitor reativado e alertas funcionando (26/04/2026)
- [ ] Crons faltantes agendados

### Semana 4 — Qualidade
- [x] automations DEFAULT corrigido (27/04/2026)
- [x] Triggers duplicados removidos (27/04/2026)
- [x] Arquivos históricos arquivados (27/04/2026)
- [x] SECURITY.md atualizado com status dos fixes (27/04/2026)
- [x] 4 fixes de limpeza: api_key querystring, lockfile, package name, dead code BullMQ (27/04/2026)

---

## Features concluídas (fora do plano de fixes)

### Sales Brain — Rota /api/sales-brain/problems ✅ 26/04/2026

**Concluído.** A tela Sales Brain (`/sales-brain`) tem 8 abas de inteligência comercial. A aba Problemas consumia `/api/sales-brain/problems` mas a rota não existia — retornava 404 silenciosamente.

**Rota criada:** `app/api/sales-brain/problems/route.ts`

- `GET ?category=<opcional>` — lista problemas do workspace filtrados por categoria, retorna `{ problems, categories }`
- `POST { category, problem, solution }` — cria problema manual com `ON CONFLICT DO UPDATE` (evita duplicatas por workspace+problem)
- Validação de categoria contra enum do banco (`VALID_CATEGORIES`)
- Auth via `session + getWorkspaceIdSafe()` igual às outras 13 rotas do Sales Brain

**Tabela:** `app_problems_learned` (18 registros existentes, schema com `times_detected`, `success_rate`, `source: manual|ai_detected|agent_reported`)

**Nota:** a aba Problemas tem estado e fetch no frontend mas não tem TabsTrigger nem TabsContent na UI — a rota estava pronta antes da UI ser completada.

---

### Rota /api/settings/sessions/revoke ✅ 27/04/2026

`app/api/settings/sessions/revoke/route.ts` — POST `{ sessionId }`

Remove a sessão do array `workspace_settings.settings.security.sessions` via jsonb_agg com filtro por id. Auth via `getActiveWorkspaceId()`. Necessária para o botão "Revoke" na aba Security de Settings.

---

### Rota /api/checkout/config ✅ 27/04/2026

`app/api/checkout/config/route.ts` — GET e PUT

- GET: retorna todos os registros de `checkout_config` como objeto `{ key: value }`
- PUT: upsert de todos os pares enviados no body
- Auth via `isSuperAdmin()` (config global, sem workspace_id)
- Campos suportados: `amplopay_public_key`, `amplopay_secret_key`, `ga4_id`, `meta_pixel_id`, `meta_capi_token`, `head_scripts`, `body_scripts`, `fee_percent`, `fee_fixed`, `pix_key`, `support_whatsapp`, `webhook_secret`

---

### Decisões estratégicas 27/04/2026

**Domínio novo registrado:** sharkpanel.com.br

**Estrutura de subdomínios planejada:**
- sharkpanel.com.br → site institucional
- app.sharkpanel.com.br → painel dos clientes
- admin.sharkpanel.com.br → painel master (Vinicius)
- checkout.sharkpanel.com.br → links de pagamento
- api.sharkpanel.com.br → API

**Auditoria master vs cliente concluída:**
- 191 tabelas no banco
- 159 tabelas isoladas por workspace ✅
- 29/29 APIs master protegidas ✅
- 13 páginas no painel master
- Componentes órfãos: ElevenLabsTab, PlansModulesTab

**Problemas encontrados (prioridade):**
1. UUID superadmin hardcoded em 4+ arquivos
2. Guard /master/* só client-side
3. 4 implementações diferentes do check superadmin
4. Settings espalhadas em 3 lugares diferentes
5. audit-log duplicado (singular/plural)
6. /workspaces-map no painel cliente (deveria ser master)

**Plano de migração para sharkpanel.com.br:**
Etapa 1 — Corrigir autenticação superadmin
Etapa 2 — Configurar subdomínios no Easypanel
Etapa 3 — Atualizar código e variáveis de ambiente
Etapa 4 — Redirecionar appcineflick.com.br
