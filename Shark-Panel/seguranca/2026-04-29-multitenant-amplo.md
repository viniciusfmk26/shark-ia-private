# Auditoria Multi-tenant — Análise Ampla (29/04 noite)

## Tabelas críticas com workspace_id

Identificar TODOS endpoints que fazem SELECT/UPDATE/DELETE
SEM filtrar por workspace_id.

### Tabelas com workspace_id
```
          table_name           
-------------------------------
 abandoned_cart_log
 admin_payouts
 agent_badges
 agent_commissions
 agent_daily_activity
 agent_levels
 agent_performance_daily
 agent_xp_log
 ai_agent_conversations
 ai_agent_logs
 ai_agents
 ai_autopilot_settings
 ai_learned_responses
 ai_provider_settings
 ai_studio_conversations
 ai_suggestions_log
 alerts
 api_tokens
 app_problems_learned
 audit_logs
 automation_execution_logs
 automation_flow_sessions
 automation_media
 automation_triggers
 automations
 bulk_send_config
 bulk_send_jobs
 campaigns
 checkout_orders
 checkout_plans
 churn_alerts
 commission_settings
 contact_blacklist
 contact_iptv_credentials
 contact_lists
 contact_notes
 contact_segments
 contact_tags
 contacts
 conversation_analysis
 conversation_extracted_data
 conversation_funnels_sent
 conversation_knowledge
 conversation_transfers
 conversations
 coupons
 credit_store_items
 credit_store_redemptions
 customer_journey
 drip_campaigns
 elevenlabs_settings
 elevenlabs_voices
 employee_payroll
 feature_access
 follow_up_log
 followup_blacklist
 followup_campaigns
 followup_logs
 funnels
 gamification_config
 group_contacts
 group_messages
 guided_funnel_sessions
 guided_funnels
 instance_alerts
 instance_metrics
 instance_metrics_daily
 instance_migrations
 internal_credits_transactions
 internal_messages
 iptv_active_trials
 iptv_app_configs
 iptv_bots_by_app
 iptv_favorite_bots
 iptv_generated_tests
 iptv_logs
 iptv_payments
 iptv_servers
 iptv_trials
 jobs
 journey_events
 journey_insights
 knowledge_bases
 knowledge_categories
 knowledge_items
 member_instance_permissions
 message_templates
 messages
 notifications
 payments
 postgres_metrics_history
 postgres_weekly_reports
 preset_messages
 processed_events
 products
 quick_replies
 quick_trigger_config
 renewal_config
 renewal_messages
 reseller_adjustments
 resellers
 rotation_logs
 sales_brain_insights
 sales_events
 sales_funnel_config
 sales_opportunities
 scheduled_messages
 shop_redemptions
 short_links
 sigma_servers
 special_iptv_plans
 store_products
 subscription_payments
 subscriptions
 supabase_usage_log
 tags
 template_categories
 text_triggers
 ticket_resolution_config
 ticket_resolutions
 tickets
 user_workspace_settings
 webchat_blocked_ips
 webchat_plans
 webchat_sessions
 webchat_settings
 webhook_logs
 webhooks
 whatsapp_groups
 whatsapp_instances
 whitelabel_settings
 withdrawal_requests
 worker_alert_configs
 worker_alert_logs
 workspace_ai_credit_purchases
 workspace_ai_credits
 workspace_ai_usage
 workspace_memberships
 workspace_module_addons
 workspace_notes
 workspace_onboarding
 workspace_plan_payments
 workspace_plans
 workspace_settings
 workspace_subscriptions
(145 rows)

```

## Análise por tabela: queries SEM workspace_id
```
Tabela conversations: 92 queries totais, 3 SEM workspace_id
Tabela contacts: 74 queries totais, 5 SEM workspace_id
Tabela messages: 46 queries totais, 6 SEM workspace_id  <!-- ver atualização 30/04 abaixo -->
Tabela campaigns: 3 queries totais, 0 SEM workspace_id
Tabela automations: 7 queries totais, 0 SEM workspace_id
Tabela sales_opportunities: 5 queries totais, 0 SEM workspace_id
Tabela sales_events: 1 queries totais, 0 SEM workspace_id
Tabela knowledge_chunks: 1 queries totais, 0 SEM workspace_id
Tabela ai_provider_settings: 16 queries totais, 1 SEM workspace_id
Tabela agent_flows: 0 queries totais, 0 SEM workspace_id
Tabela iptv_trials: 28 queries totais, 4 SEM workspace_id
Tabela payments: 47 queries totais, 2 SEM workspace_id
Tabela subscriptions: 6 queries totais, 0 SEM workspace_id
Tabela whatsapp_instances: 93 queries totais, 12 SEM workspace_id
Tabela drip_campaigns: 5 queries totais, 0 SEM workspace_id
```

## Endpoints SEM workspace_id em sales_opportunities (alta prioridade)
```
```

## Atualização 30/04 — tabela `messages`

A contagem inicial ("6 SEM workspace_id") veio de `grep -L "workspace_id"` em `app/api/**/messages/`, o que dá **falsos positivos** em rotas que delegam para helpers (`lib/server/inbox.ts:getMessages` já filtra por workspace internamente).

Após inspeção manual, sobraram **3 rotas** que precisavam de correção, com fixes diferenciados por tipo:

| Rota | Toca `messages` direto? | Problema real | Fix aplicado |
|------|-------------------------|---------------|--------------|
| `app/api/inbox/messages/route.ts` | Não (delega `getMessages`) | Sem `auth()` antes da chamada | `await auth()` + 401 se sem sessão |
| `app/api/inbox/conversations/[id]/messages/route.ts` | Não (delega `getMessages`) | Sem `auth()` antes da chamada | `await auth()` + 401 se sem sessão |
| `app/api/webchat/messages/route.ts` | **Sim** (`SELECT ... FROM messages`) | Endpoint público anônimo (visitante webchat); aplicar `getWorkspaceIdSafe()` cairia no fallback `DEFAULT_WORKSPACE_ID` e expõe outro tenant | `RETURNING workspace_id` no UPDATE de `webchat_sessions` + `AND workspace_id = $X` no SELECT |

**Lição:** o padrão "use `getWorkspaceIdSafe()` em toda rota de `messages`" não cabe em endpoints públicos (`EXCLUDED_PREFIXES`). Para rotas anônimas (webchat, webhooks), derive o `workspace_id` da entidade autenticada por token (ex.: `webchat_sessions.workspace_id`), nunca da sessão do user.

**Verificação pós-fix:**
- `grep -L "workspace_id"` ainda lista as 2 rotas inbox — esperado e correto, pois o filtro está no helper.
- `npx tsc --noEmit` limpo nos 3 arquivos.

## Atualização 30/04 — tabela `contacts`

A contagem inicial ("5 SEM workspace_id") **subestimou** o problema. `grep -L "workspace_id"` deu zero arquivos (todos tinham o token em alguma query), mas **não pegou queries individuais sem filtro** dentro de arquivos parcialmente seguros. Foi necessário um grep cirúrgico de janela (`grep -rn "FROM contacts|UPDATE contacts|INSERT INTO contacts" + checagem de 8 linhas em volta`) para enumerar todas as queries.

Cobertura escolhida: **rotas não-`migrate/`** (ficaram para depois — são one-shot admin). Triagem dos suspeitos resultou em **9 arquivos** (2 falsos positivos + 7 com fix).

| Rota | Categoria | Risco | Fix aplicado |
|------|-----------|-------|--------------|
| `app/api/iptv/unlink-username/route.ts` | B (session) | 🔴 IDOR sem auth — anônimo podia desvincular IPTV de qualquer tenant pelo phone | `auth()` + `getWorkspaceIdSafe()` + filtro workspace na SELECT por phone (linha 37), no SELECT/UPDATE de `custom_fields`, e no DELETE de `iptv_trials` |
| `app/api/iptv/link-username/route.ts` | C (workspace via body/safe) | 🔴 IDOR cross-tenant — phone match global pegava `id` do tenant errado e UPDATEs derivados gravavam no contato errado | `AND workspace_id = $resolvedWorkspaceId` na SELECT por phone (linha 50). UPDATEs `WHERE id` ficam seguros por transitividade. |
| `app/api/automations/funis/enroll/route.ts` | B (session) | 🔴 Cross-tenant — POST autenticado podia pegar `contact_id` de outro tenant via match de phone e inscrever em funil próprio (info leak + poison) | `AND workspace_id = $2` na SELECT linha 122. Lookup só roda se `workspaceId` resolveu. |
| `app/api/metrics/webhook-worker/route.ts` | B (session) | 🟠 Sem auth, retornava `id/created_at/source` de contacts de **todos** os tenants para qualquer requester | `requireSuperAdmin()` no GET (mantém comportamento global, fecha o leak — dashboard master continua funcionando) |
| `app/api/contacts/backfill-clients/route.ts` | A (helper filtra) | 🟡 Sem `auth()`, anônimo caía no `DEFAULT_WORKSPACE_ID` via `getWorkspaceIdSafe`; também sem role check | `auth()` + 401. (Role check de admin segue como pendência — fora do escopo desta task.) |
| `app/api/payments/webhook/route.ts` | C (token webhook) | 🟡 Defense-in-depth — `contactId` já vinha de SELECT workspace-filtrada, mas UPDATEs `WHERE id` não cruzavam | `AND workspace_id = $X` em 3 UPDATEs (224, 265, 300). Param dinâmico para o UPDATE de plano (vitalicio/não vitalicio). |
| `app/api/payments/amplopay-webhook/route.ts` | C (token webhook) | 🟡 Mesma situação — `contactId` vem de `findOrCreateContact(workspaceId, ...)`; UPDATEs `WHERE id` ganharam guarda extra | `AND workspace_id = $X` em 5 UPDATEs (508, 568, 582, 1223, 1249). |

**Falsos positivos do grep cirúrgico (não precisaram de fix):**
- `app/api/contacts/route.ts` — `whereClauses` é dinâmico mas seeded com `'c.workspace_id = $1'`.
- `app/api/contacts/[id]/reseller/route.ts` — todas queries já têm `AND workspace_id = $2`.

**Lições adicionais:**
1. O método `grep -L` falha em arquivos parcialmente seguros (algumas queries com filtro, outras sem). Use grep cirúrgico com janela ou auditoria por query.
2. UPDATE/SELECT `WHERE id = $1` é seguro **apenas se** o `id` veio de uma SELECT já filtrada por workspace. Quando o `id` vem de match por `phone`/identificador externo, **falsa segurança por transitividade**.
3. Para webhooks (`token`-auth), o `workspaceId` vem de uma entidade vinculada (ex.: `checkout_orders`, `webchat_sessions`). Defense-in-depth (`AND workspace_id`) nos UPDATE protege contra futuro código que reutilize o `contactId` num contexto sem o filtro upstream.

**Pendências residuais (fora do escopo desta task):**
- `app/api/iptv/link-username/route.ts` PATCH (linhas 218-240) — busca `iptv_trials` por `trialId` sem filtro de workspace; o `trial.contact_id` resultante alimenta `UPDATE contacts WHERE id = $2`. Mesma classe de IDOR, mas em `iptv_trials`, não em `contacts`.
- `app/api/automations/funis/enroll/route.ts` GET (linha 192) — sem auth e sem workspace.
- Rotas em `app/api/migrate/**/*` que tocam `contacts` — admin one-shot, prioridade menor.

**Verificação pós-fix:**
- `npx tsc --noEmit` limpo nos 7 arquivos modificados.

