# 🦈 Deep Dive — Drip Campaigns

**Escopo:** sequências automáticas de mensagens (típico email-marketing aplicado a WhatsApp), com triggers de evento e regras de stop. Tabelas: `drip_campaigns`, `drip_campaign_steps`, `drip_campaign_enrollments`.

**TL;DR:**
- **Sistema funcional, mas adoption ZERO em prod**: 0 campanhas, 0 steps, 0 enrollments. Implementação completa, ninguém usa.
- 2 crons agendados em supercronic: `drip-event-triggers` (a cada 5 min) e `drip-campaigns` (a cada 15 min). Estão rodando e processando 0 rows.
- 5 trigger events suportados (plan_expiry_7d/3d/1d, plan_expired, new_contact). 3 reservados para outros mecanismos (manual, purchase, post_service).

---

## 1. Schema

### 1.1 `drip_campaigns`
```
id              | uuid PK
workspace_id    | uuid → workspaces(id) CASCADE
name            | varchar(100)
description     | text
trigger_event   | varchar(50) default 'manual'   -- manual|plan_expiry_*|new_contact|purchase|post_service
status          | varchar(20) default 'draft'    -- CHECK: draft|active|paused|archived
stop_on_reply   | boolean default true            -- cancela enrollment se cliente respondeu
stop_on_purchase| boolean default false           -- cancela se houve payment confirmed
instance_id     | uuid                            -- WhatsApp instance específica (opcional)
created_by      | text → nextauth_users(id)
```

### 1.2 `drip_campaign_steps`
```
id                 | uuid PK
campaign_id        | uuid → drip_campaigns(id) CASCADE
step_order         | integer NOT NULL
delay_hours        | integer NOT NULL default 24
message_text       | text NOT NULL
message_media_url  | text
message_media_type | varchar(20)                  -- image|audio|video|document
condition          | jsonb                        -- não usado em prod
```

### 1.3 `drip_campaign_enrollments`
```
id              | uuid PK
campaign_id     | uuid → drip_campaigns(id) CASCADE
contact_id      | uuid → contacts(id) CASCADE
contact_phone   | text
current_step    | integer default 0
next_action_at  | timestamptz                  -- quando a próxima step deve ser processada
status          | varchar(20)                  -- CHECK: active|completed|cancelled|paused
enrolled_at     | timestamptz
completed_at    | timestamptz
UNIQUE (campaign_id, contact_id)
```

---

## 2. Estado em prod

```
drip_campaigns:               0 rows
drip_campaign_steps:          0 rows
drip_campaign_enrollments:    0 rows
```

**Feature 100% inutilizada.** Os crons rodam de minuto em minuto e processam 0 enrollments.

---

## 3. Crons agendados (Dockerfile.cron)

| Cron | Schedule | Endpoint |
|------|----------|----------|
| `drip-event-triggers` | `*/5 * * * *` (5 min) | `/api/cron/drip-event-triggers` |
| `drip-campaigns`      | `*/15 * * * *` (15 min) | `/api/cron/drip-campaigns` |

⚠️ Nota: `CLAUDE.md` afirma que esses crons "não estão agendados". **Está desatualizado** — checando `Dockerfile.cron` (que é a fonte de verdade do supercronic), AMBOS estão sim agendados.

### 3.1 `/api/cron/drip-event-triggers/route.ts` (95 linhas)

**Função:** auto-enrolla contatos em campanhas baseado em eventos.

**Trigger events suportados (EVENT_QUERIES, route.ts:11-17):**
| Event | Query |
|-------|-------|
| `plan_expiry_7d` | `contacts.plan_expires_at BETWEEN NOW() AND NOW() + 7 days` |
| `plan_expiry_3d` | `contacts.plan_expires_at BETWEEN NOW() AND NOW() + 3 days` |
| `plan_expiry_1d` | `contacts.plan_expires_at BETWEEN NOW() AND NOW() + 1 day` |
| `plan_expired`   | `contacts.plan_expires_at < NOW() AND > NOW() - 1 day` |
| `new_contact`    | `contacts.created_at > NOW() - 24 hours` |

**Skip events (delegados a outros sistemas):**
- `manual` — usuário enrolla via UI/API
- `purchase` — webhook de pagamento (não implementado nessa rota)
- `post_service` — fim de ticket/atendimento (não implementado nessa rota)

**Lógica:**
```
Para cada drip_campaign WHERE status='active' AND trigger_event != 'manual':
  Se SKIP_EVENTS contém trigger_event: continue
  Se EVENT_QUERIES não tem o trigger: warn + continue (event desconhecido)
  Roda eventQuery (workspace_id=$1) → lista de contatos elegíveis
  delayHours = primeira step.delay_hours (ou 0)
  Para cada contact:
    INSERT drip_campaign_enrollments (..., current_step=0, next_action_at=NOW()+delayHours, status='active')
    ON CONFLICT (campaign_id, contact_id) DO NOTHING
```

**Bug potencial:** `contacts.plan_expires_at` é coluna pouco populada. Se `plan_expires_at` é NULL, contato nunca é elegível para `plan_expiry_*` events.

### 3.2 `/api/cron/drip-campaigns/route.ts` (169 linhas)

**Função:** processa enrollments com `next_action_at <= NOW()`, envia mensagem da step atual e avança para próxima.

**Lógica:**
```
SELECT FROM drip_campaign_enrollments
WHERE status='active' AND next_action_at <= NOW()
LIMIT 100 ORDER BY next_action_at ASC

Para cada enrollment:
  SELECT campaign
  Se campaign.status != 'active' → enrollment.status='paused', continue (cancelled++)
  
  Se campaign.stop_on_reply:
    SELECT messages WHERE conversation.contact_id=enrollment.contact AND direction='in' AND created_at > enrolled_at
    Se há reply → status='cancelled', completed_at=NOW(), continue
  
  Se campaign.stop_on_purchase:
    SELECT payments WHERE contact_id=... AND status='confirmed' AND created_at > enrolled_at
    Se há compra → status='cancelled', continue
  
  SELECT step WHERE step_order = enrollment.current_step
  Se step não existe: status='completed', completed_at=NOW(), continue (completed++)
  
  SELECT conversation WHERE contact_id=... ORDER BY last_message_at DESC NULLS LAST LIMIT 1
  Se conv existe:
    INSERT jobs (type='send_message', payload={conversation_id, instance_id, text, media_url, drip_campaign_id, drip_enrollment_id, drip_step_order})
  
  next_step = current_step + 1
  Se next_step existe:
    UPDATE current_step=next, next_action_at=NOW()+delayHours
  Senão:
    UPDATE status='completed'
```

⚠️ **BUG:** o INSERT em `jobs` usa coluna `payload_json` (linha 118), mas o schema padrão de `jobs` usa `payload` (jsonb). Ver: outros caminhos do worker fazem `INSERT INTO jobs (workspace_id, type, payload, ...)`. Esta rota está com nome errado de coluna ou existe variant `payload_json` na tabela. **Verificar urgente** — pode ser razão de feature não funcionar mesmo se ativada.

---

## 4. API REST

| Rota | Arquivo | Função |
|------|---------|--------|
| `GET /api/campaigns/drip` | route.ts:9-29 | List + stats |
| `POST /api/campaigns/drip` | route.ts:32-94 | Create (com transação para steps) |
| `GET/PUT/DELETE /api/campaigns/drip/[id]` | [id]/route.ts (161 lin.) | CRUD |
| `POST /api/campaigns/drip/[id]/enroll` | [id]/enroll/route.ts (104 lin.) | Enroll manual |

POST cria campaign + steps em transação:
```
INSERT drip_campaigns (...)
Para cada step em body.steps[]:
  INSERT drip_campaign_steps (campaign_id, step_order, delay_hours, message_text, message_media_url, message_media_type)
```

GET retorna stats por campaign: `active_enrollments`, `total_enrollments`, `step_count`.

---

## 5. UI

`app/(dashboard)/campaigns/page.tsx` (1286 linhas, **arquivo único e grande**):
- Trata múltiplos tipos de campanha incluindo drip (e bulk send, broadcast).
- Exibe lista com stats por campanha.
- Modal de criação com editor de steps inline.

**Não há editor visual tipo xyflow** — drip é linear (step 0 → step 1 → ...).

---

## 6. Fluxo E2E

### Caso 1: Campanha "manual" (enroll manual via UI)

```
Admin abre /campaigns
  → cria drip campaign (POST /api/campaigns/drip)
  → trigger_event='manual', status='draft'
Admin ativa: PUT campaign status='active'
Admin enrolla contatos: POST /api/campaigns/drip/[id]/enroll {contact_ids:[]}
  → INSERT drip_campaign_enrollments com next_action_at=NOW()+delayHours

Cron drip-campaigns (a cada 15 min):
  → vê enrollments due
  → SELECT step → INSERT job send_message
  → UPDATE next_action_at = NOW() + nextStep.delay_hours

Worker pega job send_message (a cada ~2s)
  → envia via Evolution API
  → mensagem aparece na conversa do contato

Quando cliente responde:
  → process_webhook job processa inbound
  → Cron drip-campaigns na próxima rodada vê messages.direction='in' após enrolled_at
  → cancela enrollment (stop_on_reply=true por default)
```

### Caso 2: Campanha event-driven (`plan_expiry_3d`)

```
Cron drip-event-triggers (a cada 5 min):
  → SELECT campaigns active com trigger_event='plan_expiry_3d'
  → eventQuery: SELECT contacts WHERE plan_expires_at BETWEEN NOW() AND NOW()+3d
  → INSERT drip_campaign_enrollments ON CONFLICT DO NOTHING

Cron drip-campaigns (15 min depois ou menos):
  → processa enrollments due
  → resto idêntico ao caso 1
```

---

## 7. Diferença Drip vs Automation vs Funil

| Feature | Trigger | Cadência | Estado | Engine | Use case ideal |
|---------|---------|----------|--------|--------|----------------|
| **automation_triggers** (keyword) | inbound message + keyword match | imediata | Stateless (anti-spam por jobs) | Worker | Auto-resposta "preço" → cardápio |
| **automations** (intercept) | inbound + status='active' + intercept_trigger_type | imediata, com session | `automation_flow_sessions` | Worker | "Estou no almoço" auto-reply |
| **guided_funnels** (URA) | keyword | imediata, multi-turn | `guided_funnel_sessions.current_step_key` | Worker | Menu interativo "1=android 2=ios" |
| **funnels (sales legacy)** | enrollment manual ou trigger_event | batch, delay_minutes entre stages | `funnel_contacts.current_stage_id` | Cron 1min | Follow-up de trial IPTV |
| **drip_campaigns** | event (plan_expiry, new_contact, manual) | batch, delay_hours entre steps | `drip_campaign_enrollments.current_step` | Cron 15min + 5min | Campanha "7d antes do vencimento, mande lembrete" |
| **scheduled_messages** | data/hora absoluta | uma vez | `scheduled_messages.status` | Cron 1min | "Mande PIX dia 5 às 14h" |
| **followup** (multiple crons) | trial expiry, pix pendente, abandoned cart | batch | tabelas dedicadas | Crons hourly/dialy | Recuperação de abandono |

**Quando usar drip:** sequência de N mensagens, espaçadas por horas/dias, com gatilho automático por evento. Ex: "Cliente expirou trial — manda 3 mensagens em 1d, 3d, 7d".

**Por que ninguém usa em prod:** o caso de uso de drip foi absorvido pelo sistema de **funnels (sales legacy)** + **trial-followup cron** — que já implementam tudo isso de forma específica para IPTV, e estão bem rodados (1298 enrollments).

---

## 8. Bugs / débitos

### 8.1 🔴 BUG CRÍTICO CONFIRMADO: coluna `payload_json` não existe
`/api/cron/drip-campaigns/route.ts:118`:
```ts
INSERT INTO jobs (type, payload_json, status, run_at) VALUES ('send_message', $1, 'queued', NOW())
```
**Confirmado via `information_schema.columns`:** a tabela `jobs` só tem coluna `payload`, não `payload_json`. **Toda essa linha falha em runtime** — qualquer drip ativado **não envia mensagens**. Erro pego pelo try/catch (linha 158) e contado em `errors`, mas sem alerta visível.

Fix:
```ts
INSERT INTO jobs (workspace_id, type, payload, status, run_at, max_attempts)
VALUES ($1, 'send_message', $2, 'queued', NOW(), 3)
```
(também falta `workspace_id`, que outros INSERTs em jobs incluem — o handler send_message no worker pode falhar sem isso).

### 8.2 BUG: campo `condition` em `drip_campaign_steps` (jsonb) não é processado
Definido no schema mas o cron `drip-campaigns` não lê/avalia condition. Feature dead-code.

### 8.3 BUG: SKIP_EVENTS `purchase` e `post_service` não têm implementação alternativa
Comentário diz "handled by other mechanisms (webhooks, ticket resolution)" mas grep do código não encontra ninguém que enrolla em drips com esses triggers. **Drip via purchase e post_service não funciona.**

### 8.4 BUG: `contacts.plan_expires_at` raramente populado
Drips por `plan_expiry_*` precisam dessa coluna. Em prod muitos contatos não têm a coluna preenchida (vem de subscriptions/iptv_trials, mas sync não está garantido).

### 8.5 INCONSISTÊNCIA: stop_on_purchase ↔ tabela `payments`
Cron faz `SELECT FROM payments WHERE contact_id=...`. Mas `payments` em prod tem schema separado de checkout (`payment_intents`, `pix_charges`, etc.). Pode estar consultando tabela errada/vazia.

### 8.6 INCONSISTÊNCIA: instance_id resolution
`/api/cron/drip-campaigns/route.ts:123`: usa `campaign.instance_id || conv.instance_id`. Se ambos forem NULL, job send_message é enfileirado sem instance — provavelmente falha no worker.

### 8.7 BUG: `current_step=0` mas step_order=0 raro
Convenção comum é step_order começar em 1, mas enrollments criam com `current_step=0`. Se as steps são salvas com step_order ≥ 1, primeiro tick processa NULL step (aborta para completed sem enviar nada).

```sql
-- testar:
SELECT MIN(step_order), MAX(step_order) FROM drip_campaign_steps;
```

(Não dá pra testar agora, 0 rows.)

### 8.8 BUG: stop_on_reply só checa após enrolled_at
Não considera replies durante a janela entre fila e envio. Pode enviar step 2 mesmo se cliente respondeu enquanto step 2 estava na fila do worker.

---

## 9. Custos estimados

### Storage
- 0 rows hoje. Se ativado, com 1000 enrollments × 200B + logs ≈ **<1 MB**.

### CPU
- Cron drip-event-triggers: 5× SELECT por hora × N campaigns. Hoje N=0, custo zero.
- Cron drip-campaigns: 4× LIMIT 100 por hora. Hoje 0, custo zero.

### Tokens IA
- Drip não usa IA.

**Custo atual: ZERO.**
**Custo se usado em escala (10k enrollments ativos): <$2/mês.**

---

## 10. Resumo executivo

1. **Sistema completo, adoption zero.** Pronto pra ser usado, mas o caso de uso "follow-up de trial" foi feito antes na arquitetura `funnels` legacy.
2. **Crons rodam de graça** (5 e 15 min) processando 0 rows. Custo desprezível.
3. **Bug crítico potencial em `/api/cron/drip-campaigns/route.ts:118`** — nome de coluna `payload_json` pode estar errado. Sem teste em prod, ninguém percebe.
4. **Decisão arquitetural:** consolidar drip + funnels legacy + trial-followup em uma única feature unificada, ou deprecate drip se o caso de uso já está coberto.
5. **Não há editor visual** — UI é list+modal. Para campanhas complexas, faltaria um editor de steps melhor.
