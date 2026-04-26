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

### Fix 3.4 — Adicionar keyPrefix no Redis

```
Tarefa para Claude Code:

Arquivo: /root/Zapflix-Tech/lib/redis.ts

Adicionar keyPrefix na inicialização do cliente Redis:

ANTES:
const redis = new Redis(process.env.REDIS_URL);

DEPOIS:
const redis = new Redis(process.env.REDIS_URL, {
  keyPrefix: 'zapflix:'
});

Verificar se outros arquivos usam o cliente Redis diretamente
e se o keyPrefix não quebra nenhuma lógica de chave existente.
```

### Fix 3.5 — Reativar zapflix-monitor

```
Configurar no Easypanel (wp_zapflix-monitor → Environment):

MONITOR_PASSWORD=<senha-forte>
EVOLUTION_ALERT_KEY=<evolution-api-key>
EVOLUTION_ALERT_URL=http://evolution-api-2:8080
EVOLUTION_ALERT_INSTANCE=<nome-da-instância-ativa>
ALERT_PHONE=<numero-whatsapp-com-ddi>
APP_HEALTH_URL=http://wp_zapflix-web:3000/api/health
SECRET_KEY=<secret-fixo-32chars>

Depois: docker service update --force wp_zapflix-monitor
Verificar logs: docker service logs wp_zapflix-monitor --tail 30
```

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

### Fix 4.1 — Corrigir automations.workspace_id DEFAULT

```
Tarefa para Claude Code:

Criar migration: /root/Zapflix-Tech/migrations/097_fix_automations_default.sql

ALTER TABLE automations
ALTER COLUMN workspace_id DROP DEFAULT;

-- Verificar que não há automações com o UUID errado
SELECT COUNT(*) FROM automations
WHERE workspace_id = '00000000-0000-0000-0000-000000000001';

Registrar na tabela _migrations após aplicar.
```

### Fix 4.2 — Remover triggers duplicados em jobs

```
Tarefa para Claude Code:

A tabela jobs tem 3 triggers fazendo a mesma coisa:
- jobs_updated_at
- jobs_updated_at_trigger
- trg_jobs_updated_at

Criar migration para remover 2 dos 3:

ALTER TABLE jobs DROP TRIGGER IF EXISTS jobs_updated_at_trigger ON jobs;
ALTER TABLE jobs DROP TRIGGER IF EXISTS trg_jobs_updated_at ON jobs;

Manter apenas jobs_updated_at.
```

### Fix 4.3 — Limpar arquivos históricos da raiz

```
Tarefa para Claude Code:

Listar arquivos na raiz do projeto que não são código:
ls -la /root/Zapflix-Tech/ | grep -v "^d\|node_modules\|.git"

Mover para uma pasta /root/Zapflix-Tech/_archive/:
- all_migrations.sql
- iptv_migration.sql
- missing_*.sql
- Arquivo com nome "2026-04-24 09:00:00+00"
- Outros arquivos históricos

Não deletar, apenas mover.
```

---

## Checklist de conclusão por semana

### Semana 1 — Segurança crítica
- [x] Portas fechadas via DOCKER-USER (26/04/2026)
- [x] /api/debug/* com requireSuperAdmin (26/04/2026)
- [x] /api/migrate/* com requireSuperAdmin (26/04/2026)
- [x] Cron secret hardcoded removido do código (26/04/2026)
- [x] Cron secret hardcoded removido do crontab do servidor (27/04/2026)
- [ ] GitHub PAT revogado e renovado
- [ ] MinIO secret rotacionado (32 chars)
- [ ] CRON_SECRET rotacionado
- [x] /api/notifications com auth (27/04/2026)

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
- [ ] Redis com keyPrefix
- [ ] Monitor reativado e alertas funcionando
- [ ] Crons faltantes agendados

### Semana 4 — Qualidade
- [ ] automations DEFAULT corrigido
- [ ] Triggers duplicados removidos
- [ ] Arquivos históricos arquivados
- [ ] SECURITY.md atualizado com status dos fixes
