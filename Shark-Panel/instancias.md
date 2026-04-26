# instancias.md — Status das Instâncias WhatsApp

> Snapshot do estado das instâncias na Evolution API.
> **Atualizar manualmente** após incidentes ou mudanças de estado.
> Última atualização: 26/04/2026 18:15.

---

## Resumo

| Workspace | Total | Conectadas | Desconectadas |
|-----------|-------|-----------|---------------|
| Uniflix | 10 | 6 | 4 |
| Fábrica | 5 | 1 | 4 |
| Diario-das-Bruxas | 1 | 1 | 0 |
| Shark | 1 | 1 | 0 |
| Iphone | 1 | 0 | 1 |
| **Total** | **18** | **9** | **9** |

---

## Instâncias por workspace

### Uniflix (operadora principal)

| Instância | Status | Número | Observação |
|-----------|--------|--------|-----------|
| Amanda Soares | ✅ connected | +55 54 8910-8575 | — |
| Atendimentos Uniflix | ✅ connected | +55 51 9571-1876 | Principal atendimento |
| Denise | ✅ connected | +55 53 9968-1658 | Admin |
| Gabriele Garcia | ✅ connected | +55 53 8100-4072 | — |
| Iphone | ✅ connected | +55 53 8102-6076 | — |
| Juliana Lima | ✅ connected | +55 53 8102-4467 | — |
| Projeto Salmos | ✅ connected | +55 42 9136-5955 | — |
| Bruninhahh | ❌ disconnected | +55 21 9715-71136 | — |
| Uniflix Web | ❌ disconnected | webchat | Ver BUG-007 |
| Viniciusa30 | ❌ disconnected | +55 53 8101-9220 | — |

### Fábrica

| Instância | Status | Número | Observação |
|-----------|--------|--------|-----------|
| Marsbaks | ✅ connected | +55 53 8102-7733 | — |
| 01 | ❌ disconnected | — | Sem número — ver BUG-005 |
| cubot | ❌ disconnected | +55 53 8103-6826 | — |
| Samsung A30 | ❌ disconnected | +55 53 8102-7698 | — |
| suporte | ❌ disconnected | +55 53 9129-6251 | — |

### Diario-das-Bruxas

| Instância | Status | Número | Observação |
|-----------|--------|--------|-----------|
| Lucía Fernandes | ✅ connected | +55 53 9930-1202 | — |

### Shark

| Instância | Status | Número | Observação |
|-----------|--------|--------|-----------|
| Mayara Kook | ✅ connected | +55 48 9170-6979 | — |

### Iphone

| Instância | Status | Número | Observação |
|-----------|--------|--------|-----------|
| Disparo 01 | ❌ disconnected | — | Sem número — ver BUG-006 |

---

## Como atualizar este arquivo

```bash
# Consultar status atual direto do banco
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT wi.name, wi.status, w.name AS workspace, wi.phone_number, wi.updated_at
FROM whatsapp_instances wi
JOIN workspaces w ON w.id = wi.workspace_id
ORDER BY w.name, wi.name;"
```

---

## Diagnóstico de instância desconectada

```bash
# 1. Ver quando foi o último sync
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT name, status, updated_at, last_sync_at
FROM whatsapp_instances
WHERE name = 'NOME_DA_INSTANCIA';"

# 2. Ver jobs recentes da instância
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT type, status, last_error, created_at
FROM jobs
WHERE payload->>'instanceId' = 'ID_DA_INSTANCIA'
ORDER BY created_at DESC
LIMIT 10;"

# 3. Disparar sync manualmente
curl -s -H "x-cron-secret: \$CRON_SECRET" \
  https://appcineflick.com.br/api/cron/sync-instances
```

---

## Notas operacionais

- Evolution API em `evolution-api-2` (porta 8080 interna)
- Sync automático via cron `check-instance-health` e `sync-instances`
- Instâncias desconectadas precisam reconectar via QR Code no painel
- Instância tipo `webchat` é canal diferente — não usa QR Code
