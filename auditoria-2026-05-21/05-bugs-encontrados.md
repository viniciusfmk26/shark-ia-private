---
title: Bugs Encontrados — Auditoria 2026-05-21
date: 2026-05-21
---

# 05 — Bugs encontrados nesta auditoria

> Severidade: 🔴 P0 (corrigir hoje) · 🟠 P1 (esta semana) · 🟡 P2 (próximo sprint) · 🟢 P3 (backlog)

---

## 🔴 BUG-01 — Duplicate key em `whatsapp_instances` ao buscar pela Evolution API

**Severidade:** 🔴 P0
**Evidência:** [[04-logs-erros]]

```
[API] Error fetching from Evolution API: error: duplicate key value violates unique constraint "idx_whatsapp_instances_ws_phone"
```

**Diagnóstico provável:** alguma rota de sync/fetch insere instância sem `ON CONFLICT`. Como o índice é `(workspace_id, phone)`, qualquer re-sync de uma instância já existente quebra.

**Correção sugerida:**
```sql
INSERT INTO whatsapp_instances (...)
VALUES (...)
ON CONFLICT (workspace_id, phone) DO UPDATE
  SET status = EXCLUDED.status, updated_at = now();
```

**Como localizar:** `grep -rn "INTO whatsapp_instances" /root/Zapflix-Tech/app /root/Zapflix-Tech/lib` e checar quais não têm `ON CONFLICT`.

---

## 🔴 BUG-02 — `audit_logs` sem retenção (timebomb de disco)

**Severidade:** 🔴 P0
**Evidência:** [[02-banco]]

- 874 MB / 2,86 M linhas
- Crescimento ~70 k linhas/dia
- 32 % do banco inteiro
- Projeção: +2 GB em 90 dias, +8 GB em 1 ano

**Correção sugerida:**
1. Particionar por mês (`PARTITION BY RANGE (created_at)`) e dropar partições > 90 dias via cron.
2. Ou TTL job semanal: `DELETE FROM audit_logs WHERE created_at < now() - interval '60 days'`.

---

## 🟠 BUG-03 — `messages` com bloat alto, sem vacuum

**Severidade:** 🟠 P1
**Evidência:** [[02-banco]]

```
tablename | n_dead_tup | n_live_tup | last_vacuum | last_autovacuum
messages  |     11 042 |      5 090 |     (null)  |     (null)
```

Rácio dead/live = 2,17×. Nunca vacuumado. Bloat afeta seq scans e índices.

**Correção:**
- Imediato: `VACUUM (ANALYZE, VERBOSE) messages;` fora de pico.
- Sustentável: verificar `autovacuum_vacuum_scale_factor` na tabela; provavelmente o threshold padrão (20 % de live tuples) está sendo enganado por updates de larga escala. Definir override:
  ```sql
  ALTER TABLE messages SET (autovacuum_vacuum_scale_factor = 0.05);
  ```

---

## 🟠 BUG-04 — `wp_zapflix-web` reinicia silenciosamente (4× em 19h)

**Severidade:** 🟠 P1
**Evidência:** [[01-infraestrutura]]

5 tasks visíveis: 1 running + 4 shutdown nas últimas 19h. Sem `ERROR` populado no `docker service ps`.

**Investigação sugerida:**
- `dmesg | grep -iE "killed process|out of memory"` no host
- `docker service logs wp_zapflix-web --since 24h 2>&1 | head -200` em torno dos timestamps de shutdown
- Verificar se há deploy automático configurado (cada `git push main` redeploy?)

---

## 🟠 BUG-05 — Erros do Evolution API logados como `error` em vez de `warn`

**Severidade:** 🟠 P1
**Evidência:** [[04-logs-erros]]

Avatar 404 e media 400 são esperáveis (contatos sem avatar, mídias antigas expiradas). Mas saem como `[Avatar] Evolution API error:` — atrapalha qualquer alerta baseado em grep `error`.

**Correção:** rebaixar para `console.warn` ou prefixo `[Avatar] missing:` para 404 específicos.

---

## 🟡 BUG-06 — 4 conversas com `contact_id = NULL`

**Severidade:** 🟡 P2
**Evidência:** [[02-banco]] (query do bloco 5)

```
total_sem_contato        = 4
sem_contato_e_unread > 0 = 0
```

Não bloqueia UX (todas com unread=0), mas indica que houve momentos em que uma `conversation` foi criada antes do `contact`. Correção: garantir que o webhook crie/upsert o contato **antes** da conversa.

**Como localizar:**
```sql
SELECT id, contact_phone, workspace_id, created_at
FROM conversations WHERE contact_id IS NULL;
```

Depois, popular `contact_id` via lookup por `(workspace_id, phone_e164)`.

---

## 🟡 BUG-07 — Secrets hardcoded em rotas `/api/migrate/*`

**Severidade:** 🟡 P2
**Evidência:** [[03-segurança]]

`fix-phone-e164-format` (`'zapflix-diag-secret'`), `check-pix-settings` (`'zapflix-check-inst'`). Hoje só compromete se o RBAC quebrar, mas é dívida de defesa em profundidade.

---

## 🟢 BUG-08 — 7 jobs no estado `dead`

**Severidade:** 🟢 P3
**Evidência:** [[06-plano-de-acao]] (queue stats)

```
succeeded | 18156
cancelled |  1238
archived  |    14
dead      |     7
```

7 jobs mortos. Pode ser de campanhas antigas. Listar e decidir entre re-enqueue, archive ou delete.

```sql
SELECT id, type, error, created_at FROM jobs WHERE status='dead' ORDER BY created_at DESC;
```

---

## 🟢 BUG-09 — 15 de 29 instâncias WhatsApp `disconnected`

**Severidade:** 🟢 P3
**Evidência:** [[01-infraestrutura]] (mas problema é de produto, não infra)

Mais da metade do parque desligado. Workspace **Fábrica** sozinho tem 6 instâncias `disconnected`. Pode ser cliente em churn ou só falta de re-pairing.

Sugerir contato com clientes desses workspaces (Fábrica, Iphone, Eduardo, Denise).
