# 🦈 Deep Dive — Follow-up Engine + Scheduled Messages

**Escopo:** todo sistema de mensagens automáticas com timing, agrupando: `followup_campaigns`, `followup_logs`, `follow_up_log`, `followup_blacklist`, `scheduled_messages`, `contact_blacklist`, `global_blacklist`, `abandoned_cart_log`. Crons: `follow-up`, `trial-followup`, `pix-followup`, `abandoned-cart`, `scheduled-messages`, `close-inactive`, `plan-expiry`, `renewal-check`, `promote-expired-trials`.

**TL;DR:**
- **3 sistemas de follow-up paralelos:**
  1. `followup_campaigns` (multi-tipo: pix_pending, trial_expired, monthly_renewal) — **EM USO** em shark-panel + diario-das-bruxas. 6 campaigns (4 paused, 2 active).
  2. Cron `follow-up` (genérico) — usa tabela `follow_up_log` (0 rows hoje).
  3. Cron `trial-followup`/`pix-followup`/`abandoned-cart` específicos — geram `followup_logs` (1.544 rows até hoje).
- **scheduled_messages: 3.599 rows** (3.593 sent, 4 pending, 2 cancelled). Coração do agendamento manual e de funnels legacy.
- **3 níveis de blacklist:** `followup_blacklist` (0), `contact_blacklist` (0), `global_blacklist` (215). Última é a maior — bloqueio centralizado.
- **abandoned_cart_log: 0 rows** — feature configurada mas ninguém ativou.
- **Sistemas de PROTEÇÃO ANTI-SPAM** robustos no `scheduled-messages` cron (3 camadas).

---

## 1. Schema

### 1.1 `followup_campaigns` — campanhas configuráveis
```
id, workspace_id
name, type            -- pix_pending|trial_expired|monthly_renewal|...
status                -- active|paused|...
delay_minutes         -- atraso em minutos antes do 1º envio
max_attempts          -- número máximo de tentativas
randomize_messages    -- escolher mensagem aleatória dentre messages[]
instance_ids (jsonb)  -- whatsapp_instances permitidas
messages (jsonb)      -- array de templates de mensagens
schedule_enabled, schedule_hours[], schedule_days[]   -- janela permitida
total_sent, total_converted   -- contadores
```

### 1.2 `followup_logs` — log de envios (1544 rows)
```
id, workspace_id, campaign_id (FK), contact_id, contact_phone, contact_name
type            -- ex: trial_expired, pix_pending
message_index   -- qual mensagem da campaign[].messages foi usada
instance_id, status (sent|failed|...)
converted_at, sent_at
metadata (jsonb), reference_id, reseller_id, recovery_ref
```

### 1.3 `follow_up_log` — log de cron `follow-up` genérico (0 rows)
```
workspace_id, conversation_id (FK CASCADE)
attempt, message_text, sent_at
```

⚠️ Nome diferente (`follow_up_log` vs `followup_logs`) e schema mais simples — feature paralela mais antiga.

### 1.4 `scheduled_messages` — agendamento via UI (3599 rows)
```
id, conversation_id (FK CASCADE), workspace_id (FK CASCADE)
message (text NOT NULL), attachments (jsonb)
scheduled_for (timestamptz NOT NULL)
status            -- CHECK: pending|sent|cancelled|failed
created_at, sent_at, error_message, created_by (text → nextauth_users)
CHECK: scheduled_for > created_at
```

Indexes incluem partial: `idx_scheduled_messages_pending (scheduled_for, status) WHERE status='pending'`.

### 1.5 `followup_blacklist` — bloqueio por workspace para campanhas
```
workspace_id, phone (text NOT NULL), reason
UNIQUE (workspace_id, phone)
```
0 rows.

### 1.6 `contact_blacklist` — bloqueio padrão por workspace
```
workspace_id, phone_e164 (varchar(20))
reason, blocked_by, blocked_at
UNIQUE (workspace_id, phone_e164)
```
0 rows.

### 1.7 `global_blacklist` — bloqueio global (215 rows)
```
phone_e164 UNIQUE
reason, blocked_by_user_id, blocked_by_workspace_id (FKs)
```
**215 telefones bloqueados globalmente** — provavelmente concorrentes/spam reportado.

### 1.8 `abandoned_cart_log` — registro de cart followup (0 rows)
```
workspace_id, conversation_id, contact_id
attempt, sent_at
```

---

## 2. Estado em prod

```
follow_up_log:        0
followup_blacklist:   0
followup_campaigns:   6 (4 paused, 2 active)
followup_logs:      1544
scheduled_messages: 3599 (3593 sent, 4 pending, 2 cancelled)
contact_blacklist:    0
global_blacklist:   215
abandoned_cart_log:   0
```

Campanhas (6 total):
| Workspace | Nome | Type | Status | delay_min | max_att | sent | conv |
|-----------|------|------|--------|-----------|---------|------|------|
| diario-das-bruxas | PIX Pendente | pix_pending | paused | 60 | 2 | 0 | 0 |
| diario-das-bruxas | Trial Expirado | trial_expired | paused | 60 | 1 | 0 | 0 |
| diario-das-bruxas | Renovação Mensal | monthly_renewal | paused | 1440 | 1 | 0 | 0 |
| shark-panel | Renovação Mensal | monthly_renewal | paused | 1440 | 1 | 0 | 0 |
| **shark-panel** | **PIX Pendente** | **pix_pending** | **active** | 30 | 2 | 8 | 1 |
| **shark-panel** | **Trial Expirado** | **trial_expired** | **active** | 30 | 1 | 24 | **3** |

⚠️ **`total_sent` está zerado nas tabelas mas há 1544 logs** — contadores não são atualizados pelos crons. Cálculo em UI provavelmente vem de `followup_logs`.

Followup logs por type:
| type | count |
|------|-------|
| trial_expired | 1417 |
| pix_pending | 127 |

---

## 3. Crons (em supercronic)

| Cron | Schedule | Endpoint | Linhas |
|------|----------|----------|--------|
| `scheduled-messages` | `* * * * *` (cada minuto) | /api/cron/scheduled-messages | 180 |
| `follow-up` | `0 */4 * * *` (cada 4h) | /api/cron/follow-up | 169 |
| `trial-followup` | `0 10 * * *` (1x/dia 10h) | /api/cron/trial-followup | 312 |
| `pix-followup` | `*/30 * * * *` (cada 30min) | /api/cron/pix-followup | 290 |
| `abandoned-cart` | `0 */2 * * *` (cada 2h) | /api/cron/abandoned-cart | 129 |
| `close-inactive` | `0 3 * * *` (1x/dia 3h) | /api/cron/close-inactive | 76 |
| `plan-expiry` | `0 8 * * *` | /api/cron/plan-expiry | n/a |
| `renewal-check` | `0 7 * * *` | /api/cron/renewal-check | n/a |
| `promote-expired-trials` | `0 1 * * *` | /api/cron/promote-expired-trials | n/a |

### 3.1 `/api/cron/scheduled-messages` (180 linhas)

Triplo anti-spam:
- **Camada 1 (atômica):** UPDATE...RETURNING marca `pending → sent` antes de enfileirar. Concurrency-safe via `FOR UPDATE SKIP LOCKED`.
- **Camada 2 (max_attempts=1):** jobs de mensagem agendada não retentam — falha vai pra 'dead' imediatamente.
- **Camada 3 (idempotência):** worker verifica `client_message_id` antes de enviar.

```sql
UPDATE scheduled_messages
SET status='sent', sent_at=NOW()
WHERE id IN (
  SELECT id FROM scheduled_messages
  WHERE status='pending' AND scheduled_for <= NOW()
  ORDER BY scheduled_for ASC LIMIT 50
  FOR UPDATE SKIP LOCKED
) RETURNING ...;
```

Substitui `{{link_pagamento}}` no message body por URL parametrizada.

### 3.2 `/api/cron/trial-followup` (312 linhas)
**Não usa `followup_campaigns` por workspace** diretamente — usa `iptv_servers.trial_followup_enabled` + delay. As campaigns são overlay opcional para customizar mensagens.

```sql
SELECT iptv_trials t WHERE
  s.trial_followup_enabled = true
  AND t.followup_sent_at IS NULL
  AND t.status <> 'converted'
  AND t.expires_at < NOW() - INTERVAL X hours
  AND t.expires_at > NOW() - 7 days   -- não follow-up de trials muito antigos
LIMIT 200
```

Verifica:
- `iptv_servers.trial_followup_enabled`
- `contact.plan_expires_at` (não follow-up de quem já é cliente)
- Janela de horário/dia da campaign (timezone São Paulo)
- Janela de "business hours" do workspace (`workspace_settings.followup_schedule`)

INSERT `followup_logs` + UPDATE `iptv_trials.followup_sent_at = NOW()`.

### 3.3 `/api/cron/pix-followup` (290 linhas)
Para `payment_intents`/`pix_charges` pendentes:
- Templates suportam `{{nome}}`, `{{plano}}`, `{{valor}}`, `{{link}}`.
- Delays parametrizáveis: 30m, 1h, 2h, 6h, 24h.
- Campaign override em `followup_campaigns` (type=pix_pending).
- Caso sem campaign: usa `workspace_settings.pix_followup`.

### 3.4 `/api/cron/abandoned-cart` (129 linhas)
Lê `workspace_settings.value->'abandonedCart'`:
```ts
{ enabled, delay_hours, max_reminders, message_template }
```
Em prod: ninguém habilitou (`abandoned_cart_log: 0 rows`).

### 3.5 `/api/cron/follow-up` (169 linhas)
**Genérico** — usa `follow_up_log` (0 rows). Provavelmente é um precursor abandonado ou path alternativo.

### 3.6 `/api/cron/close-inactive` (76 linhas)
Fecha conversas sem atividade após X dias. Não envia mensagens.

---

## 4. Endpoints REST `/api/followup/*`

| Rota | Função |
|------|--------|
| `GET/POST /api/followup/campaigns` | CRUD campaigns |
| `PUT/DEL /api/followup/campaigns/[id]` | Edit/delete |
| `GET /api/followup/logs` | List `followup_logs` paginado |
| `GET /api/followup/dashboard` | KPIs (sent, conversion rate, etc) |
| `GET /api/followup/monitor` | Monitor em tempo real |
| `GET /api/followup/upcoming` | Próximos envios programados |
| `GET /api/followup/preview-data` | Preview da renderização de templates |
| `GET /api/followup/funnel` | Funil de conversão |
| `POST /api/followup/cancel` | Cancela follow-up de um trial/pix |
| `POST /api/followup/pause` | Pausa workspace inteiro |
| `GET/POST /api/followup/blacklist` | Lista/adiciona ao `followup_blacklist` |
| `DELETE /api/followup/blacklist/[phone]` | Remove |

UI: `/follow-up` em dashboard. Não há um page único grande — feature distribuída em /agendamentos, /campaigns, /follow-up.

---

## 5. Diferença entre features

| Feature | Trigger | Quando rodar | Tabela log | Adoption |
|---------|---------|--------------|------------|----------|
| **scheduled_messages** | Manual (UI: "agendar") | Cron 1min | scheduled_messages | **Pesado** (3599 rows) |
| **followup_campaigns(trial_expired)** | Auto (iptv_trials expirou) | Cron 1x/dia 10h | followup_logs | **Em uso** (1417 rows) |
| **followup_campaigns(pix_pending)** | Auto (PIX não pago) | Cron 30min | followup_logs | **Em uso** (127 rows) |
| **followup_campaigns(monthly_renewal)** | Auto (assinatura próximo de vencer) | (?) | followup_logs | **Pausado** |
| **abandoned_cart_log** | Auto (interesse sem pagamento) | Cron 2h | abandoned_cart_log | **Não usado** |
| **follow_up_log** | (?) genérico | Cron 4h | follow_up_log | **Não usado** |
| **drip_campaigns** | Event ou manual | Cron 15min | (jobs) | Não usado (ver Area 3) |
| **funnel_contacts** (sales legacy) | Enrollment | Cron 1min | funnel_execution_log | **Em uso** (1298) |
| **automations intercept** | Inbound message | Worker | automation_flow_sessions | Pausado |

---

## 6. Pause/cancel mecanismos

`/api/followup/pause` — UPDATE workspace_settings ou similar para pausar todos os crons de follow-up.

`/api/followup/cancel` — UPDATE `iptv_trials.followup_sent_at = NOW()` (impede re-disparo).

`/pause-contact`, `/cancel` (não confirmados) — podem ser via:
1. Cliente envia keyword "PARAR"/"CANCELAR" → INSERT em `followup_blacklist` ou `contact_blacklist`.
2. Operador clica "blacklist" no inbox.

---

## 7. Fluxo E2E — Trial Expirado

```
1. Trial criado em iptv_trials (via webchat ou manual)
   → expires_at = NOW() + duration
2. Cliente NÃO converte
3. Cron trial-followup roda 10h da manhã
4. SELECT iptv_trials WHERE expires_at < NOW() - delay
   AND followup_sent_at IS NULL
   AND server.trial_followup_enabled = true
   AND contact.plan_expires_at IS NULL  (não é cliente)
5. Para cada trial:
   a. Render template trial_followup_message com {{nome}}, {{servidor}}
   b. Verifica blacklist (followup_blacklist + contact_blacklist + global_blacklist)
   c. Verifica horário permitido (campaign.schedule_hours/days OR workspace_settings.followup_schedule)
   d. Chama Evolution API sendText
   e. INSERT followup_logs (type='trial_expired', metadata)
   f. UPDATE iptv_trials.followup_sent_at = NOW()
6. Se cliente converter depois:
   UPDATE followup_logs.converted_at quando subscription criada
```

---

## 8. Bugs / débitos

### 8.1 BUG: `followup_campaigns.total_sent` não atualizado
1.544 logs reais vs 0 sent nas campaigns. UI provavelmente faz JOIN, mas se não fizer, dashboard mostra zero.

### 8.2 BUG: dois sistemas paralelos `follow_up_log` vs `followup_logs`
- `follow_up_log` (single underscore): 0 rows. Usado pelo cron `follow-up` (genérico, 169 linhas).
- `followup_logs` (sem underscore): 1544 rows. Usado por trial/pix/abandoned-cart crons.

Confusing naming, e o cron `follow-up` parece deprecated. **Sugestão: dropar `follow_up_log` se inutilizado.**

### 8.3 BUG: `followup_campaigns` em workspace `diario-das-bruxas` é teste/sandbox
3 campaigns paused com 0 sent. Se workspace é teste, campanhas órfãs poluem dashboards. Cleanup manual sugerido.

### 8.4 BUG: scheduled_messages 4 pending mas alguns são antigos
```sql
-- verificar idade dos pending:
SELECT id, created_at, scheduled_for, AGE(NOW(), scheduled_for) FROM scheduled_messages 
WHERE status='pending' ORDER BY scheduled_for;
```
Se `scheduled_for < NOW()` e ainda pending, o cron de 1min não pegou — possível job preso.

### 8.5 BUG: 3 niveis de blacklist
`followup_blacklist`, `contact_blacklist`, `global_blacklist`. Crons checam alguns mas não todos. Atacante pode bypass: adicionar em um nível mas crons checam outro.

```sql
-- consolidar:
CREATE VIEW blacklist_all AS
  SELECT phone_e164 FROM contact_blacklist
  UNION SELECT phone FROM followup_blacklist
  UNION SELECT phone_e164 FROM global_blacklist;
```

### 8.6 BUG: cron `follow-up` (4h) não é referenciado por endpoints
Pode ser dead code. Verificar:
```sql
SELECT * FROM follow_up_log LIMIT 1;  -- 0 rows
```
Se nunca foi escrito, o cron está rodando à toa.

### 8.7 BUG: `abandoned_cart_log` 0 rows mas cron roda a cada 2h
Cron rodando inutilmente em workspaces que não habilitaram. Pode adicionar early-return se nenhum workspace tem `abandonedCart.enabled = true`.

### 8.8 BUG: `followup_logs` cresce sem retenção
1544 rows hoje × ~500B = 750 KB. Pequeno, mas com 100x volume vira 75 MB. Adicionar cron de db-retention (já existe `0 4 * * 0 db-retention`) que limpe `followup_logs > 90 dias`.

### 8.9 INCONSISTÊNCIA: dois nomes de coluna pra phone
- `followup_blacklist.phone` (text)
- `contact_blacklist.phone_e164` (varchar(20))
- `global_blacklist.phone_e164` (varchar(20))

Migrar todos pra `phone_e164` para consistência.

### 8.10 BUG: trial-followup atira mesmo se `contact.plan_expires_at IS NULL` ou expirado
A query é `(c.id IS NULL OR c.plan_expires_at IS NULL OR c.plan_expires_at < NOW())`. Aparentemente a intenção é "follow-up se NÃO é cliente ativo". Mas o `OR` com `IS NULL` é problemático — se contato não tem `plan_expires_at`, é considerado elegível. Pode causar follow-up incorreto.

---

## 9. Custos

### Storage
- followup_logs: 1544 × ~500B ≈ 750 kB
- scheduled_messages: 3599 × ~500B ≈ 2 MB
- global_blacklist: 215 × ~100B ≈ 22 kB
- followup_campaigns + outros: <100 kB

**Total: ~3 MB.**

### CPU
- Cron `scheduled-messages` (1min): leve, batch de 50, com indexes corretos.
- Cron `trial-followup` (1x/dia): pesado mas raro (limit 200 trials).
- Cron `pix-followup` (30min): médio.
- Cron `follow-up` (4h): processa 0 — desperdício mas <1ms.

**CPU total: <0.5% de uma vCPU.**

### Tokens IA
- Não usa IA diretamente. Templates são strings com variáveis substituídas.

**Custo total: <$1/mês.**

---

## 10. Resumo executivo

1. **Trial-followup é o motor principal:** 1417 envios em prod, 24 sent + 3 conversões via campaign trial_expired ativa em shark-panel. **Funciona.**
2. **PIX-followup** ativo, 127 envios, 8 sent + 1 conversão.
3. **Scheduled messages** é a feature mais usada (3.599 mensagens enviadas) — operadores agendam manualmente PIX/follow-ups via UI.
4. **Abandoned cart** dormente — feature pronta, ninguém habilitou em workspace_settings.
5. **`follow_up_log` + cron `follow-up`** parecem dead code.
6. **3 níveis de blacklist** sem unificação — risco de bypass.
7. **Anti-spam é robusto** no scheduled-messages cron — 3 camadas independentes.
8. **Counters em campaign** desatualizados (UI provavelmente calcula via JOIN).
