# 03 — Banco de Dados

> Engine: PostgreSQL (porta 5433 local)  
> Tamanho: 2,5 GB — 220+ tabelas  
> Migrações: 61 arquivos em `supabase/migrations/`  
> Atualizado: 2026-05-20

---

## Multi-tenancy

### `workspaces`
Entidade raiz do multi-tenancy. Cada workspace é um tenant isolado.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | Identificador |
| `name` | TEXT | Nome do workspace |
| `slug` | TEXT UNIQUE | Slug único para URLs |
| `owner_id` | UUID | Dono do workspace |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

**Relações:** → `whatsapp_instances`, `conversations`, `contacts`, `automations`, `jobs`, `resellers`, etc.

### `workspace_settings`
Settings JSON do workspace (configs gerais, notificações, integrações).

| Coluna | Tipo |
|--------|------|
| `workspace_id` | UUID PK FK → workspaces |
| `settings` | JSONB |

### `workspace_memberships`
Membros do workspace (multi-usuário).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `user_id` | TEXT | ID do NextAuth (text, não UUID) |
| `role` | TEXT | `owner` / `admin` / `agent` |
| `instance_permissions` | JSONB | Permissões por instância |

### `workspace_plans`
Plano contratado do workspace.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `plan` | TEXT | `free`/`starter`/`pro`/`business`/`enterprise` |
| `price_cents` | INT | Preço mensal em centavos ⚠️ zerado para alguns planos pagos |
| `status` | TEXT | `active`/`cancelled`/`past_due` |

### `workspace_subscriptions`
Assinaturas de plano (tabela separada do workspace_plans).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `plan` | TEXT | |
| `status` | TEXT | |
| `current_period_end` | TIMESTAMPTZ | Data de vencimento |
| **Dados prod** | | 4 linhas — 2 pagando de fato |

### `workspace_features`
Feature flags por workspace.

| Coluna | Tipo |
|--------|------|
| `workspace_id` | UUID FK |
| `features` | JSONB |

### `workspace_module_addons`
Add-ons de módulos (instâncias extras, créditos, etc.).

---

## Usuários / Auth

### `nextauth_users`
Usuários do sistema (tabela custom NextAuth).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `email` | TEXT UNIQUE | |
| `password_hash` | TEXT | bcrypt |
| `name` | TEXT | |
| `nickname` | TEXT | |
| `phone_whatsapp` | TEXT | |
| `avatar_url` | TEXT | |
| `status` | TEXT | `pending`/`active`/`rejected`/`approved` |
| `role` | TEXT | `user`/`master` |

**Dados prod:** 17 usuários — 4 active, 7 rejected, 1 pending

### `user_settings`
Preferências do usuário.

### `api_tokens`
Tokens para API externa v1. **0 linhas em produção.**

---

## WhatsApp / Instâncias

### `whatsapp_instances`
Instâncias WhatsApp via Evolution API.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `name` | TEXT | |
| `evolution_instance_id` | TEXT | ID na Evolution API |
| `phone_number` | TEXT | |
| `status` | TEXT | `connected`/`disconnected`/`connecting` |
| `is_paused` | BOOL | |
| `tag_color` | TEXT | Cor visual |

**Dados prod:** 29 instâncias (18 conectadas)

### `instance_metrics`
Métricas de performance das instâncias.

### `instance_health_log`
Log de saúde das instâncias. **82.485 linhas** (sem retenção adequada).

---

## Atendimento

### `conversations`
Conversas WhatsApp (uma por contato por instância).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `instance_id` | UUID FK | |
| `contact_phone` | TEXT | Telefone E.164 |
| `contact_name` | TEXT | |
| `contact_avatar` | TEXT | |
| `last_message_text` | TEXT | |
| `last_message_at` | TIMESTAMPTZ | |
| `unread_count` | INT | |
| `status` | TEXT | `open`/`closed`/`pending` |
| `assigned_to` | UUID | Agente responsável |
| `ai_mode` | TEXT | `suggestion`/`copilot`/`autonomous`/`off` |
| `sentiment` | TEXT | |
| `tags` | TEXT[] | |
| `metadata` | JSONB | |

**Dados prod:** 16.062 conversas

### `messages`
Mensagens das conversas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `conversation_id` | UUID FK | |
| `whatsapp_message_id` | TEXT UNIQUE | Idempotência |
| `text` | TEXT | |
| `from_me` | BOOL | |
| `status` | TEXT | `sending`/`sent`/`delivered`/`read`/`failed` |
| `media_url` | TEXT | |
| `media_type` | TEXT | |
| `timestamp` | TIMESTAMPTZ | |
| `metadata` | JSONB | |

**Dados prod:** 262.308 mensagens

### `tickets`
Tickets de suporte ao cliente final.

### `conversation_notes`
Notas internas sobre conversas.

---

## Contatos / CRM

### `contacts`
Contatos (clientes dos workspaces).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `phone` | TEXT | Telefone normalizado |
| `name` | TEXT | |
| `email` | TEXT | |
| `avatar_url` | TEXT | |
| `plan_type` | TEXT | Plano IPTV |
| `plan_status` | TEXT | `active`/`expired`/`cancelled` |
| `health_score` | INT | Score 0-100 |
| `sold_by_user_id` | TEXT | Vendedor responsável |
| `reseller_id` | UUID FK | |
| `tags` | TEXT[] | |
| `metadata` | JSONB | |

**Dados prod:** 17.643 contatos

### `contact_tags`
Tags disponíveis no workspace.

### `contact_tag_assignments`
Relação N:N entre contatos e tags.

### `contact_notes`
Notas sobre contatos.

### `crm_pipelines` / `crm_stages` / `crm_deals` / `crm_activities`
CRM completo. **0 deals em produção** (módulo criado mas não adotado).

---

## IPTV

### `iptv_trials`
Testes/trials de IPTV para clientes.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `contact_id` | UUID FK | |
| `server` | INT | Legado: 1=megabox, 2=tps (sem FK) |
| `app` | TEXT | App IPTV |
| `username` | TEXT | |
| `password` | TEXT | |
| `status` | TEXT | `active`/`expired`/`cancelled` |
| `expires_at` | TIMESTAMPTZ | |
| `sold_by_user_id` | TEXT | |
| `is_test` | BOOL | |

**Dados prod:** 1.287 trials

### `iptv_generated_tests`
Testes gerados automaticamente. **2.872 linhas.**

### `iptv_active_trials`
**VIEW** (não tabela) — agrega trials ativos com LATERAL JOIN nos payments. ⚠️ Cara em hot path.

### `iptv_app_configs`
Configurações dos apps IPTV por workspace.

### `iptv_server_bots` / `iptv_bots_by_app`
Bots de IPTV por servidor/app.

### `sigma_servers` / `sigma_mappings`
Servidores Sigma e seus mapeamentos.

---

## Checkout / Pagamentos

### `checkout_orders`
Pedidos do checkout (PIX e cartão).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `product_id` | UUID FK | |
| `customer_phone` | TEXT | |
| `customer_name` | TEXT | |
| `amount_cents` | INT | Valor em centavos |
| `status` | TEXT | `pending`/`paid`/`failed`/`cancelled` |
| `payment_method` | TEXT | |
| `amplopay_external_id` | TEXT | ID na Amplo Pay |
| `coupon_id` | UUID FK | |
| `metadata` | JSONB | |

### `checkout_plans`
Planos do checkout. `server` é campo INT legado (1=megabox, 2=tps).

### `payments`
Registro consolidado de pagamentos.

| Dados prod | Valor |
|-----------|-------|
| Total de pagamentos | 2.039 |
| Valor total transacionado | R$ 88.971,73 |
| Via checkout PIX | R$ 78.244,15 |
| Manuais | R$ 9.729,58 |

### `lowticket_orders` / `lowticket_products` / `lowticket_checkouts`
Sistema de checkout de baixo ticket por tenant (via `/p/[slug]`).

### `coupons`
Cupons de desconto.

### `subscriptions` / `subscription_payments` / `renewal_messages`
Assinaturas recorrentes dos clientes dos workspaces. **1.743 linhas.**

---

## Automações / Funis

### `automations`
Automações configuradas.

| Coluna | Tipo |
|--------|------|
| `id` | UUID PK |
| `workspace_id` | UUID FK |
| `name` | TEXT |
| `type` | TEXT |
| `status` | TEXT |
| `trigger_type` | TEXT |

### `automation_steps`
Passos de uma automação (enviar mensagem, esperar, condição, etc.).

### `automation_triggers`
Gatilhos de automação (keyword, horário, tag, evento).

### `automation_flow_sessions`
Sessões ativas de execução de automação.

### `automation_logs`
Histórico de execuções. **11.802 logs em produção.**

### `guided_funnels`
Funis guiados visuais (builder xyflow).

### `guided_funnel_steps`
Passos dos funis guiados.

### `followups` / `followup_queue` / `followup_campaigns`
Sistema de follow-up automatizado.

### `scheduled_messages`
Mensagens agendadas para envio futuro.

### `templates`
Templates de mensagem reutilizáveis.

---

## Marketing / Campanhas

### `campaigns`
Campanhas de mensagem em massa.

### `campaign_recipients`
Destinatários de cada campanha.

### `drip_campaigns`
Campanhas drip (sequência de mensagens ao longo do tempo).

### `bulk_send_batches` (e tabelas relacionadas)
Envio em lote para grupos.

### `ad_campaigns`
Campanhas de ads rastreadas.

### `links` / `link_clicks`
Links curtos com rastreamento de cliques.

### `nps_responses`
Respostas de NPS. **0 linhas em produção.**

---

## IA

### `ai_agents`
Agentes de IA configurados. **5 agentes ativos.**

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `name` | TEXT | |
| `system_prompt` | TEXT | Prompt do sistema |
| `mode` | TEXT | `suggestion`/`copilot`/`autonomous` |
| `instance_ids` | UUID[] | Instâncias vinculadas |
| `model` | TEXT | LLM usado |
| `temperature` | FLOAT | |

### `ai_agent_conversations` / `ai_agent_logs`
Histórico e logs dos agentes.

### `agent_contexts`
Contextos injetados no agente.

### `ai_writing_agents`
Agentes de escrita. **Esqueleto, 0 linhas.**

### `knowledge_items` / `knowledge_categories` / `knowledge_bases`
Base de conhecimento. **15 itens.**

### `knowledge_chunks` / `knowledge_documents`
Chunks para RAG. **0 linhas** (pgvector quebrado — Bug #14).

### `marketplace_agents`
Agentes do marketplace. **0 linhas.**

### `sales_brain_insights` / `sales_opportunities`
Sales Brain. `sales_opportunities` tem **3.169 linhas.**

### `journey_events` / `customer_journey` / `journey_insights`
Jornada do cliente (Sales Brain).

### `churn_alerts`
Alertas de churn. **33 linhas.**

### `conversation_analysis`
Análise de conversas por IA. **13.000+ linhas.**

---

## Equipe / Gamificação

### `agent_levels`
Níveis de gamificação disponíveis.

### `agent_xp_log`
Histórico de XP ganho.

### `agent_badges`
Badges/conquistas.

### `agent_commissions`
Comissões calculadas. **867 linhas em produção.**

### `agent_performance_daily`
Performance diária por agente.

---

## Resellers

### `resellers`
Revendedores cadastrados. **4 linhas.**

### `reseller_sales`
Vendas atribuídas a revendedores. **272 linhas.**

### `reseller_ledger`
Extrato financeiro do revendedor. **110 linhas.**

### `reseller_credit_ledger`
Extrato de créditos.

### `reseller_withdrawals`
Solicitações de saque.

### `reseller_levels`
Níveis de revendedor.

---

## Infraestrutura / Sistema

### `jobs`
Fila de jobs para processamento assíncrono.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID PK | |
| `workspace_id` | UUID FK | |
| `type` | TEXT | `send_message`/`process_webhook`/`ai_response`/etc. |
| `payload` | JSONB | |
| `status` | TEXT | `pending`/`running`/`succeeded`/`failed`/`cancelled` |
| `attempts` | INT | |
| `locked_at` | TIMESTAMPTZ | Para `FOR UPDATE SKIP LOCKED` |
| `locked_by` | TEXT | ID do worker |
| `run_at` | TIMESTAMPTZ | |
| `last_error` | TEXT | |

**Dados prod:** 17.571 jobs (16.439 succeeded, 10 pending/queued)

### `worker_runs` / `worker_heartbeats`
Heartbeat e histórico de execuções do worker. **383.560 linhas** (sem retenção).

### `worker_alert_configs`
Configurações de alertas do worker.

### `audit_logs`
Logs de auditoria de ações. **⚠️ 2.398.669 linhas — ~1 GB do banco.**

| Coluna | Tipo |
|--------|------|
| `workspace_id` | UUID FK |
| `user_id` | UUID |
| `action` | TEXT |
| `resource_type` | TEXT |
| `resource_id` | UUID |
| `changes` | JSONB |
| `ip_address` | INET |
| `created_at` | TIMESTAMPTZ |

### `processed_events`
Tabela de idempotência de eventos. **391.720 linhas** (sem TTL).

### `webhook_logs`
Logs de webhooks recebidos.

### `webhook_token_audit`
Auditoria de tokens de webhook. **250.268 linhas** (sem TTL).

### `webhooks`
Webhooks externos configurados pelo usuário.

---

## Whitelabel / Configurações Avançadas

### `whitelabel_settings`
Configurações de white-label por workspace.

### `workspace_notes`
Notas internas da workspace.

### `module_trials`
Trials de módulos específicos por workspace.

### `saas_tickets` / `ticket_messages`
Tickets de suporte SaaS. **0 linhas.**

### `internal_messages`
Chat interno. **Esqueleto.**

### `webchat_sessions` / `webchat_settings` / `webchat_plans` / `webchat_blocked_ips`
Widget de webchat público.

---

## Tabelas com problema de retenção (ação necessária)

| Tabela | Linhas | Impacto |
|--------|--------|---------|
| `audit_logs` | 2.398.669 | ~1 GB — P1 |
| `processed_events` | 391.720 | sem TTL — P2 |
| `worker_runs` | 383.560 | sem TTL — P2 |
| `webhook_token_audit` | 250.268 | sem TTL — P2 |
| `instance_health_log` | 82.485 | sem TTL — P2 |

---

*Veja também: [[00-visao-geral]] | [[04-pendencias]] | [[05-fluxos-principais]]*
