---
title: Banco de Dados — Auditoria 2026-05-21
date: 2026-05-21
---

# 02 — Banco de Dados

> Postgres 17 em `localhost:5433` (Docker), database `zapflix`.

## Tamanho geral

| Métrica | Valor |
|---------|-------|
| Tamanho total | **2 754 MB** |
| Long queries (> 30 s) | 0 ✅ |
| Tabela `audit_logs` | 874 MB (32 % do banco) ⚠️ |

## Top 20 tabelas por tamanho (heap)

| # | Tabela | Tamanho |
|---|--------|---------|
| 1 | `audit_logs` | **874 MB** |
| 2 | `messages` | 259 MB |
| 3 | `jobs` | 170 MB |
| 4 | `processed_events` | 67 MB |
| 5 | `worker_runs` | 43 MB |
| 6 | `webhook_token_audit` | 18 MB |
| 7 | `instance_health_log` | 13 MB |
| 8 | `conversations` | 7,9 MB |
| 9 | `contacts` | 6,1 MB |
| 10 | `conversation_knowledge` | 6,0 MB |
| 11 | `short_links` | 5,8 MB |
| 12 | `conversation_analysis` | 4,2 MB |
| 13 | `group_messages` | 3,2 MB |
| 14 | `funnel_execution_log` | 2,9 MB |
| 15 | `customer_journey` | 2,9 MB |
| 16 | `iptv_generated_tests` | 2,4 MB |
| 17 | `scheduled_messages` | 2,2 MB |
| 18 | `sales_events` | 1,8 MB |
| 19 | `ai_suggestions_log` | 1,7 MB |
| 20 | `contact_tag_assignments` | 1,6 MB |

## Contagens das tabelas-chave

| Tabela | Linhas |
|--------|-------:|
| `audit_logs` | **2 855 920** |
| `messages` | 283 630 |
| `contacts` | 18 549 |
| `conversations` | 14 889 |
| `whatsapp_instances` | 29 |
| `workspaces` | 12 |
| `iptv_trials` | 802 |

## Crescimento de `audit_logs` (últimos 8 dias)

| Dia | Linhas novas |
|-----|-------------:|
| 2026-05-20 (hoje) | 115 959 |
| 2026-05-19 | 29 181 |
| 2026-05-18 | 127 448 |
| 2026-05-17 | 113 418 |
| 2026-05-16 | 74 970 |
| 2026-05-15 | 33 155 |
| 2026-05-14 | 50 673 |
| 2026-05-13 | 21 499 |

**Média ~70 k linhas/dia.** Em 90 dias acumula ~6,3 M linhas adicionais, projeção de +2 GB. Sem política de retenção, esta tabela vira a maior dor operacional. Ver bug [[05-bugs-encontrados#BUG-02]].

## Dead tuples

| Tabela | Dead | Live | last_vacuum | last_autovacuum |
|--------|-----:|-----:|-------------|-----------------|
| `messages` | 11 042 | 5 090 | — | — |

⚠️ `messages` com mais dead tuples que live (rácio 2,17×) e nunca vacuumado manualmente nem autovacuumado. Bloat alto. Considerar `VACUUM (ANALYZE, VERBOSE) messages;` fora de pico.

## Itens de ação

- [ ] 🔴 Implementar retenção em `audit_logs` (TTL ~30 dias ou particionamento por mês + drop de partições antigas)
- [ ] 🟠 Rodar `VACUUM ANALYZE` em `messages`; investigar por que autovacuum não está rodando (thresholds?)
- [ ] 🟡 Avaliar arquivamento de `jobs` succeeded > 30 dias (170 MB, 18 156 linhas succeeded)
- [ ] 🟢 Avaliar se `webhook_token_audit` (18 MB) precisa de retenção similar a audit_logs
