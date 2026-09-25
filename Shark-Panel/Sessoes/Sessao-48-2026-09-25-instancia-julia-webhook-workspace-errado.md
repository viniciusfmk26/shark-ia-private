# Sessão 48 — 25/09/2026 — Instância Julia Abreu: webhook caindo no workspace errado após mudança de workspace (Shark Panel → Shark 2)

## Sintoma reportado

Dono foi "passar a Júlia" no workspace de instâncias. Abriu para **Shark 2**, ela "estava na Shark normal", e **simplesmente não funciona**. A instância aparece `connected` mas não recebe nada.

## Diagnóstico (comprovado em produção)

**A Júlia é Cloud API da Meta** (`provider = 'cloud_api'`), não Evolution API:
- phone `+55 47 9277-5137`
- WABA `27727293163627289`
- `cloud_phone_number_id = 1155677294305122`

**O que o painel fez ao "mover" entre workspaces:** não moveu — **duplicou**.
Manteve a linha antiga com `deleted_at` preenchido e criou uma linha nova no workspace destino:

| id | nome | workspace | status |
|---|---|---|---|
| `6f65b5bf-…` | Julia Abreu 47 | Shark Panel (`00000000-…-0002`) | `deleted` / pausada |
| `7b93dff5-…` | Julia Abreu De Melo 5137 | **Shark 2** (`4a815ba6-…`) | `connected` |

Mesmo `cloud_phone_number_id`, mesmo token, duas linhas.

### Causa raiz — `app/api/webhook/cloud/route.ts` → `resolveInstanceByPhoneNumberId()`

```sql
SELECT workspace_id, name, evolution_instance_id, cloud_access_token
  FROM whatsapp_instances
 WHERE provider = 'cloud_api' AND cloud_phone_number_id = $1
 LIMIT 1          -- ← sem deleted_at IS NULL, sem status, sem ORDER BY
```

Rodando a query **exata** do código contra produção, ela retornava a linha **deletada do workspace errado** (`00000000-…-0002`, "Julia Abreu 47"). O `LIMIT 1` sem `ORDER BY` pegava a linha deletada porque ela tem TID menor no índice `idx_whatsapp_instances_cloud_phone_number_id`.

**Prova — `processed_events`:** os **212** eventos do número da Júlia estavam gravados no **Shark Panel**; **zero** no Shark 2 (último em 19/09 20:16).

**Por que o índice deixou passar:** o UNIQUE real é
`idx_whatsapp_instances_evo_unique (evolution_instance_id) WHERE deleted_at IS NULL`
— cobre **só** `evolution_instance_id` e é **parcial**. Nada impedia o mesmo `cloud_phone_number_id` existir em dois workspaces. (O comentário em `app/api/instances/route.ts:358` dizendo `UNIQUE(workspace_id, evolution_instance_id)` está **errado**.)

**Por que "conecta" mas não recebe:** envio de mensagem funciona — `lib/whatsapp/send.ts:58` busca por `id` com `deleted_at IS NULL` e pega a linha certa. Só a **entrada** (webhook) estava quebrada.

## Impacto apurado

| Tabela | Registros | Ação |
|---|---|---|
| `conversations` | 189 | migrados |
| `auto_campaigns` | 6 (todas `enabled = false`) | migrados |
| `whatsapp_template_instances` | 9 (approved, Meta template ids) | migrados |
| `chatbot_flows.instance_ids` | 1 (array uuid[]) | migrado |
| `compliance_events` | 1 (auditoria de 27/07) | **mantido** — log histórico, não reescrever |
| `instance_migrations` | — | 1 registro criado (sistema já tinha a tabela, não foi usada) |

189 + 9 = **198 conversas** consolidadas na instância do Shark 2.
Sobreposição de contatos entre as duas linhas: **zero** (migração sem duplicata).

**Cuidado registrado:** `conversations.instance_id` tem `ON DELETE CASCADE`. Apagar a linha antiga sem migrar as conversas destruiria as 189.

## Execução

### Fix A — banco (transação única, `ON_ERROR_STOP=1`)

Backups antes: `/tmp/opencode/julia-fix/snapshot.sql` (29M — `whatsapp_instances`, `conversations`, `processed_events`) e `refs-snapshot.sql` (75M — as 38 tabelas com coluna `*instance_id*`).

Ordem: conversas → auto_campaigns → templates → chatbot_flows → `instance_migrations` → `DELETE` da linha duplicada. `conversations.migrated_from_instance_id` preenchido com o id antigo (rastreabilidade).

### Fix B — código (commit `176f889a`)

| Arquivo | Correção |
|---|---|
| `app/api/webhook/cloud/route.ts` | `resolveInstanceByPhoneNumberId`: `+ deleted_at IS NULL`, `+ ORDER BY updated_at DESC, created_at DESC` |
| `app/api/webhook/cloud/route.ts` | verify do webhook: `+ deleted_at IS NULL` |
| `app/api/webhook/route.ts` | 2 queries de `groups.upsert` (Evolution): `+ deleted_at IS NULL` |
| `app/api/cron/sync-instance-profiles/route.ts` | `+ deleted_at IS NULL` (era o único sem filtro) |
| `app/api/payments/amplopay-webhook/route.ts` | 3 queries: `+ deleted_at IS NULL` — **caminho de PIX/pagamentos** |
| `migrations/20260925_cloud_phone_number_unique.sql` | novo índice `uq_whatsapp_instances_cloud_phone_active (cloud_phone_number_id) WHERE deleted_at IS NULL` |

Já estavam corretos (auditados, sem mudança): `app/api/rotation/next`, `rotation/stats`, `instances/sync-cloud-profiles`, `meta-apps/[id]/phone-numbers`, `lib/whatsapp/send.ts`, `lib/whatsapp/dispatch-guard.ts`.

## Validação

- `npx tsc --noEmit -p .` → exit 0
- Índice aplicado após confirmar **zero** duplicados ativos (19 instâncias sem `cloud_phone_number_id`, 0 vazios, 28 ativas)
- Deploy: `build_time 2026-09-25T21:26:14Z`
- **Teste real:** POST sintético em `/api/webhook/cloud` com `phone_number_id = 1155677294305122` → HTTP 200, `processed_events` gravado em `4a815ba6` (**Shark 2** ✅), conversa criada em "Julia Abreu De Melo 5137" / Shark 2
- Registros de teste removidos (conversa, `processed_events`, 2 jobs). Júlia com **198** conversas

## Lição / regra permanente

> **Toda query que resolve instância por identificador externo (`cloud_phone_number_id`, `evolution_instance_id`, `name`, `phone_number`) precisa de `deleted_at IS NULL` + `ORDER BY` determinístico.**
> Sem isso, um soft-delete deixa a linha invisível pro painel mas **visível pro webhook** — e o `LIMIT 1` escolhe a linha errada silenciosamente.
> Diagnóstico rápido: rodar a query de resolução **na mão** contra produção. Se ela tem `LIMIT 1` sem `ORDER BY`, é bug.

## Pendências

1. **Não existe fluxo de "mover instância entre workspaces" no painel.** Ele duplica. A tabela `instance_migrations` existe e o `app/api/instances/route.ts` já a consulta (`active_migration_to`), mas nada popula em movimento de workspace — só em ban. **Próximo candidato a feature.**
2. `app/api/instances/route.ts:358` — comentário errado sobre o índice unique; corrigir junto da feature acima.
3. `compliance_events` da Júlia ficou com `instance_id` do id removido (auditoria de 27/07) — sem impacto funcional (sem FK), deixado como registro histórico.
4. Confirmar com o dono se as 6 `auto_campaigns` migradas devem ser reativadas (estavam todas `enabled = false`).
