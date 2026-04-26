# clientes.md — Workspaces Ativos

> Registro de todos os tenants do sistema Zapflix Tech.
> Status das instâncias WhatsApp por tenant: [[instancias]]
> Atualizado em 26/04/2026.

---

## Workspaces ativos

### Uniflix — Operadora principal

| Campo | Valor |
|-------|-------|
| UUID | `00000000-0000-0000-0000-000000000002` |
| Tipo | Operadora (workspace fixo do sistema) |
| Criado em | 21/02/2026 |
| Membros | 4 |
| Instâncias WhatsApp | 10 (6 conectadas, 4 desconectadas) |
| Contato principal | Denise (admin) |

**Observações:**
- Workspace da empresa operadora — não é cliente, é o próprio negócio
- Vinicius (superadmin) tem acesso a todos os workspaces
- UUID fixo hardcoded no sistema

---

### Fábrica

| Campo | Valor |
|-------|-------|
| UUID | `4e437249-b2cb-4572-a4ff-44f3f89d24d0` |
| Tipo | Cliente ativo |
| Criado em | 30/03/2026 |
| Membros | 1 |
| Instâncias WhatsApp | 5 (1 conectada, 4 desconectadas) |

**Observações:**
- 4 instâncias desconectadas — clientes precisam reconectar ou verificar se ainda usam
- Instância "01" sem número cadastrado (ver BUG-005)

---

### Iphone

| Campo | Valor |
|-------|-------|
| UUID | `09711328-25e0-4d06-94f1-5b1afc42e070` |
| Tipo | Cliente ativo |
| Criado em | 02/04/2026 |
| Membros | 1 |
| Instâncias WhatsApp | 1 (0 conectadas, 1 desconectada) |

**Observações:**
- Única instância ("Disparo 01") nunca foi conectada — sem número
- Verificar se cliente ainda está em processo de onboarding

---

### Shark

| Campo | Valor |
|-------|-------|
| UUID | `21461c56-3f40-40d2-8c42-00c6b1ba4c5f` |
| Tipo | Cliente ativo |
| Criado em | 17/04/2026 |
| Membros | 1 |
| Instâncias WhatsApp | 1 (conectada) |

**Observações:**
- Instância "Mayara Kook" conectada (+55 48 9170-6979)
- Workspace mais recente entre os clientes pagantes

---

### Diario-das-Bruxas

| Campo | Valor |
|-------|-------|
| UUID | `625bb524-7a8e-4e95-b3e7-6718fd8b216a` |
| Tipo | Cliente ativo |
| Criado em | 23/04/2026 |
| Membros | 2 |
| Instâncias WhatsApp | 1 (conectada) |

**Observações:**
- Instância "Lucía Fernandes" conectada (+55 53 9930-1202)
- Workspace mais novo — criado há 3 dias

---

## Workspace do sistema (não é cliente)

| UUID | Nome | Função |
|------|------|--------|
| `00000000-0000-0000-0000-000000000001` | Superadmin | Workspace interno do sistema — não usar como tenant |

---

## Totais

| Métrica | Valor |
|---------|-------|
| Workspaces de clientes | 4 (Fábrica, Iphone, Shark, Diario-das-Bruxas) |
| Total de membros (excl. Uniflix) | 5 |
| Total de instâncias (excl. Uniflix) | 8 |
| Instâncias conectadas (excl. Uniflix) | 3 |

---

## Como consultar dados atualizados

```bash
# Listar todos os workspaces com contagens
docker exec -i $(docker ps -q -f name=wp_zapflix-db.1) psql -U zapflix -d zapflix -c "
SELECT w.id, w.name, w.created_at,
  COUNT(DISTINCT wm.user_id) AS membros,
  COUNT(DISTINCT wi.id) AS instancias,
  COUNT(DISTINCT wi.id) FILTER (WHERE wi.status = 'connected') AS conectadas
FROM workspaces w
LEFT JOIN workspace_memberships wm ON wm.workspace_id = w.id
LEFT JOIN whatsapp_instances wi ON wi.workspace_id = w.id
GROUP BY w.id, w.name, w.created_at
ORDER BY w.created_at;"
```

---

## Template para novo cliente

Ao criar um novo workspace, registrar aqui:

```
### [Nome do cliente]

| Campo | Valor |
|-------|-------|
| UUID | (gerado automaticamente) |
| Tipo | Cliente ativo |
| Criado em | DD/MM/AAAA |
| Membros | 1 |
| Instâncias WhatsApp | 0 |
| Plano | — |
| Contato | — |
```
