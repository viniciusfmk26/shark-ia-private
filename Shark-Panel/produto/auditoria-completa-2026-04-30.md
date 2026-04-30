# Auditoria completa — Zapflix Tech

> Data: 2026-04-30 · Workspace alvo: `00000000-0000-0000-0000-000000000002` (Uniflix)
> Banco: `wp_zapflix-db` (PostgreSQL 17, 192 tabelas) · App: Next.js 14 + Worker Node + Supercronic

---

## Sumário executivo

O sistema é um SaaS multi-tenant para revendedores de IPTV com automação de WhatsApp.
A operadora principal (Uniflix) tem **12.716 contatos**, **6.255 conversas**,
**170k mensagens** e **317 assinaturas ativas**.

O fluxo central — WhatsApp → trial IPTV → checkout PIX → assinante → renovação — está
implementado mas **fragmentado em três sistemas de pagamento paralelos** (`payments`,
`iptv_payments`, `workspace_plan_payments`) e tem **forte dependência de tabelas
desnormalizadas** (`contacts.plan_expires_at`, `contacts.custom_fields.iptv_plan`,
tags `Converteu`/`Trial Ativo`, `subscriptions`).

**Estado do produto:** 192 tabelas, das quais **75 estão completamente vazias** (~40%) —
indicando muitas features iniciadas e abandonadas. As features que efetivamente rodam
estão concentradas em ~30 tabelas centrais.

---

## PARTE 1 — Mapa do banco (192 tabelas, 1,5 GB)

### Tabelas com volume relevante (>100 kB)

| Tabela | Linhas (ws=Uniflix) | Tamanho | Função |
|---|---:|---:|---|
| `audit_logs` | — | 706 MB | Log auditoria (sem retenção — cresce indefinidamente) |
| `messages` | 170 449 | 662 MB | Mensagens WhatsApp |
| `jobs` | — | 212 MB | Fila de processamento (worker Postgres SKIP LOCKED) |
| `processed_events` | — | 134 MB | Idempotência de eventos Evolution |
| `worker_runs` | — | 49 MB | Execuções do worker |
| `conversations` | 6 255 | 38 MB | Conversas WhatsApp |
| `contacts` | 12 716 | 26 MB | Contatos / clientes |
| `webhook_token_audit` | — | 13 MB | Auditoria de tokens de webhook |
| `instance_health_log` | — | 9 MB | Health check de instâncias |

### Tabelas centrais do negócio

```
CORE TENANT      workspaces, workspace_memberships, workspace_settings
AUTH             nextauth_users (31), nextauth_sessions (vazia → JWT)
WHATSAPP         whatsapp_instances (35 total; 21 do ws Uniflix), conversations, messages
CONTATOS         contacts (12 716), contact_tags, contact_tag_assignments, contact_iptv_credentials
IPTV TRIALS      iptv_trials (19), iptv_generated_tests (1 425), iptv_servers (3),
                 iptv_server_bots (4), iptv_app_configs, iptv_payments (3), iptv_logs,
                 iptv_active_trials (VIEW)
PAGAMENTOS       payments (1 571), checkout_orders (559), subscriptions (317),
                 subscription_payments (214), iptv_payments (3), workspace_plan_payments (0)
AUTOMAÇÃO        automations (4 — todas paused), funnels (1 ativo), funnel_stages,
                 funnel_contacts (1 341), funnel_execution_log, scheduled_messages (3 714)
REVENDA          resellers (2), reseller_sales, reseller_commissions, reseller_credit_ledger,
                 reseller_withdrawals, reseller_levels (vazia)
GAMIFICAÇÃO      agent_levels, agent_performance_daily, agent_commissions, agent_xp_log (vazia)
AI               ai_agents, ai_provider_settings, ai_studio_conversations, ai_learned_responses,
                 ai_suggestions_log, ai_writing_agents
JOBS             jobs (11 133 succeeded), worker_runs, worker_heartbeats, worker_alert_*
```

### 75 tabelas vazias (potencial limpeza)

Todas as features abaixo têm tabela criada mas **0 registros**:

- **Gamificação inacabada:** `agent_xp_log`, `agent_badges`, `agent_daily_activity`, `gamification_config` (algumas)
- **AI inacabado:** `ai_agent_conversations`, `ai_agent_logs`, `ai_autopilot_settings`
- **Drip campaigns inacabadas:** `drip_campaigns`, `drip_campaign_steps`, `drip_campaign_enrollments`
- **Bulk send inacabado:** `bulk_send_jobs`, `bulk_send_items`, `campaigns`, `campaign_recipients`
- **Knowledge inacabado:** `knowledge_documents`, `knowledge_chunks`, `knowledge_items`, `knowledge_categories`
- **Store/credits inacabado:** `credit_store_redemptions`, `shop_redemptions`, `store_products`, `products`
- **Workspace plans/AI credits:** `workspace_plan_payments`, `workspace_ai_credits`, `workspace_ai_credit_purchases`, `workspace_module_addons`
- **Automation logs vazios:** `automation_executions`, `automation_step_logs`, `automation_execution_logs` — apesar de termos 4 automações registradas
- **NextAuth não usado (JWT):** `nextauth_sessions`, `nextauth_accounts`, `nextauth_verification_tokens`
- **Followup/feedback:** `followup_blacklist`, `follow_up_log`, `phone_corrections_log`
- **Resíduo Supabase:** `supabase_usage_log`
- **Workflow legado:** `app_flow_nodes`, `app_users`

---

## PARTE 2 — Entidades centrais e seus relacionamentos

### 1. Contato / Cliente — múltiplos espelhos

Um **mesmo cliente** pode aparecer em até 5 tabelas distintas, sem normalização forte:

```
nextauth_users (operadores/admins do SaaS, 31 registros)
       │
       └── workspace_memberships (9) → workspaces

contacts (clientes finais — 12 716)
   ├── plan_expires_at, plan_type, custom_fields.iptv_plan  ← estado de assinatura desnormalizado
   ├── conversations (FK contact_id, mas 887 telefones aparecem em múltiplas conversations
   │                  pois UNIQUE é (workspace_id, instance_id, contact_phone))
   ├── iptv_trials (FK contact_id; 19 ativos — vê seção Problemas)
   ├── payments (FK contact_id; 1 571)
   ├── subscriptions (FK contact_id; 317)
   ├── contact_tags (Converteu, Trial Ativo, Trial Expirado — fonte da verdade ALTERNATIVA)
   ├── contact_iptv_credentials (vincula login/senha IPTV ao contato)
   └── checkout_orders (FK por whatsapp string, NÃO por contact_id — 559 orders)

resellers (2) — overlap parcial com nextauth_users (FK user_id) e workspaces
```

**Identidade frágil**: o "mesmo cliente" pode ter:
- 1 row em `contacts`
- 5+ rows em `conversations` (uma por instância WhatsApp que falou com ele)
- 0–N rows em `iptv_trials` (todos ativos hoje, expirados deletados pelo cron)
- 1+ rows em `payments` (cada compra gera uma)
- 0–1 rows em `subscriptions` (criada pelo `recorrencia/sync`)
- 1+ rows em `checkout_orders` (cada PIX gerado)

A "fonte da verdade" sobre se alguém é cliente ativo está **espalhada em 4 lugares**:
`contacts.plan_expires_at`, `contacts.custom_fields.iptv_plan`, tag `Converteu`,
`subscriptions.status='active'`. O código de listagem em `app/api/contacts/route.ts`
combina todos eles via OR.

### 2. Pagamentos — três sistemas paralelos

| Sistema | Linhas | Quem grava | Vincula a | Status |
|---|---:|---|---|---|
| `payments` | 1 571 | webhook AmploPay (`/api/payments/amplopay-webhook`), webhook checkout externo (`/api/payments/webhook` — DEPRECADO mas ativo) | `contact_id` (FK) + `external_id` | **Canônica** |
| `iptv_payments` | 3 | `/api/iptv/trials/[id]/activate` (ativação manual) | `trial_id` (FK iptv_trials) | Quase morta — só 3 ativações manuais |
| `workspace_plan_payments` | 0 | (nenhum) | `workspace_id` | **Dormente** — feature SaaS-de-SaaS não decolou |
| `subscription_payments` | 214 | join entre `subscriptions` e `payments` | tabela ponte | Auxiliar |

**1 307 pagamentos confirmados sem subscription** — o `recorrencia/sync` só pega
pagamentos dos **últimos 3 dias**, então o backlog histórico não é processado.

### 3. IPTV — fluxo trial → cliente

```
iptv_servers (3 — ex: megabox, tps)
    └── iptv_server_bots (4 — endpoints de geração)
            └── iptv_app_configs (per-app message templates)

POST /api/iptv/generate-and-send
    ├── chama Sigma/TopStreaming API externa
    ├── INSERT iptv_generated_tests (1 425 — log permanente)
    ├── INSERT iptv_trials (19 ativos hoje — expirados são deletados)
    ├── auto-enroll em funnel "Funil IPTV - Conversão de Teste"
    ├── envia mensagem via Evolution API
    └── update conversations.metadata.iptvTrial

iptv_trials.status enum: active | expiring | expired | converted
   → mas no banco SÓ existem 'active' (cleanup cron remove os outros)
```

**Anomalia crítica:** apesar de a aplicação tratar 4 status (active/expiring/expired/converted),
existem **só 19 trials no banco — todos active**. O histórico está em `iptv_generated_tests`
(1 425 registros). A fonte de verdade da conversão é a tag `Converteu` + `subscriptions`,
NÃO `iptv_trials.status='converted'`.

### 4. Mensagens e automações

```
WhatsApp → Evolution API → webhook → INSERT messages → UPDATE conversations.last_message_at

Disparadores de automação:
  ├── funnels (1 ativo: trial_created)
  ├── automations (4 cadastradas, TODAS paused — feriado, academia, manutenção, fora-do-horário)
  ├── scheduled_messages (3 705 enviadas, 6 pending — feature funcionando)
  ├── automation_triggers (152 kB de configs)
  ├── quick_trigger_config (176 kB — gatilhos por palavra-chave)
  └── jobs (worker processa async; 11 133 succeeded, fila vazia hoje)

Crons que disparam mensagens (via supercronic):
  ├── trial-followup    (envia followup de teste expirando)
  ├── pix-followup      (recupera carrinhos PIX abandonados)
  ├── renewal-check     (avisa renovação)
  ├── drip-campaigns    (TABELA VAZIA — não roda)
  ├── close-inactive    (fecha conversas)
  ├── promote-expired-trials (move trials)
  ├── follow-up         (campanhas followup_campaigns)
  ├── funnel-processor  (avança contatos no funil)
  └── scheduled-messages
```

### 5. Instâncias WhatsApp

| Workspace | Instâncias | Status |
|---|---:|---|
| Uniflix (ws=2) | 21 | 11 connected + 10 disconnected |
| (sem ws) | 6 | 2 connected + 4 disconnected |
| outros tenants | 8 | mix |

35 instâncias totais. Instâncias órfãs sem `workspace_id` precisam ser limpas.

---

## PARTE 3 — Fluxos do produto (rastreados nos arquivos)

### Fluxo 1: lead novo chega pelo WhatsApp

1. Mensagem chega em `evolution-api-2` → webhook em `/api/webhooks/evolution`
2. Worker insere row em `messages`, faz UPSERT em `conversations`
3. `contacts` é vinculado por telefone normalizado (`UNIQUE workspace_id+phone_e164`)
4. `GET /api/inbox/conversations` lista conversas via `getConversations()` em `lib/server/inbox`
5. Status inicial: `conversations.status = 'open'`. Aposentado: `'resolved'` cai para `'open'`
   se mensagem nova chegar (lib normaliza)

### Fluxo 2: geração de trial IPTV

`POST /api/iptv/generate-and-send` (linha 132 em `app/api/iptv/generate-and-send/route.ts`):

1. **Reuse guard** (linha 257): se já existe trial active+não expirado para mesmo
   `phone+server_id+app_type`, reutiliza credenciais e retorna sem chamar a Sigma
2. Chama `sigmaUrl` (resolvido por precedência `iptv_app_configs.chatbot_url` →
   `bot.chatbot_url` → `bot.bot_url` → construído de `server.base_url`)
3. Extrai credenciais (`username`, `password`, `dns`, `m3u_url`, `code`) da resposta
4. Renderiza mensagem via template (custom > workspace > hardcoded)
5. INSERT em `iptv_generated_tests` (log permanente) e `iptv_trials` (estado vivo)
6. **Auto-enroll** (linha 530): se existe funnel `is_auto=true, trigger_event='trial_created'`,
   insere em `funnel_contacts` (status active, próxima ação calculada por `delay_minutes`)
7. Envia via Evolution API: `POST /message/sendText/{instanceId}`
8. UPDATE `conversations.metadata.iptvTrial = {trialId, status:'active'}`
9. INSERT `iptv_logs` com duração

### Fluxo 3: pagamento e ativação

**Caminho A — checkout externo (PIX via AmploPay)**: `/api/payments/webhook`
(deprecado, ainda recebe do checkout MySQL externo)

1. Valida `secret` (env `PAYMENT_WEBHOOK_SECRET`)
2. Branches:
   - Se `transaction_id` casa com `workspace_module_addons` → ativa addon (30 dias)
   - Se casa com `workspace_ai_credit_purchases` → adiciona créditos AI
   - Senão: fluxo normal de pagamento de cliente
3. **Idempotência**: rejeita se `payments.external_id = transaction_id` já existe `confirmed`
4. INSERT `payments` (`payment_type='checkout_pix'`, `status='confirmed'`)
5. Resolve `contact_id` por `REGEXP_REPLACE(phone)` exato
6. UPDATE `payments.contact_id`, remove tags Trial Ativo/Trial Expirado, adiciona Converteu
7. UPDATE `contacts.custom_fields.iptv_plan` ('mensal' / 'anual')
8. UPDATE `contacts.plan_type` + `plan_expires_at` (NOW() + 30/90/180/365/1825 dias ou +100 anos)
9. UPDATE `iptv_trials SET status='converted'` para todos active/expiring do telefone
10. **Comissão de agente** (gamificação): `recordSaleCommission`
11. Envia mensagem de confirmação + recibo via Evolution

**Caminho B — ativação manual**: `POST /api/iptv/trials/[id]/activate`

1. Lê `checkout_plans` para resolver preço/meses, ou usa "cortesia" se `is_courtesy=true`
2. INSERT `iptv_payments` (não `payments`!) com `payment_method='manual'|'cortesia'`
3. UPDATE `iptv_trials.status='converted'`
4. UPDATE `contacts.plan_type` + `plan_expires_at`

> **Inconsistência**: os dois caminhos gravam em **tabelas diferentes** (`payments` vs `iptv_payments`).
> Quem consulta histórico vendo só `payments` perde as ativações manuais; quem só vê
> `iptv_payments` perde tudo do checkout.

### Fluxo 4: automações e mensagens automáticas

Disparadores possíveis:

- **Funil de conversão** (`funnels.is_auto=true, trigger_event='trial_created'`) — auto-enroll
  no `generate-and-send`, executado pelo cron `funnel-processor` (avança `funnel_contacts.next_action_at`)
- **Automations** (4 cadastradas, todas paused): `trigger_type='any_message'`
- **Scheduled messages** (3 705 enviadas; cron `/api/cron/scheduled-messages` processa)
- **Quick triggers** (palavras-chave): tabela `quick_trigger_config` (176 kB)
- **Followup de trial**: cron `trial-followup` lê `iptv_trials.followup_sent_at IS NULL`
- **PIX followup**: cron `pix-followup` recupera `checkout_orders.status IN ('pending','created')`
  com `pix_followup_sent < N`
- **Renewal**: cron `renewal-check` lê `contacts.plan_expires_at`, marca `renewal_notified_today`
- **Drip campaigns**: tabelas vazias — feature não usada

### Fluxo 5: recorrência

`POST /api/recorrencia/sync` (linha 8 em `app/api/recorrencia/sync/route.ts`):

Cria `subscriptions` a partir de duas fontes:

1. **Contatos com `plan_expires_at IS NOT NULL` sem subscription ativa** — usa último
   `payments` confirmado dos últimos 3 dias para inferir `plan_name` + `billing_cycle`
2. **Pagamentos confirmados últimos 3 dias sem subscription** — DISTINCT ON contact_id

Em ambos: sanitiza descrição (remove `RefXXX`/`SellerXXX`, troca "Zapflix" pela `brand_name`).
Detecta cycle por keywords (`vital/lifetime`/`anual`/`semest`/`trimestr`/`avulso`) ou
faixa de valor.

`GET /api/recorrencia/subscriptions` lista com `effective_status` derivado:
- `s.status='active' AND next_billing_at < NOW()` → `overdue`
- `... <= NOW() + 7d` → `expiring`
- senão → `s.status`

Calcula custo/lucro/margem usando `workspace_settings.subscription_cost_cents`.

---

## PARTE 4 — Problemas e inconsistências (workspace Uniflix)

### Resultados das queries de diagnóstico

| Métrica | Valor | Severidade |
|---|---:|---|
| Contatos com `phone` literal duplicado | 0 | ✅ |
| Trials sem `contact_id` | 0 | ✅ |
| Conversas sem `contact_id` | 2 | 🟡 baixo |
| Status atual de `iptv_trials` | 19 — 100% `active` | 🔴 ver nota |
| Contacts ativos (`plan_expires_at > NOW()`) | 282 / 12 716 (~2,2%) | informação |
| Contacts sem plano | 12 434 (~97,8%) | esperado (são leads/trials) |
| `iptv_payments` sem trial vinculado | 3 / 3 | 🔴 100% órfão |
| `payments` sem `contact_id` | 94 / 1 571 (~6%) | 🟡 |
| `subscriptions` sem `payment_id` | 67 / 317 (~21%) | 🟡 |
| **Pagamentos confirmados sem subscription** | **1 307 / 1 488 (~88%)** | 🔴 |
| Contatos com `plan_expires_at` mas sem subscription ativa | 19 | 🟡 sync pendente |
| Conversas com mesmo `contact_phone` em múltiplas instâncias | 887 telefones | 🟡 inflação |
| `checkout_orders` paid | 398 | ✅ |
| `checkout_orders` created (PIX gerado, não pago) | 122 | informação |
| `checkout_orders` cancelled | 35 | ✅ |
| `checkout_orders` error | 4 | 🟡 |

### Top conversas duplicadas (mesmo telefone, várias instâncias)

```
553588481383   → 7 conversas (uma por instância distinta)
555391130902   → 6
5527998879878  → 6
5511938019117  → 6
5516993674804  → 5
...
```

Total: **887 telefones com >1 conversa**. Isso é por design (UNIQUE
`workspace_id+instance_id+contact_phone`), mas inflaciona métricas que contam
conversas como "leads únicos".

### Outras inconsistências de modelagem

1. **Tag `Converteu`** vs `subscriptions.status='active'` vs `contacts.plan_expires_at > NOW()`
   vs `contacts.custom_fields.iptv_plan IN (...)` — **4 fontes** discordando
   (rota `/api/contacts` faz OR em todas para listar "clientes")

2. **`iptv_trials.status` enum tem 4 valores, banco tem só `active`** — o cleanup
   (`delete_old_trials`, `delete_expired_trials`) apaga histórico. Conversões reais
   ficam em `iptv_generated_tests` (1 425) + `funnel_contacts.status='converted'` (328)
   + tag `Converteu`. Confuso.

3. **`payments` vs `iptv_payments`** — duas tabelas para o mesmo conceito (pagamento
   de assinatura IPTV). `iptv_payments` quase morta (3 registros, todos órfãos).

4. **`workspace_plan_payments`** — feature SaaS-de-SaaS (cobrar tenants pelo uso do
   próprio Zapflix) implementada mas nunca ativada (0 registros).

5. **`checkout_orders` não tem FK para `contacts`** — vincula por string `whatsapp`,
   o que dificulta join. AmploPay webhook resolve no momento do pagamento via
   `REGEXP_REPLACE`, mas pode não casar quando há JIDs diferentes.

6. **Automations todas pausadas** — 4 automações (`Atendimento Feriado`, `Estou na Academia`,
   `Aviso de Manutenção`, `Fora do Horário`) cadastradas mas com `status='paused'`.

7. **Crons "fantasmas"** — 25 endpoints `/api/cron/*` existem; CLAUDE.md indica que
   apenas 4 estão agendados no supercronic. Os demais (incluindo `pix-followup`,
   `trial-followup`, `renewal-check`, `monthly-payroll`) **não rodam automaticamente**.

8. **`audit_logs` 706 MB sem retenção** — cresce indefinidamente; o cron `db-retention`
   existe mas não confirmado se está agendado.

9. **`auth.*` schema resíduo Supabase** (CLAUDE.md confirma) — `is_workspace_member()`,
   `get_workspace_role()` retornam NULL, mas RLS policies em `conversations` ainda
   referenciam essas funções.

10. **`processed_events` 134 MB** — idempotência de webhooks Evolution; pode precisar de
    purge (existe `purge-jobs`, não claro se cobre essa tabela).

---

## PARTE 5 — Mapa de entidades (diagrama textual)

```
                              workspaces (5)
                                   │
           ┌───────────────────────┼─────────────────────────────┐
           │                       │                             │
   workspace_memberships     whatsapp_instances (35)        workspace_settings
           │                       │
   nextauth_users (31)             │
           │                       │
           ├──→ resellers (2)      ▼
           │                conversations (6 255) ◄──── messages (170 449)
           │                  │  │       │                      │
           │                  │  │       └── scheduled_messages (3 714)
           │                  │  │
           │                  │  ▼
           │                  │  iptv_trials (19) ─────► iptv_generated_tests (1 425)
           │                  │       │                          │
           │                  │       │        iptv_servers (3) ─┘
           │                  │       │             └── iptv_server_bots (4)
           │                  │       │                       └── iptv_app_configs
           │                  │       │
           │                  │       └──► iptv_payments (3) [quase morta]
           │                  │
           │                  ▼
           │             contacts (12 716)
           │                  │  │  │  │
           │                  │  │  │  └── contact_tag_assignments → contact_tags
           │                  │  │  │       (Converteu / Trial Ativo / Trial Expirado)
           │                  │  │  └── contact_iptv_credentials
           │                  │  │
           │                  │  ├──► payments (1 571) ◄── webhook AmploPay
           │                  │  │       │                checkout externo (deprec.)
           │                  │  │       └─── subscription_payments (214)
           │                  │  │
           │                  │  └──► subscriptions (317) [criadas por recorrencia/sync]
           │                  │           ↑
           │                  │           │ FK payment_id (67 NULL)
           │                  │           │
           │                  └──► funnel_contacts (1 341) ──► funnels (1 ativo)
           │                              │                       └── funnel_stages
           │                              └── funnel_execution_log
           │
           └──► resellers (2) ──► reseller_sales / reseller_commissions / reseller_credit_ledger

   checkout_orders (559) [vincula a contacts por string whatsapp]
        └─ paid 398 / created 122 / cancelled 35 / error 4

   jobs (11 133 succeeded) ◄── worker (Postgres SKIP LOCKED, 12 tipos)

   workspace_plan_payments (0) [feature dormente — cobrar tenants pelo SaaS]
```

---

## PARTE 6 — Fluxo completo do cliente (passo a passo)

```
1. LEAD CHEGA
   ├─ Cliente manda mensagem WhatsApp
   ├─ Evolution API → webhook → worker
   ├─ INSERT messages + UPSERT conversations + UPSERT contacts
   └─ Conversa aparece em /inbox com status=open

2. INTERESSE EM TESTE
   ├─ Operador (ou bot) chama POST /api/iptv/generate-and-send
   ├─ Sistema reusa trial ativo OU pede credenciais à Sigma API
   ├─ INSERT iptv_generated_tests + iptv_trials (status=active, exp +2h)
   ├─ Auto-enroll em "Funil IPTV - Conversão de Teste" (funnel_contacts)
   ├─ Envia mensagem com login/senha via Evolution
   └─ Atualiza conversations.metadata.iptvTrial

3. SEGUIMENTO DO TESTE
   ├─ Funnel-processor cron avança o contato pelas stages do funil
   ├─ Trial-followup cron envia mensagem antes de expirar
   ├─ Trial expira (cleanup deleta o registro de iptv_trials,
   │                mas iptv_generated_tests permanece)
   └─ Tag "Trial Expirado" pode ser aplicada

4. CHECKOUT (cliente decide pagar)
   ├─ Cliente acessa checkout.appcineflick.com.br (Vite + tRPC + MySQL próprio)
   ├─ POST cria checkout_orders (status=created, gera PIX via AmploPay)
   ├─ Se demora: pix-followup cron envia lembretes (pix_followup_sent++)
   └─ AmploPay processa PIX

5. PAGAMENTO CONFIRMADO
   ├─ AmploPay webhook → /api/payments/amplopay-webhook (ou /api/payments/webhook deprec.)
   ├─ INSERT payments (payment_type=checkout_pix, status=confirmed)
   ├─ Resolve contact_id por REGEXP_REPLACE(phone)
   ├─ UPDATE payments.contact_id
   ├─ Remove tags "Trial Ativo"/"Trial Expirado", adiciona "Converteu"
   ├─ UPDATE contacts.plan_type + plan_expires_at (30/90/180/365/1825d ou +100y)
   ├─ UPDATE contacts.custom_fields.iptv_plan = 'mensal'/'anual'/...
   ├─ UPDATE iptv_trials SET status='converted' (do telefone)
   ├─ Comissão de agente (gamificação) → recordSaleCommission
   └─ Envia mensagem de confirmação + recibo via Evolution

6. CRIAÇÃO DE SUBSCRIPTION
   ├─ Cron (ou chamada manual) POST /api/recorrencia/sync
   ├─ Para contatos com plan_expires_at sem sub ativa, OU pagamentos últimos 3d sem sub
   ├─ INSERT subscriptions (cycle inferido por keyword/valor)
   └─ payment_id ↔ subscription (mas 67 subs ficam sem payment_id ainda)

7. ATIVAÇÃO MANUAL (alternativa via painel)
   ├─ POST /api/iptv/trials/[id]/activate
   ├─ Lê checkout_plans, calcula meses
   ├─ INSERT iptv_payments (NÃO payments!) — método 'manual'/'cortesia'
   ├─ UPDATE iptv_trials.status='converted'
   └─ UPDATE contacts.plan_type + plan_expires_at

8. RENOVAÇÃO
   ├─ Renewal-check cron lê contacts.plan_expires_at próximo de vencer
   ├─ Marca renewal_notified_today/_1d para evitar reenvio
   ├─ Envia mensagem (template em workspace_settings ou padrão)
   └─ Cliente paga → ciclo volta ao passo 5

9. CHURN
   ├─ Sem renovar: plan_expires_at < NOW(), subscription vira "overdue"
   ├─ Churn_alerts pode ser populada (96 kB de dados)
   └─ Sem cron de churn ativo confirmado
```

---

## PARTE 7 — Lista de problemas encontrados

### 🔴 Críticos

1. **Três sistemas de pagamento desconexos** (`payments`, `iptv_payments`, `workspace_plan_payments`).
   `iptv_payments` tem 3 registros, todos órfãos do FK `trial_id`. Ativação manual não
   aparece nos relatórios baseados em `payments`.

2. **88% dos pagamentos confirmados não têm subscription** (1 307 de 1 488). O
   `recorrencia/sync` só pega últimos 3 dias — backlog histórico nunca processado.

3. **`/api/debug/*` e `/api/migrate/*` sem autenticação** (já documentado em CLAUDE.md
   e SECURITY.md, mas listo para visibilidade).

4. **`iptv_trials` perde histórico** — só 19 ativos, todos `status='active'`. Status
   converted/expired existe no enum mas nunca aparece no banco. Histórico vai pra
   `iptv_generated_tests`, mas as duas tabelas armazenam dados sobrepostos.

### 🟡 Médios

5. **Estado de "cliente" desnormalizado em 4 lugares** (tag `Converteu`,
   `contacts.plan_expires_at`, `contacts.custom_fields.iptv_plan`, `subscriptions.status`).
   Risco de divergência crônica.

6. **887 telefones em múltiplas conversations** — esperado pela UNIQUE
   `(workspace_id, instance_id, contact_phone)`, mas atrapalha métrica de leads únicos.

7. **`checkout_orders` sem FK para `contacts`** — relacionamento por string
   `whatsapp` é frágil (formatos JID variáveis).

8. **`audit_logs` 706 MB sem retenção visível** — cron `db-retention` existe mas
   confirmar se está agendado no supercronic.

9. **Crons "fantasmas"**: 25 endpoints, só 4 agendados no supercronic.
   Features como `pix-followup`, `renewal-check`, `monthly-payroll`,
   `promote-expired-trials`, `drip-campaigns`, `close-inactive` **não rodam automaticamente**.

10. **4 automations cadastradas, todas `paused`** — usuário desativou ou nunca
    foram ativadas após teste. Limpar ou reativar.

11. **`subscription_payments` (214) vs `subscriptions.payment_id` (250 com valor)** —
    duas formas de relacionar pagamento↔subscription. Manter só uma.

12. **`processed_events` 134 MB** — verificar política de purge.

### 🟢 Cosméticos / debt baixa

13. **75 tabelas vazias** — features iniciadas e abandonadas (drip, campaigns, knowledge,
    store, AI agents, gamificação parcial, módulos addon, créditos AI, workspace plans).
    Ocupam pouco espaço mas poluem schema.

14. **Resíduo Supabase**: schema `auth.*`, RLS policies referenciando funções
    quebradas (`is_workspace_member`, `get_workspace_role`).

15. **`worker.ts` 7 669 linhas monolítico** (já em CLAUDE.md). Funciona mas dificulta
    manutenção.

16. **Status `resolved` legado em `conversations`** (2 150 registros) — código já
    normaliza para `open`, mas dados antigos persistem.

---

## PARTE 8 — Recomendações de refatoração

### Consolidar (alta prioridade)

1. **Unificar pagamentos**: migrar os 3 registros de `iptv_payments` para `payments`
   (com `payment_type='manual'` e `metadata.trial_id`), depois dropar `iptv_payments`.
   Atualizar `/api/iptv/trials/[id]/activate` para escrever em `payments`.

2. **Backfill de `subscriptions`**: rodar versão do `recorrencia/sync` sem o
   `INTERVAL '3 days'` para processar todo o backlog (1 307 pagamentos órfãos).
   Depois agendar `recorrencia/sync` no supercronic (atualmente roda só on-demand).

3. **Decidir fonte da verdade do "cliente ativo"**: escolher 1 entre tag `Converteu`,
   `subscriptions.status='active'`, `contacts.plan_expires_at > NOW()`. Sugestão:
   `subscriptions` como canônica, `contacts.plan_expires_at` como cache derivado,
   abandonar tag (ou usar só para UX visual).

4. **Adicionar FK `checkout_orders.contact_id`**: backfill via match por whatsapp,
   depois passar a popular no momento do checkout.

### Remover

5. **Dropar tabelas vazias confirmadamente sem código que escreva** (precisa varredura):
   `workspace_plan_payments`, `app_flow_nodes`, `app_users`, `supabase_usage_log`,
   `nextauth_accounts`, `nextauth_sessions`, `nextauth_verification_tokens` (JWT mode).

6. **Remover `iptv_payments`** após migração (item 1).

7. **Remover policies RLS quebradas** (Supabase) ou reescrever sem `auth.uid()`.

8. **Adicionar retenção em `audit_logs`** (90 dias?) e `processed_events` (30 dias?).

### Falta implementar

9. **Agendar crons no supercronic**: `pix-followup`, `trial-followup`, `renewal-check`,
   `monthly-payroll`, `promote-expired-trials`, `drip-campaigns`, `close-inactive`,
   `recorrencia/sync`, `db-retention`.

10. **Auth nas rotas `/api/debug/*` e `/api/migrate/*`** — bloqueador de segurança.

11. **Dashboard de saúde de dados**: query única que reporta os números da PARTE 4
    (rodar diariamente, alertar se piorar).

12. **Documentação de fluxo**: o ciclo trial → checkout → pagamento → subscription
    está espalhado em ~10 arquivos. Centralizar em `lib/server/customer-lifecycle.ts`.

---

## PARTE 9 — Glossário do produto

| Termo | Definição em linguagem de negócio | Tabela(s) |
|---|---|---|
| **Workspace** | Tenant isolado do SaaS. Cada cliente do Zapflix tem o seu. Uniflix é o principal. | `workspaces` |
| **Operador** | Funcionário do workspace que usa o painel. Tem login. | `nextauth_users`, `workspace_memberships` |
| **Contato** | Pessoa que existe no telefone — pode ser lead frio, em teste ou cliente pago. | `contacts` |
| **Lead** | Contato que ainda não fez teste IPTV. | `contacts` sem `iptv_trials` |
| **Trial / Teste** | Acesso IPTV temporário (2h) gerado por bot da Sigma. | `iptv_trials` (vivo), `iptv_generated_tests` (histórico) |
| **Cliente / Assinante** | Contato que pagou e tem `plan_expires_at` futura. | `contacts.plan_expires_at` + `subscriptions.status='active'` + tag `Converteu` |
| **Plano** | Pacote vendido (mensal, trimestral, semestral, anual, 5anos, vitalício). | `checkout_plans`, `subscriptions.billing_cycle`, `contacts.plan_type` |
| **Checkout order** | Pedido de PIX gerado para o cliente pagar. | `checkout_orders` |
| **Pagamento** | Confirmação de transação (PIX confirmado pela AmploPay ou ativação manual). | `payments` (canônico) + `iptv_payments` (legado) |
| **Subscription** | Recorrência ativa que dá acesso ao IPTV. Criada após pagamento. | `subscriptions` |
| **Conversa** | Thread de mensagens com um contato em uma instância WhatsApp. | `conversations` (UNIQUE workspace+instance+phone) |
| **Instância WhatsApp** | Linha telefônica conectada via Evolution API. Workspace pode ter várias. | `whatsapp_instances` |
| **Funil** | Sequência de mensagens automáticas após um trigger (hoje só `trial_created`). | `funnels`, `funnel_stages`, `funnel_contacts` |
| **Automation** | Resposta automática a evento (mensagem recebida, fora de horário etc.). | `automations`, `automation_triggers` |
| **Scheduled message** | Mensagem agendada para enviar em data/hora específica. | `scheduled_messages` |
| **Reseller** | Revendedor que ganha comissão por venda no checkout. | `resellers`, `reseller_sales` |
| **Tag** | Marcador no contato (Converteu, Trial Ativo, Trial Expirado, etc.). | `contact_tags`, `contact_tag_assignments` |
| **Bot IPTV** | Endpoint na Sigma/TopStreaming que gera credenciais de teste. | `iptv_server_bots` |
| **App IPTV** | Aplicativo cliente (xcloud, vizzion, playsim, etc.) com configs próprias. | `iptv_app_configs` |
| **Job** | Tarefa assíncrona processada pelo worker (envio de msg, sync, etc.). | `jobs` |
| **Cron** | Endpoint chamado pelo supercronic com `x-cron-secret`. | `app/api/cron/*` |

---

## Conclusão

O produto **funciona** no fluxo principal (lead → teste → pagamento → assinante)
mas carrega forte débito técnico de "features começadas e abandonadas" (75 tabelas
vazias) e **fragmentação de fontes de verdade** (3 sistemas de pagamento, 4 fontes
para "cliente ativo"). Os dois problemas mais urgentes para o operador são:

1. Os **1 307 pagamentos confirmados sem subscription** (relatórios de recorrência
   estão errando para baixo).
2. Os **crons que existem no código mas não estão agendados** no supercronic
   (renewal-check, pix-followup, trial-followup) — features de retenção que
   simplesmente não rodam.

A consolidação proposta (PARTE 8, itens 1–4) eliminaria a maior parte do risco
operacional sem reescrever código de negócio.
