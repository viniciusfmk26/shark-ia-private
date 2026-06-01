---
title: Plano de Ação — Auditoria 2026-05-21
date: 2026-05-21
---

# 06 — Plano de Ação

> Priorização: 🔴 P0 (hoje) · 🟠 P1 (semana) · 🟡 P2 (sprint) · 🟢 P3 (backlog).
> Esforço estimado em homem-hora corrida (uma pessoa focada).

## 🔴 P0 — fazer hoje

| # | Ação | Origem | Esforço |
|---|------|--------|---------|
| 1 | Aplicar firewall (UFW) nas portas 5433, 6379, 9000, 33060, 3000 — derrubar exposição pública | [[03-segurança]] | 0,5 h |
| 2 | Rotacionar senha Postgres + chaves MinIO + senha MySQL após (1) | [[03-segurança]] | 1 h |
| 3 | Corrigir [[05-bugs-encontrados#BUG-01]] — adicionar `ON CONFLICT` no insert de `whatsapp_instances` | [[04-logs-erros]] | 0,5 h |
| 4 | Implementar retenção em `audit_logs` (cron `DELETE WHERE created_at < now() - 60 days` ou particionamento) | [[05-bugs-encontrados#BUG-02]] | 2 h |

**Total P0:** ~4 h. Sozinho move o score de 58 → ~80.

## 🟠 P1 — esta semana

| # | Ação | Origem | Esforço |
|---|------|--------|---------|
| 5 | Investigar 4 restarts do `wp_zapflix-web` (dmesg, logs full, deploy hooks) | [[05-bugs-encontrados#BUG-04]] | 2 h |
| 6 | `VACUUM ANALYZE messages` + ajustar `autovacuum_vacuum_scale_factor=0.05` | [[05-bugs-encontrados#BUG-03]] | 1 h |
| 7 | Rebaixar nível de log de Avatar 404 e Media 400 (`error` → `warn`) | [[05-bugs-encontrados#BUG-05]] | 0,5 h |
| 8 | Mover secrets literais de `/api/migrate/*` para `process.env.MIGRATION_SECRET` | [[03-segurança]] | 1 h |
| 9 | Verificar uso de `CRON_SECRET` no repo inteiro (não só `lib/`) | [[03-segurança]] | 0,5 h |

**Total P1:** ~5 h.

## 🟡 P2 — próximo sprint

| # | Ação | Origem | Esforço |
|---|------|--------|---------|
| 10 | Corrigir 4 conversas com `contact_id = NULL` (popular via lookup) + endurecer o webhook | [[05-bugs-encontrados#BUG-06]] | 2 h |
| 11 | Arquivar `jobs` succeeded > 30 dias para uma `jobs_archive` ou drop | [[02-banco]] | 2 h |
| 12 | Auditar 72 rotas `/api/migrate/*` — marcar candidatas a remoção | [[03-segurança]] | 3 h |
| 13 | Decidir destino de `wp_zapflix-monitor` e `wp_zapflix-postgrest` (escalar ou remover) | [[01-infraestrutura]] | 1 h |
| 14 | Avaliar retenção de `webhook_token_audit` (18 MB) e `processed_events` (67 MB) | [[02-banco]] | 1 h |

**Total P2:** ~9 h.

## 🟢 P3 — backlog

| # | Ação | Origem | Esforço |
|---|------|--------|---------|
| 15 | Triar 7 dead jobs (re-enqueue / archive / delete) | [[05-bugs-encontrados#BUG-08]] | 0,5 h |
| 16 | Contatar workspaces com instâncias `disconnected` (Fábrica, Eduardo, Denise) | [[05-bugs-encontrados#BUG-09]] | 2 h |
| 17 | Avaliar swap em uso (1,2 Gi) — instalar swap monitor ou aumentar RAM | [[01-infraestrutura]] | 1 h |
| 18 | Implementar agregador de logs (Loki/Grafana ou script de histograma) | [[04-logs-erros]] | 4 h |

**Total P3:** ~7,5 h.

---

## Resumo de esforço

| Bucket | Itens | Horas |
|--------|------:|------:|
| 🔴 P0 | 4 | 4 |
| 🟠 P1 | 5 | 5 |
| 🟡 P2 | 5 | 9 |
| 🟢 P3 | 4 | 7,5 |
| **Total** | **18** | **25,5 h** |

## Checkboxes de execução

### 🔴 P0
- [ ] Firewall UFW (5433, 6379, 9000, 33060, 3000)
- [ ] Rotacionar credenciais (Postgres, MinIO, MySQL)
- [ ] `ON CONFLICT` em `whatsapp_instances`
- [ ] Retenção `audit_logs` (60 dias)

### 🟠 P1
- [ ] Investigar restarts do web
- [ ] `VACUUM ANALYZE messages` + tuning autovacuum
- [ ] Rebaixar logs Evolution API
- [ ] Migrar secrets literais para env
- [ ] Auditar uso `CRON_SECRET`

### 🟡 P2
- [ ] Popular `contact_id` nas 4 conversas órfãs
- [ ] Arquivar jobs antigos
- [ ] Triagem das 72 rotas migrate
- [ ] Decidir `monitor` e `postgrest`
- [ ] Retenção de `webhook_token_audit` e `processed_events`

### 🟢 P3
- [ ] Triar 7 dead jobs
- [ ] Contato com workspaces de instâncias desligadas
- [ ] Avaliar swap usage
- [ ] Agregador de logs

---

## Critérios de pronto

A próxima auditoria (sugerida para **2026-06-04**, 2 semanas depois) deve mostrar:

- Score ≥ 80
- Tabela `audit_logs` ≤ 500 MB
- 0 restarts não programados do web em 7 dias
- Portas 5433, 6379, 9000, 33060 não responderem do exterior
- 0 erros de `duplicate key` em `whatsapp_instances` nas últimas 24 h
- `messages` com dead_tup < live_tup
