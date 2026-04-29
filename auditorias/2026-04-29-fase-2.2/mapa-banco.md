# Mapa do Banco — Shark Panel

> PostgreSQL 17, role `zapflix` (superuser + BYPASSRLS).
> Auditoria de leitura em 2026-04-29.
> 192 tabelas no schema `public`. Schema `auth.*` legado (Supabase) ainda existe — não usar.

---

## Top tabelas por volume (n_live_tup)

```
audit_logs                    1.459.260   ⚠️ sem retenção, ~347 MB
processed_events                260.010
worker_runs                     226.344
messages                        186.055
webhook_token_audit             124.399
instance_health_log              40.831
jobs                             17.731
contacts                         13.976
conversations                    10.116
conversation_knowledge            9.167
conversation_analysis             8.841
customer_journey                  8.207
funnel_execution_log              6.057
short_links                       4.931
tickets                           4.290
conversation_funnels_sent         3.704
scheduled_messages                3.596
sales_events                      2.628
sales_opportunities               2.592
iptv_trials                       1.604
iptv_logs                         1.599
payments                          1.546
followup_logs                     1.538
iptv_generated_tests              1.376
funnel_contacts                   1.296
worker_heartbeats                 1.098
checkout_orders                     522
internal_credits_transactions       393
agent_commissions                   383
subscriptions                       285
contact_tag_assignments             247
subscription_payments               196
agent_performance_daily              82
reseller_sales                       49
automation_media                     48
quick_trigger_config                 48
whatsapp_instances                   23
churn_alerts                         16
app_meta                             14
```

(Tabelas com 0-12 rows omitidas; na prática a grande maioria tem volume baixo até serem ativadas em produção.)

---

## Diagrama de relações (principais)

```
workspaces (1)
 ├── workspace_memberships (N)         user_id ↔ nextauth_users
 ├── workspace_settings (1)            jsonb
 ├── workspace_plans (1)               plan name
 ├── workspace_subscriptions (N)
 ├── whitelabel_settings (1)
 ├── nextauth_users (via membership)
 │    ├── nextauth_accounts (vazia)
 │    ├── nextauth_sessions (vazia — JWT mode)
 │    ├── password_reset_tokens
 │    ├── login_history
 │    └── api_tokens
 │
 ├── whatsapp_instances (N)
 │    ├── conversations (N)
 │    │    ├── messages (N)
 │    │    │    └── automation_media (FK opcional)
 │    │    ├── conversation_tags
 │    │    ├── conversation_transfers
 │    │    ├── conversation_funnels_sent
 │    │    ├── conversation_analysis (1:1)
 │    │    └── conversation_knowledge
 │    ├── instance_health_log
 │    ├── instance_alerts
 │    ├── instance_metrics / instance_metrics_daily
 │    ├── instance_migrations
 │    └── webhook_logs / webhook_token_audit
 │
 ├── contacts (N)
 │    ├── contact_tag_assignments → contact_tags / tags
 │    ├── contact_notes
 │    ├── contact_segments
 │    ├── contact_blacklist
 │    ├── contact_iptv_credentials
 │    └── contact_lists ← contact_list_members
 │
 ├── resellers (N) — workspace_id ON DELETE SET NULL
 │    ├── reseller_credit_ledger (N)   (kind: purchase | usage | adjust)
 │    ├── reseller_commissions (N)
 │    ├── reseller_sales (N)
 │    ├── reseller_withdrawals (N)
 │    ├── reseller_levels (N)          (level varchar default 'bronze')
 │    └── reseller_adjustments
 │
 ├── sigma_servers (N)                  (em prod: 1 global)
 │    └── sigma_plan_mapping → checkout_plans
 │
 ├── special_iptv_plans (N)             (4 slugs por workspace: monthly, quarterly, semiannual, annual)
 ├── checkout_plans (N)                 (key suffix -<workspaceId[:8]>)
 ├── checkout_orders (N)                (PIX via AmploPay)
 ├── checkout_config (key/value)
 │
 ├── payments (N)
 │    └── subscription_payments
 │
 ├── subscriptions (N)
 │    ├── contact_id → contacts
 │    ├── payment_id → payments
 │    └── (iptv_username/password/server/expires_at flat fields)
 │
 ├── iptv_trials (N) ← server_id (sigma_server) + bot_id
 ├── iptv_servers (N)
 ├── iptv_server_bots (N)
 ├── iptv_app_configs / iptv_server_app_configs
 ├── iptv_generated_tests
 │
 ├── automations (N)
 │    ├── automation_steps
 │    ├── automation_triggers
 │    ├── automation_executions
 │    ├── automation_execution_logs
 │    ├── automation_step_logs
 │    └── automation_flow_sessions
 │
 ├── guided_funnels (N)
 │    ├── guided_funnel_steps
 │    ├── guided_funnel_sessions
 │    └── guided_funnel_templates
 │
 ├── campaigns (N)
 │    ├── campaign_recipients
 │    └── (segments via contact_segments)
 │
 ├── drip_campaigns ← drip_campaign_steps + drip_campaign_enrollments
 │
 ├── ai_agents (N)
 │    ├── ai_agent_conversations
 │    ├── ai_agent_logs
 │    ├── ai_studio_conversations
 │    ├── app_flow_nodes
 │    └── ai_writing_agents
 │
 ├── knowledge_bases / knowledge_categories / knowledge_items / knowledge_documents / knowledge_chunks
 │
 ├── tickets ← ticket_messages
 │
 ├── jobs (N)                            (fila SKIP LOCKED)
 ├── audit_logs (N)
 └── workspace_notes
```

---

## Tabelas centrais — colunas relevantes

### `workspaces`
```
id                  uuid PK (default uuid_generate_v4())
name                text NOT NULL
slug                text NOT NULL UNIQUE
owner_id            uuid NOT NULL
created_at          timestamptz default now()
updated_at          timestamptz default now()
blocked_at          timestamptz
internal_chat_mode  varchar(20) default 'company'  ('company' | …)
```

Triggers: `workspaces_updated_at` BEFORE UPDATE → `update_updated_at()`.
Políticas RLS definidas mas não enforced (zapflix é BYPASSRLS).

### `nextauth_users`
```
id                       text PK (default gen_random_uuid()::text)
name                     text
email                    text UNIQUE
emailVerified            timestamptz
image                    text
password                 text                       (bcrypt $2a$12$…)
status                   varchar(20) default 'pending'   ('pending' | 'approved' | 'rejected')
nickname                 text
phone_whatsapp           text
avatar_url               text
requested_workspace_id   uuid
requested_role           varchar(20) default 'agent'
approved_by              uuid
approved_at              timestamptz
role                     varchar(20) default 'user'
                         CHECK role IN ('user', 'admin', 'superadmin')
```

⚠️ Distinção importante: `nextauth_users.role` é GLOBAL (user / admin / superadmin). A role POR WORKSPACE está em `workspace_memberships.role` (owner / admin / agent / viewer).

Em prod (29/04/2026):
- 30 usuários totais (29 `role='user'`, 1 `role='superadmin'`)
- 5 owners + 3 admins distribuídos em 5 workspaces (Superadmin Sistema sem membros)

### `workspace_memberships` (não detalhado nesta auditoria)
```
workspace_id  uuid FK
user_id       text FK
role          text  ('owner' | 'admin' | 'agent' | 'viewer')
created_at    …
```

### `resellers`
```
id                  uuid PK
workspace_id        uuid (ON DELETE SET NULL — reseller pode existir órfão)
user_id             text FK nextauth_users
name                text NOT NULL
email               text NOT NULL
phone_whatsapp      text
referral_code       text NOT NULL UNIQUE
type                text default 'reseller'   ('reseller' | 'affiliate')
status              text default 'pending'    ('pending' | 'approved' | …)
commission_percent  numeric(5,2) default 50.00
balance_cents       integer default 0          # comissão em centavos (saca-vel)
plan                text default 'reseller'
plan_amount_cents   integer default 19700
plan_expires_at     timestamptz
notes               text
iptv_credits        integer NOT NULL default 0   # créditos para ativar clientes IPTV
payout_mode         text NOT NULL default 'commission'   CHECK ('commission' | 'credit')
created_at, updated_at
```

Em prod: 4 resellers, todos `status='approved'`.

### `reseller_credit_ledger` (imutável, append-only)
```
id                       uuid PK
reseller_id              uuid FK ON DELETE CASCADE
kind                     text NOT NULL  ('purchase' | 'usage' | 'adjust' | …)
amount                   integer NOT NULL  # signed (-N para usage, +N para purchase)
balance_after            integer NOT NULL  # snapshot pós-aplicação
cents_paid               integer
iptv_customer_id         text  # username Sigma quando kind='usage'
special_plan_id          uuid → special_iptv_plans
months_sigma_activated   integer
pix_identifier           text
description              text
performed_by             uuid → nextauth_users.id
created_at               timestamptz NOT NULL default now()
```

### `subscriptions`
```
id                   uuid PK
workspace_id         uuid NOT NULL
contact_id           uuid → contacts
plan_name            text NOT NULL
plan_price_cents     integer NOT NULL
billing_cycle        text default 'monthly'   ('monthly' | 'manual' | …)
status               text default 'active'    ('active' | 'cancelled' | 'churned' | …)
started_at           timestamptz NOT NULL default now()
next_billing_at      timestamptz
cancelled_at, churned_at
source               text default 'manual'    ('manual' | 'amplopay' | 'credits' | …)
payment_id           uuid → payments
iptv_username        text
iptv_password        text
iptv_server          text
iptv_app             text
iptv_expires_at      timestamptz
notes                text
created_at, updated_at
```

⚠️ Coluna `iptv_*` é ground-truth do que foi ativado. **Bug B-AMPLOPAY-001:** webhook AmploPay não preenche essas colunas (deixa NULL); credenciais ficam só em `payments.metadata` JSONB.

### `sigma_servers`
```
id            uuid PK
workspace_id  uuid NOT NULL
name          text NOT NULL          # ex: "Servidor 2"
display_name  text NOT NULL default 'UNIFLIX'
panel_url     text NOT NULL default 'https://sharks10.top/api'
token         text NOT NULL          # ⚠️ plaintext
user_id       text NOT NULL          # account id no Sigma
is_active     boolean default true
is_global     boolean default false
created_at    timestamptz default now()
```

Em prod: **1 servidor**, `workspace_id=00000000…0002`, `is_global=true`. Outros workspaces caem nele via fallback.

### `special_iptv_plans`
```
id                 uuid PK
workspace_id       uuid NOT NULL FK
slug               text NOT NULL    # 'monthly' | 'quarterly' | 'semiannual' | 'annual'
name               text NOT NULL    # 'Mensal' | 'Trimestral' | …
sigma_months       integer NOT NULL # quanto Sigma deve cobrar
client_months      integer NOT NULL default 1   # quanto vale pro cliente
credits_cost       integer NOT NULL
display_order      integer NOT NULL default 0
is_active          boolean NOT NULL default true
description        text
sigma_package_id   text NOT NULL    # ID do pacote no Sigma
sigma_server_id    uuid → sigma_servers
created_at, updated_at
```

Em prod (workspace `…0002`):
```
monthly     | sigma_months=1 | client_months=1  | credits_cost=1 | sigma_package_id=BV4D3rLaqZ ✅
quarterly   | sigma_months=3 | client_months=3  | credits_cost=3 | sigma_package_id=RYAWRk1jlx ✅
semiannual  | sigma_months=3 | client_months=6  | credits_cost=3 | sigma_package_id=RYAWRk1jlx ❌ B-009
annual      | sigma_months=3 | client_months=12 | credits_cost=3 | sigma_package_id=RYAWRk1jlx ❌ B-009
```

### `checkout_plans`
```
id                  serial PK
key                 varchar(50) NOT NULL UNIQUE   # ex: 'mensal-s1', 'mensal-s1-cb2544fc'
label               varchar(100) NOT NULL
price               integer NOT NULL              # cents
original_price      integer
discount, badge, monthly_label, savings  # marketing
active              boolean default true
sort_order          integer default 0
server              integer default 2             # 1=megabox, 2=tps (legado, sem FK)
workspace_id        uuid
extra_screen_price  integer default 1000
created_at, updated_at
```

> **Convenção `server`** (de memória): `server` é int legado 1/2 sem FK. Mapping por slug (1=megabox, 2=tps).

### `whatsapp_instances`
```
id                               uuid PK
workspace_id                     uuid
name                             text NOT NULL    # ex: 'Atendimento1'
evolution_instance_id            text NOT NULL    # nome registrado no Evolution
phone_number                     text
status                           text default 'disconnected'  ('connected' | 'disconnected' | …)
qr_code                          text
webhook_url                      text
profile_picture_url, profile_pic_url, profile_name
tag_color                        text
is_paused                        boolean default false
payment_confirmation_enabled     boolean default true
daily_limit                      integer default 150
hourly_limit                     integer default 20
anti_ban_enabled                 boolean default true
warmup_day                       integer default 0
instance_type                    text default 'atendimento'   ('atendimento' | 'payment_confirmation' | …)
is_confirmation_fallback         boolean default false
is_payment_confirmation          boolean default false
channel                          text default 'whatsapp'
banned_at, ban_count, ban_expires_at
failover_priority, is_backup
description                      text
created_at, updated_at
```

23 instâncias em prod.

### `iptv_trials`
```
id              uuid PK
workspace_id    uuid NOT NULL
contact_phone, contact_name
conversation_id, contact_id
server_id, server_name
bot_id, bot_name
app_type        text default 'xcloud'
username, password, code, dns
m3u_url, list_url
duration_hours  numeric NOT NULL default 2
started_at      timestamptz NOT NULL default now()
expires_at      timestamptz NOT NULL default now() + '02:00:00'
status          iptv_trial_status (enum: 'active' | 'expired' | 'converted' | …)
converted_at, subscription_id
generated_test_id
metadata        jsonb default '{}'
followup_sent_at, promoted_at
created_at, updated_at
created_by      text
```

### `audit_logs`
```
id              uuid PK
workspace_id    uuid NOT NULL
user_id         uuid
user_name       varchar(100)
user_email      varchar(255)
action          text NOT NULL    # ex: 'clients.activate.requested'
resource_type, resource_id
entity_type, entity_id
changes         jsonb            # diff antes/depois
payload         jsonb
details         jsonb default '{}'
summary         text
status          text
level           text default 'info'  ('info' | 'warn' | 'error')
type            text
ip_address      inet
user_agent      text
timestamp       timestamptz default now()
created_at      timestamptz default now()
```

⚠️ Desenho confuso — `timestamp` e `created_at` duplicados, `resource_*` e `entity_*` redundantes, sem retenção configurada (1.4M linhas).

### `jobs` (fila Postgres SKIP LOCKED)
```
id              uuid PK
workspace_id    uuid NOT NULL
type            text NOT NULL    # send_message | sync_instance | process_webhook | ai_response | …
payload         jsonb NOT NULL
status          text default 'pending'
attempts        integer default 0
max_attempts    integer default 3
run_at          timestamptz default now()
next_retry_at   timestamptz default now()
locked_at, locked_until, locked_by  # worker hostname
last_error, error
created_at, updated_at
```

---

## Inventário completo (192 tabelas)

```
_migrations                         abandoned_cart_log                  admin_payouts
agent_badges                        agent_commissions                   agent_daily_activity
agent_levels                        agent_performance_daily             agent_xp_log
ai_agent_conversations              ai_agent_logs                       ai_agents
ai_autopilot_settings               ai_learned_responses                ai_provider_settings
ai_studio_conversations             ai_suggestions_log                  ai_writing_agents
alerts                              api_tokens                          app_flow_nodes
app_meta                            app_problems_learned                app_users
audit_logs                          automation_execution_logs           automation_executions
automation_flow_sessions            automation_media                    automation_step_logs
automation_steps                    automation_triggers                 automations
bulk_send_config                    bulk_send_items                     bulk_send_jobs
campaign_recipients                 campaigns                           checkout_config
checkout_orders                     checkout_plans                      churn_alerts
commission_settings                 contact_blacklist                   contact_iptv_credentials
contact_list_members                contact_lists                       contact_notes
contact_segments                    contact_tag_assignments             contact_tags
contacts                            conversation_analysis               conversation_extracted_data
conversation_funnels_sent           conversation_knowledge              conversation_tags
conversation_transfers              conversations                       coupons
credit_store_items                  credit_store_redemptions            customer_journey
db_latency_samples                  drip_campaign_enrollments           drip_campaign_steps
drip_campaigns                      elevenlabs_settings                 elevenlabs_voices
employee_payroll                    feature_access                      follow_up_log
followup_blacklist                  followup_campaigns                  followup_logs
funnel_contacts                     funnel_execution_log                funnel_stages
funnels                             gamification_config                 global_blacklist
group_contacts                      group_messages                      guided_funnel_sessions
guided_funnel_steps                 guided_funnel_templates             guided_funnels
instance_alerts                     instance_health_log                 instance_metrics
instance_metrics_daily              instance_migrations                 internal_credits_transactions
internal_messages                   iptv_app_configs                    iptv_favorite_bots
iptv_generated_tests                iptv_logs                           iptv_payments
iptv_server_app_configs             iptv_server_bots                    iptv_servers
iptv_trials                         jobs                                journey_events
journey_insights                    knowledge_bases                     knowledge_categories
knowledge_chunks                    knowledge_documents                 knowledge_items
knowledge_templates                 login_history                       member_instance_permissions
message_templates                   messages                            nextauth_accounts
nextauth_sessions                   nextauth_users                      nextauth_verification_tokens
notifications                       outgoing_webhook_logs               password_reset_tokens
payments                            phone_corrections_log               postgres_metrics_history
postgres_weekly_reports             preset_messages                     processed_events
products                            quick_replies                       quick_trigger_config
renewal_config                      renewal_messages                    reseller_adjustments
reseller_commissions                reseller_credit_ledger              reseller_levels
reseller_sales                      reseller_withdrawals                resellers
rotation_logs                       sales_brain_insights                sales_events
sales_funnel_config                 sales_opportunities                 scheduled_messages
shop_redemptions                    short_links                         sigma_plan_mapping
sigma_servers                       special_iptv_plans                  store_products
subscription_payments               subscriptions                       supabase_usage_log
tags                                template_categories                 text_triggers
ticket_messages                     ticket_resolution_config            ticket_resolutions
tickets                             user_favorite_apps                  user_workspace_settings
webchat_blocked_ips                 webchat_plans                       webchat_sessions
webchat_settings                    webhook_logs                        webhook_token_audit
webhooks                            whatsapp_groups                     whatsapp_instances
whitelabel_settings                 withdrawal_requests                 worker_alert_configs
worker_alert_logs                   worker_heartbeats                   worker_runs
workspace_ai_credit_purchases       workspace_ai_credits                workspace_ai_usage
workspace_memberships               workspace_module_addons             workspace_notes
workspace_onboarding                workspace_plan_payments             workspace_plans
workspace_settings                  workspace_subscriptions             workspaces
```
