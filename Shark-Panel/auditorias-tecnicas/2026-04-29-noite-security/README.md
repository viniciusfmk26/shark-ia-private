# Sessão Noturna 29/04/2026 — Hardening de segurança

Continuação após pausa pós-deploys do dia. Foco: auditoria + fixes de vulnerabilidades.

## Resumo executivo

**4 fixes em produção** após auditoria noturna autônoma de 5 áreas (workers, master/admin, multi-tenant amplo, secrets, áreas pendentes).

| Commit | Bug | Severidade |
|--------|-----|------------|
| fbbb99dc | B-SECRETS-AMPLOPAY-001 (token mask) | 🟢 BAIXA |
| 27cf4cfe | B-ADMIN-001 (3 endpoints admin) | 🔴 CRÍTICO |
| 91143f01 | B-INSTANCES-WEBHOOK-001 + B-ROTATION-STATS-001 | 🔴 CRÍTICO + 🟡 MÉDIO |

## Vulnerabilidades fechadas

### 🔴 CRÍTICO — Hardcoded secret 'zapflix-admin-2024'
- **Arquivo:** `app/api/admin/media-debug/route.ts`
- **Risco:** Acesso permanente sem rotação possível, expunha messages.raw_payload
- **Fix:** Trocar por `process.env.ADMIN_MIGRATION_SECRET`
- **Decisão:** NÃO rotacionar (repo privado, baixo risco)

### 🔴 ALTO — Zero auth em debug-jobs
- **Arquivo:** `app/api/admin/debug-jobs/route.ts`
- **Risco:** Qualquer user logado de qualquer tenant via últimos 20 jobs send_message globais
- **Fix:** Header `x-admin-secret` ou query param `?secret=...`

### 🟡 MÉDIO — Privilege escalation em fix-contact-plans
- **Arquivo:** `app/api/admin/fix-contact-plans/route.ts`
- **Risco:** Agent/viewer podia bulk_set_plan
- **Fix:** Role check via `getUserRole(workspaceId, userId)` da `lib/auth/rbac.ts`
- **Pegadinha:** Tabela é `workspace_memberships` (não `workspace_members`)

### 🔴 CRÍTICO — Cross-tenant webhook reconfiguration
- **Arquivo:** `app/api/instances/[id]/webhook/route.ts`
- **Risco:** User logado + UUID conhecido = ler/alterar webhook de outro tenant
- **3 queries vazando:**
  1. `SELECT settings FROM workspace_settings LIMIT 1` (cross-tenant settings)
  2. `SELECT * FROM whatsapp_instances WHERE id = $1` (info disclosure)
  3. `UPDATE whatsapp_instances SET webhook_url WHERE id = $1` (cross-tenant write)
- **Fix:** `getWorkspaceIdSafe()` + filtros `AND workspace_id = $N` em todas as 3

### 🟡 MÉDIO — rotation/stats sem workspace filter
- **Arquivo:** `app/api/rotation/stats/route.ts`
- **Risco:** Atacante com API key + phone exato vê stats de qualquer tenant
- **Fix:** JOIN workspaces + slug filter (padrão dos 3 endpoints irmãos)

## Auditoria noturna autônoma (5 áreas em paralelo)

Estrutura criada em `Shark-Panel/`:
- `mapas/` — 6 docs estruturais migrados de /root/
- `deep-dives/` — 9 análises profundas
- `auditorias-tecnicas/` — 3 auditorias noturnas
- `seguranca/` — 2 análises (multi-tenant, secrets)

### Métricas da auditoria
- 145 tabelas com workspace_id no schema
- 33 arquivos potencialmente vazando workspace_id (regex pessimista)
- 32/32 endpoints master protegidos ✅
- 25 endpoints /api/admin/*: 22 OK, 3 com fix
- 14 arquivos whatsapp_instances: 13 OK por design, 2 BUGS reais

## Pendentes catalogados (próxima sessão)

### 🔴 ALTA prioridade
- **6 arquivos messages sem workspace_id** — tabela com PII sensível
- **5 arquivos contacts sem workspace_id** — dados de leads

### 🟡 MÉDIA prioridade
- **sync/route.ts e sync-contacts/route.ts** — mesmo bug whatsapp_instances do webhook
- **payments/iptv_trials sem workspace_id** (~6 arquivos)
- **892 opps falso positivo IA** (worker.ts:6504)
- **Phone format chaos** refactor (sales_opps JID 59% / digits 41%)

### 🟢 BAIXA prioridade (catalogar)
- **_shared.isAuthorized fail-OPEN** em rotation/_shared.ts
  - Se ROTATION_API_KEY sumir, endpoints viram públicos silenciosamente
  - Deveria ser fail-CLOSED (`if (!apiKey) return false`)
- **SELECT * → SELECT explícito** em webhook/route.ts (refactor performance)

## Lições aprendidas

1. **Auditoria automatizada com regex amplo gera falsos positivos** — 14 flagados, só 2 bugs reais. Sempre validar manualmente.

2. **Tabelas com nomes parecidos** — `workspace_memberships` (correto) vs `workspace_members` (não existe). Sempre confirmar schema antes de SQL inline.

3. **Defesa em profundidade** — UPDATE também precisa de filtro mesmo quando SELECT já filtra. Atacante pode pular o SELECT.

4. **Padrão dominante > inovação** — 8 dos 11 sibling endpoints usavam `getWorkspaceIdSafe()`. Seguir o padrão evita bugs e facilita revisão.

5. **Bonus discovery** — Investigando webhook/route.ts, descobrimos que `workspace_settings` também vazava (não estava no relatório original).
