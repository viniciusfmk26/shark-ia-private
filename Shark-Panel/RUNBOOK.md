# RUNBOOK.md — Zapflix Tech

> Comandos prontos para operações do dia a dia.
> Todos testados no servidor 69.62.91.79 (Ubuntu 24, Docker Swarm).

---

## Deploy

### Deploy normal (via Easypanel)
```
Easypanel → wp → zapflix-web → Deploy
OU
Easypanel → wp → zapflix-worker → Deploy
```

### Deploy manual via CLI
```bash
# Forçar redeploy sem alterar código
docker service update --force wp_zapflix-web
docker service update --force wp_zapflix-worker

# Ver progresso do deploy
docker service ps wp_zapflix-web --no-trunc | head -5
```

### Rollback
```bash
# Ver imagens disponíveis
docker images | grep zapflix

# Rollback para imagem anterior
docker service update \
  --image easypanel/wp/zapflix-web:<tag-anterior> \
  wp_zapflix-web
```

---

## Monitoramento

### Status de todos os serviços
```bash
docker service ls
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep zapflix
```

### Logs em tempo real
```bash
# App principal
docker service logs wp_zapflix-web -f --tail 50

# Worker
docker service logs wp_zapflix-worker -f --tail 50

# Cron
docker service logs wp_zapflix-cron -f --tail 50

# Checkout
docker service logs wp_zapflix-checkout -f --tail 50
```

### Métricas de recursos
```bash
# CPU e memória de todos os containers
docker stats --no-stream

# Disco
df -h
du -sh /opt/zapflix-uploads/
```

---

## Banco de dados

### Conectar
```bash
docker exec -it $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix
```

### Jobs na fila (diagnóstico rápido)
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT type, status, COUNT(*) as total
FROM jobs
GROUP BY type, status
ORDER BY status, total DESC;"
```

### Jobs travados (running há mais de 30min)
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT id, type, workspace_id, locked_at, locked_by, last_error
FROM jobs
WHERE status = 'running'
AND locked_at < NOW() - INTERVAL '30 minutes'
ORDER BY locked_at;"
```

### Desbloquear jobs travados
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
UPDATE jobs
SET status = 'queued', locked_at = NULL, locked_by = NULL
WHERE status = 'running'
AND locked_at < NOW() - INTERVAL '30 minutes';"
```

### Tamanho das tabelas
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT
  relname AS tabela,
  pg_size_pretty(pg_total_relation_size(relid)) AS tamanho_total
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;"
```

### Backup manual
```bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  pg_dump -U zapflix zapflix | gzip > /root/backups/manual_$DATE.sql.gz
echo "Backup salvo: /root/backups/manual_$DATE.sql.gz"
```

### Restore de backup
```bash
# ⚠️ CUIDADO — destrói dados atuais
gunzip -c /root/backups/ARQUIVO.sql.gz | \
  docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix
```

---

## Worker

### Ver jobs processados hoje
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT type, status, COUNT(*) as total
FROM jobs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY type, status
ORDER BY total DESC;"
```

### Jobs com erro
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT id, type, workspace_id, last_error, created_at
FROM jobs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 20;"
```

### Reprocessar job específico
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
UPDATE jobs
SET status = 'queued', attempts = 0, last_error = NULL
WHERE id = '<UUID-DO-JOB>';"
```

---

## WhatsApp / Evolution API

### Ver instâncias ativas
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT name, status, workspace_id, updated_at
FROM whatsapp_instances
WHERE status = 'connected'
ORDER BY updated_at DESC;"
```

### Ver instâncias desconectadas
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT name, status, workspace_id, updated_at
FROM whatsapp_instances
WHERE status != 'connected'
ORDER BY updated_at DESC;"
```

---

## Crons

### Disparar cron manualmente
```bash
# Substituir <nome> pelo nome do cron e <CRON_SECRET> pelo valor real
curl -s -X GET \
  -H "x-cron-secret: <CRON_SECRET>" \
  https://appcineflick.com.br/api/cron/<nome>
```

### Crons disponíveis
```
check-instance-health  → verifica saúde das instâncias WhatsApp
purge-jobs            → limpa jobs antigos
sync-instances        → sincroniza instâncias com Evolution API
retry-failed-jobs     → reprocessa jobs com falha
plan-expiry           → verifica planos vencendo
renewal-check         → verifica renovações pendentes
pix-followup          → follow-up de PIX pendentes
trial-followup        → follow-up de trials
monthly-payroll       → folha de pagamento mensal
```

---

## MinIO (S3)

### Ver buckets
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-minio.1) \
  mc ls local/ 2>/dev/null || \
  curl -s http://localhost:9000/zapflix-media/ | head -20
```

### Espaço utilizado
```bash
docker exec -i $(docker ps -q -f name=wp_zapflix-minio.1) \
  mc du local/zapflix-media 2>/dev/null
```

---

## Diagnóstico de problemas comuns

### App não responde
```bash
# 1. Verificar se container está rodando
docker ps | grep zapflix-web

# 2. Ver logs de erro
docker service logs wp_zapflix-web --tail 100 | grep -i error

# 3. Ver se banco está acessível
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) \
  psql -U zapflix -d zapflix -c "SELECT 1;"

# 4. Forçar restart
docker service update --force wp_zapflix-web
```

### Worker parou de processar
```bash
# 1. Ver se worker está rodando
docker ps | grep zapflix-worker

# 2. Ver logs
docker service logs wp_zapflix-worker --tail 50

# 3. Ver jobs na fila
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c \
  "SELECT status, COUNT(*) FROM jobs WHERE created_at > NOW() - INTERVAL '1 hour' GROUP BY status;"

# 4. Verificar jobs travados e desbloquear
# (ver seção "Banco de dados" acima)

# 5. Restart do worker
docker service update --force wp_zapflix-worker
```

### Mensagem WhatsApp não enviou
```bash
# 1. Ver job específico (buscar por workspace_id ou created_at)
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT id, type, status, payload, last_error, created_at
FROM jobs
WHERE type = 'send_message'
AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 10;"

# 2. Ver instância WhatsApp do workspace
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT name, status FROM whatsapp_instances WHERE workspace_id = '<UUID>';"
```

### PIX não sendo confirmado
```bash
# 1. Ver checkout_orders pendentes
docker exec -i $(docker ps -q -f name=wp_zapflix-checkout-db.1 2>/dev/null || \
  docker ps -q -f name=zapflix-checkout-db) \
  mysql -u root zapflix_checkout -e \
  "SELECT id, customer_name, status, created_at FROM checkout_orders \
   WHERE status IN ('pending','created') ORDER BY created_at DESC LIMIT 10;"

# 2. Disparar reconciliação manualmente via painel admin do checkout
# claw.appcineflick.com.br → Reconciliar
```

---

## Acesso de emergência

### Se o app principal cair
```bash
# Acesso direto ao banco
docker exec -it $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix

# Ver usuários com senha para reset manual
SELECT id, email, status FROM nextauth_users;

# Reset de senha (gerar hash bcrypt antes)
-- UPDATE nextauth_users SET password = '<BCRYPT_HASH>' WHERE email = '<EMAIL>';
```

### Gerar hash bcrypt (para reset de senha)
```bash
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('NOVA_SENHA', 12).then(h => console.log(h));"
```

---

## Contatos e acessos

| Recurso | URL/Acesso |
|---------|------------|
| App principal | appcineflick.com.br |
| Painel master | appcineflick.com.br/master |
| Checkout público | checkout.appcineflick.com.br |
| Admin checkout (Manus) | claw.appcineflick.com.br |
| Easypanel | 69.62.91.79:3000 |
| MinIO Console | minio.zapflix.shop |
| PostgREST | wp-zapflix-postgrest.jomik8.easypanel.host |
| Monitor (quando ativo) | porta 5000 interna |
