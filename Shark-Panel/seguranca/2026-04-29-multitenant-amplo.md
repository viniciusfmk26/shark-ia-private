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

## Atualização 30/04 — tabela `whatsapp_instances`

A contagem inicial ("12 SEM workspace_id") **subestimou** novamente. Grep cirúrgico (janela de 10 linhas) retornou **53 hits em ~30 arquivos**. Após exclusão das 3 categorias intencionalmente cross-tenant — `migrate/*` (admin one-shot, deferido), `admin/*` (gateado por `requireSuperAdmin`), `cron/*` (gateado por `CRON_SECRET`) — sobraram **18 arquivos** para análise.

A triagem revelou que `whatsapp_instances` tem um padrão de risco distinto das tabelas anteriores: a maioria das rotas faz `SELECT` workspace-filtrado **antes** do `UPDATE`/`DELETE`, mas as mutações finais usam `WHERE id = $1` apenas. Transitivamente seguro, mas **frágil**: qualquer refactor que reuse o `instanceId` num contexto sem o filtro upstream abre IDOR. Por isso o fix uniforme é defense-in-depth (`AND workspace_id` em toda mutação).

| # | Rota | Categoria | Risco | Fix aplicado |
|---|------|-----------|-------|--------------|
| **🔴 CRÍTICOS (4)** | | | | |
| 1 | `app/api/media/[messageId]/route.ts` | B (sem auth) | 🔴 **CRÍTICO** — endpoint público que retornava bytes de mídia (imagem/áudio/vídeo) de qualquer tenant pelo `messageId` | `auth()` + `getWorkspaceIdSafe()` + `AND workspace_id = $2` na SELECT messages (linha 60). NOTA: muda comportamento — frontend mesma-origem já envia cookie, mas mídia do **webchat público** vai 401 e precisará de tratamento separado em rodada futura. |
| 2 | `app/api/ai/transcribe/route.ts` | B | 🔴 Cross-tenant via `messageId` — autenticado podia passar messageId de outro tenant, ler o áudio, transcrever, e a transcrição era SALVA de volta no message do outro tenant | `AND workspace_id = $2` em SELECT messages (linha 59), SELECT conversations (97), SELECT whatsapp_instances (105) e UPDATE messages (207). |
| 3 | `app/api/inbox/conversations/[id]/send-product/route.ts` | B | 🔴 Cross-tenant via `conversationId` — autenticado podia disparar produto via instância WhatsApp de outro tenant para contato de outro tenant | `getWorkspaceIdSafe()` + `AND workspace_id = $userWorkspaceId` na SELECT conversations (linha 27). |
| 4 | `app/api/payments/send-receipt/route.ts` | B | 🔴 Cross-tenant via `paymentId` — autenticado podia disparar recibo via WhatsApp de outro tenant ao contato de outro tenant | `getWorkspaceIdSafe()` + `AND p.workspace_id = $userWorkspaceId` no SELECT payments (linha 22). |
| **🟡 DEFENSE-IN-DEPTH (9)** | | | | |
| 5 | `app/api/whatsapp/instances/[id]/logout/route.ts` | B | 🟡 Transitivo (instanceId já validado upstream) | `AND workspace_id` no UPDATE linha 82 |
| 6 | `app/api/whatsapp/instances/[id]/reconnect/route.ts` | B | 🟡 Transitivo | `AND workspace_id` no UPDATE linha 91 |
| 7 | `app/api/instances/[id]/route.ts` (PATCH+DELETE) | B | 🟡 Workspace check explícito antes, mas UPDATE/DELETE finais sem cross | `AND workspace_id` no UPDATE PATCH (linha 101) e DELETE (205) |
| 8 | `app/api/instances/[id]/connect/route.ts` | B | 🟡 5 UPDATEs por `id` apenas | `AND workspace_id` em 5 UPDATEs (128, 191, 241, 277, 288) |
| 9 | `app/api/instances/[id]/sync-profile/route.ts` | B | 🟡 2 UPDATEs por `id` | `AND workspace_id` em UPDATE 119 e 134 |
| 10 | `app/api/instances/sync-evolution/route.ts` | B | 🟡 UPDATE por `existingId` (vem de mapa workspace-filtrado) | `AND workspace_id` no UPDATE linha 109 |
| 11 | `app/api/inbox/conversations/[id]/avatar/route.ts` | B | 🟡 SELECT instance por `id` — instance_id vem de conversation já validada | `AND workspace_id` no SELECT linha 58 |
| 12 | `app/api/groups/bulk-send/stats/route.ts` | B | 🟡 UPDATE inline em loop por `instance_id` | `AND workspace_id` no UPDATE linha 58 |
| 13 | `app/api/groups/route.ts` | B | 🟡 UPDATE por `inst.id` (vem de `getConnectedInstances(workspaceId)`) | `AND workspace_id` no UPDATE linha 36 |

**Falsos positivos / OK por design (5 arquivos sem fix):**
- `app/api/webhook/route.ts` e `app/api/webhook/connection/route.ts` — webhooks token-auth onde `workspace_id` é DERIVADO de `whatsapp_instances` por `evolution_instance_id`/`name` (globalmente únicos no Evolution). Design correto da categoria C.
- `app/api/resellers/withdraw/route.ts`, `app/api/resellers/public-signup/route.ts`, `app/api/affiliates/public-signup/route.ts` — SELECT global de instância por `phone_number LIKE '%superadmin%'` para notificar o admin via WhatsApp. Intencional, não é leak de tenant.

**Lições adicionais:**
1. **Defense-in-depth importa**: 9 dos 13 fixes não corrigiram um bug atual (tudo era transitivamente seguro), mas blindam contra refactors. Custo (4 caracteres `AND ws_id = $X`) é trivial perto do risco.
2. **`media/[messageId]` é exemplo do anti-padrão clássico**: rota "interna" (chamada pelo frontend) que não está em `EXCLUDED_PREFIXES` mas também não tinha `auth()`. Provavelmente confiava no middleware, mas o middleware só valida sessão — não valida tenancy. **Toda rota que recebe id de URL precisa filtrar por workspace ou validar ownership.**
3. **Webhooks (categoria C)** continuam sendo o padrão correto: derivar workspace de uma entidade autenticada por token (instance, conversation, etc), nunca usar `getWorkspaceIdSafe()`.

**Pendências residuais (fora do escopo desta task):**
- ~~`app/api/media/[messageId]` agora exige sessão — mídia do **webchat público** vai retornar 401.~~ **RESOLVIDO 30/04 — ver "Fix 30/04 — webchat mídia dual auth" abaixo.**
- `app/api/migrate/**/*` que tocam `whatsapp_instances` — admin one-shot, prioridade menor.
- Webhooks `webhook/connection` UPDATE por `name` (linha 75) podem casar instances cross-workspace se houver colisão de nome. Evolution garante unicidade global, mas vale auditar se DB tem constraint.

**Verificação pós-fix:**
- `npx tsc --noEmit` limpo nos 13 arquivos modificados.
- Grep cirúrgico continua listando hits para esses arquivos — esperado, pois o filtro está nas mutações via `AND workspace_id`. O `grep -L` continua retornando vazio.

### Fix 30/04 — webchat mídia dual auth

`app/api/media/[messageId]/route.ts` ganhou autenticação dupla para fechar a regressão introduzida pelo fix anterior (visitantes anônimos do webchat recebiam 401 ao tentar carregar mídias).

**Lógica implementada:**
1. Tenta `auth()` de NextAuth primeiro.
2. Se user autenticado → `workspaceId = await getWorkspaceIdSafe()` (fluxo antigo do dashboard, sem restrição de conversa).
3. Se NÃO autenticado → busca token em `request.headers.get('x-session-token')` ou query param `session_token`.
4. Se token presente → `SELECT workspace_id, conversation_id FROM webchat_sessions WHERE session_token = $1`. Se inválido → 401.
5. Se nenhum dos dois → 401.

**Restrição extra no caso visitante (decisão de segurança não explícita no briefing):**

A SELECT messages adiciona `AND conversation_id = $3` quando o auth veio do webchat, restringindo o visitante à própria conversa. Sem isso, um visitante com session_token válido conseguiria buscar mídia de **qualquer outra conversa do mesmo workspace** (mensagens internas de atendentes, conversas de outros clientes), o que seria um leak intra-tenant. O fluxo do dashboard mantém o filtro só por `workspace_id` (atendente precisa ver mídia de qualquer conversa).

```sql
-- User autenticado (dashboard):
WHERE id = $1 AND workspace_id = $2

-- Visitante webchat (anônimo):
WHERE id = $1 AND workspace_id = $2 AND conversation_id = $3
```

**Por que NÃO usar `getWorkspaceIdSafe()` no caminho do visitante:** sem session de user, ele cai no fallback `DEFAULT_WORKSPACE_ID` (variável de ambiente), o que retorna mídia de outro tenant arbitrário. Mesmo erro que cometemos quase em `webchat/messages` na primeira rodada.

**Padrão consolidado para rotas com dual-auth (dashboard + webchat público):**
- Dashboard: `auth()` + `getWorkspaceIdSafe()`, filtro `workspace_id`.
- Webchat: `webchat_sessions.session_token`, filtro `workspace_id AND conversation_id`.
- Header preferido: `X-Session-Token`. Query param `session_token` como fallback (compatibilidade com `<img src=...>` e `<audio src=...>` onde headers customizados não funcionam).

**Verificação:**
- `npx tsc --noEmit` limpo.
- Smoke-test live pendente — requer deploy. Session token de teste reservado: `3aee8bed-50a4-4048-90a8-1efbeefecdc5` (workspace `00000000-0000-0000-0000-000000000002`, conversa `b574acf9-29ef-4810-ba38-4b7dffb83a29`). Conversa não tem mensagem com mídia ainda; teste 200 precisa de messageId real após deploy.

