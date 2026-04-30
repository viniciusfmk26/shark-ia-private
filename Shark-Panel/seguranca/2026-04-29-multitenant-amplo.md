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
- ✅ Smoke-test live validado em produção (deploy `7eca2a7a1e74`, 30/04 04:09 UTC):
  - Sem auth → 401 ✅
  - Token bogus → 401 ✅
  - Token válido + messageId fake → **404** ✅ (era 401 antes do fix de middleware — provou que dual-auth executa)
- ⚠️ **Achado durante o smoke-test**: middleware do NextAuth bloqueava a request **antes** do handler executar. Resolvido em commit `0f01545d` adicionando `/api/media/` ao `EXCLUDED_PREFIXES` do middleware. Padrão segue `/api/webchat/` (auth interna no handler).
- Caso 200 (mídia real do webchat) ainda não validável — zero linhas no JOIN `webchat_sessions × messages WHERE media_type IS NOT NULL`. Fica para validação natural quando algum visitante real mandar imagem/áudio.

## Atualização 30/04 — tabela `iptv_trials`

A contagem inicial ("4 SEM workspace_id") **subestimou drasticamente**. Grep cirúrgico em `app/api/` retornou 25 hits; após exclusão de `migrate/*`, `cron/*` e `admin/*` por escopo, sobraram **9 arquivos**. Após análise: 7 vulnerabilidades reais (a maioria CRÍTICAS), 1 defense-in-depth, 1 falso positivo. **Esta foi a tabela com maior densidade de bugs por arquivo.**

| # | Rota | Categoria | Risco | Fix aplicado |
|---|------|-----------|-------|--------------|
| **🔴 CRÍTICOS (7)** | | | | |
| 1 | `app/api/iptv/payments/route.ts` (POST + GET) | B (sem auth) | 🔴 **CRÍTICO público** — endpoint sem nenhuma auth permitia registrar fake payments e converter trials de **qualquer tenant** pelo trialId | `auth()` + `getWorkspaceIdSafe()` em ambos handlers; `AND workspace_id` em SELECT iptv_trials, SELECT iptv_payments, INSERT iptv_payments e UPDATE iptv_trials. INSERT agora usa `workspaceId` em vez de `trial.workspace_id`. |
| 2 | `app/api/iptv/trials/[id]/route.ts` DELETE | B | 🔴 **IDOR** — sem auth, qualquer um deletava trial de qualquer tenant pelo UUID | `auth()` + `getWorkspaceIdSafe()` + `AND workspace_id` no DELETE iptv_trials e UPDATE conversations |
| 3 | `app/api/iptv/trials/[id]/temporary/route.ts` | B | 🔴 **IDOR** — sem auth (helper importado mas não usado), qualquer um marcava trial como temporário (4h pra cleanup) | `auth()` + `getWorkspaceIdSafe()` + `AND workspace_id` no UPDATE |
| 4 | `app/api/iptv/link-username/verify/route.ts` | B | 🔴 **Info leak público** — SELECT contacts e iptv_trials por phone globalmente; retornava nomes/usernames/conversation_ids de qualquer tenant que tivesse o telefone | `auth()` + `getWorkspaceIdSafe()` + `AND workspace_id` em ambos SELECTs |
| 5 | `app/api/iptv/trials/[id]/activate/route.ts` | B | 🔴 **Cross-tenant via trialId** — autenticado pode ativar trial de outro tenant; INSERT iptv_payments usava fallback `trial.workspace_id \|\| workspaceId` (escolhia o workspace do trial!); UPDATE contacts usava `trial.contact_id` (contato de outro tenant) | `AND workspace_id = $userWorkspaceId` no SELECT (27); **fallback removido** — INSERT agora usa `workspaceId`; UPDATE contacts ganhou `AND workspace_id = $4` |
| 6 | `app/api/iptv/generate-and-send/route.ts` POST | B | 🔴 **Reuse-guard cross-tenant** — busca trial ativo por phone sem workspace; se 2 tenants têm o mesmo phone, podia **reusar credenciais IPTV de outro tenant** e enviá-las pra contato do tenant atual via Evolution. | `AND workspace_id = $4` na SELECT reuse-guard (258); também na SELECT contactLastBotId (95) |
| 7 | `app/api/iptv/link-username/route.ts` | B | 🔴 Múltiplas IDORs — POST: SELECT por username globalmente (61) + UPDATE derivado (90); PATCH inteiro sem auth (218); GET inteiro sem auth (261) | POST: `AND workspace_id` em SELECT (61) e UPDATE (90); PATCH e GET ganharam `auth()` + `getWorkspaceIdSafe()` + filtros workspace |
| **🟡 DEFENSE-IN-DEPTH (1)** | | | | |
| 8 | `app/api/recorrencia/subscriptions/route.ts` | B | 🟡 Subqueries iptv_trials por `contact_id` apenas — transitivamente seguras (s já filtrada por workspace) mas frágeis a corrupção de dados | `AND t.workspace_id = s.workspace_id` nas 2 subqueries (65, 68) |

**Falsos positivos (não precisaram fix):**
- `app/api/contacts/tested/route.ts` — `whereClause` (linha 78) já inclui `t.workspace_id = $1` em todas as queries; o grep de janela perdeu por causa da indireção via variável.

**Achados extra desta rodada:**

1. **`iptv/trials/[id]/activate` tinha o anti-padrão clássico de `||` fallback**: `trial.workspace_id || workspaceId` na linha 86. Isso **explicitamente preferia o workspace do trial sobre o do user** — exatamente o oposto do correto. Esse fallback foi escrito provavelmente para "robustez" (e se trial.workspace_id estiver NULL?), mas com o filtro novo no SELECT, o trial só vem se for do mesmo workspace. Fallback removido.

2. **`iptv/payments/route.ts` era um endpoint financeiro completamente público** — sem auth, criava registros de pagamento e marcava trials como convertidos (`status = 'converted'`). Combinado com o fallback de #1, atacante podia: descobrir trialIds via `link-username/verify` (também público), passar trialId para `payments` POST, criar payment fake no workspace alvo, e converter o trial. Toda a cadeia de comprometimento agora está fechada nesta rodada.

3. **Padrão de risco da família `iptv_trials`**: trial é uma entidade derivada (criada por geração de teste IPTV), e várias rotas operavam sobre ela usando apenas `trialId` como entrada, sem validar ownership. **Lição para o resto da auditoria**: toda tabela com `id UUID primary key` exposta em rota pública/autenticada precisa de filtro de workspace, não importa quão "interno" o ID pareça ser.

**Pendências residuais (fora do escopo desta task):**
- `app/api/migrate/**/*` que tocam `iptv_trials` — admin one-shot.
- `app/api/cron/{trial-followup,promote-expired-trials}` — gateado por CRON_SECRET, processa todos tenants intencionalmente.
- `app/api/admin/run-migration` — superadmin.

**Verificação pós-fix:**
- `npx tsc --noEmit` limpo nos 8 arquivos modificados.
- Grep cirúrgico continua listando hits para esses arquivos — esperado, pois o filtro está nas mutações via `AND workspace_id`.

## Atualização 30/04 — tabela `payments`

A contagem inicial ("2 SEM workspace_id") **subestimou novamente**. Grep cirúrgico em `app/api/` retornou 33 hits. Após excluir `migrate/*`, `cron/*`, `admin/*` por escopo, sobraram 18 hits em 13 arquivos. Após análise: 8 OK por design, 3 vulnerabilidades reais, 2 defense-in-depth.

| # | Rota | Categoria | Risco | Fix aplicado |
|---|------|-----------|-------|--------------|
| **🔴 CRÍTICOS (3)** | | | | |
| 1 | `app/api/inbox/conversations/[id]/ai-suggestion/route.ts` | B | 🔴 **Cross-tenant via `conversationId`** — `auth()` ✅ mas SELECT conversations sem workspace check; user autenticado podia passar conversationId de outro tenant e ter o **prompt da OpenAI alimentado com PII desse tenant** (nome, plano, contagem de pagamentos) | `getWorkspaceIdSafe()` + `AND workspace_id = $userWorkspaceId` em SELECT conversations (19); defense-in-depth nos SELECTs derivados de contacts (43), payments (61) e messages (72) |
| 2 | `app/api/external/metricas/route.ts` | B/C | 🔴 **Cross-tenant** — endpoint protegido por API key hardcoded; agregava vendas e faturamento de **todos os tenants** (linhas 16-26 e 28-34), expondo MRR/dados financeiros da plataforma inteira a quem tivesse a API key | `const uniflixWorkspaceId = process.env.UNIFLIX_WORKSPACE_ID ?? '00000000-0000-0000-0000-000000000002'`; `AND p.workspace_id = $1` em ambos SELECTs. Refatorou também a 3ª query (que já tinha o UUID hardcoded inline) para usar a mesma variável. |
| 3 | `app/api/external/pedidos/route.ts` | B/C | 🔴 **Cross-tenant** — listava pedidos (`payments` + `checkout_orders`) de **todos os tenants** via API key. Vazamento de PII (nome, telefone, valor, UTMs) de todos os clientes da plataforma | Mesma variável `uniflixWorkspaceId`; `WHERE p.workspace_id = $1` no SELECT payments; `AND co.workspace_id = $1` no SELECT checkout_orders. Reposicionou parâmetros do CTE (LIMIT/OFFSET passaram de $1/$2 para $2/$3) |
| **🟡 DEFENSE-IN-DEPTH (2)** | | | | |
| 4 | `app/api/recorrencia/sync/route.ts` | B | 🟡 2 subqueries `payments` por `contact_id` apenas; `c` (contacts) já workspace-filtered no CTE candidatos, transitivamente seguro | `AND p.workspace_id = $1` nas 2 subqueries scalares dentro do CTE candidatos (28-29, 32-33) |
| 5 | `app/api/iptv/trials/analytics/route.ts` | B | 🟡 2 subqueries `EXISTS payments` por `contact_id`; `tr` já workspace-filtered no CTE | `AND p.workspace_id = $1` nas 2 subqueries EXISTS no funil (131, 135) |

**Falsos positivos / OK por design (8 arquivos sem fix):**

- **`master/financeiro/route.ts`** + 4 arquivos `master/pessoas/*` — todos têm `isSuperAdmin()` no topo (return 403 se falhar). Cross-tenant intencional para painel master. Meu grep inicial falhou ao detectar `isSuperAdmin()` por bug no escape (`auth(\|...`).
- **`payments/webhook/route.ts:137`** — SELECT por `external_id` para idempotência (transação processada uma vez globalmente). Adicionar workspace_id quebraria a idempotência.
- **`payments/amplopay-webhook/route.ts`** (6 hits) — mesmo padrão: idempotência (1003) e cancellation/refund por `external_id` (transaction ID AmploPay, globalmente único). Workspace já vem derivado de `checkout_orders` upstream.
- **`checkout/status/[id]/route.ts`** — endpoint público que retorna apenas `{status: 'PAID'|'UNKNOWN'}`. Sem PII, é confirmação de pagamento equivalente ao próprio webhook.

**Achados extra desta rodada:**

1. **`external/*` revelou um padrão de risco específico de "API key hardcoded apontando para tenant fixo"**. O nome `'uniflix2026'` da API key sugeria que o endpoint deveria ser Uniflix-only, mas o código não impunha isso — leakava todos os tenants. **Lição**: quando uma API key tem nome/contexto que sugere ownership de um tenant específico, o filtro de workspace deve ser explícito no código, não inferido pelo cliente.

2. **`ai-suggestion` é o exemplo perfeito de leak via prompt LLM**: dados cross-tenant entravam no prompt da OpenAI, que então respondia ao atendente do tenant atual com sugestões baseadas em informações de outro tenant. Vazamento sutil porque a "vítima" não percebe — recebe uma sugestão estranha mas não rastreável à origem cross-tenant. **Toda rota que envia dados a um LLM precisa de filtro de tenancy ainda mais rigoroso, porque a saída do LLM frequentemente vaza informações da entrada de forma não-óbvia.**

3. **Padrão consolidado para idempotência de webhook**: SELECT/UPDATE por identificador externo único (transaction ID, evento ID, etc) **NÃO** deve incluir workspace_id, pois quebraria idempotência. Workspace é derivado uma vez ao processar o evento e usado nas mutações de negócio (em `contacts`, `tags`, etc), não nas guardas de idempotência.

**Pendências residuais (fora do escopo desta task):**
- **API key `'uniflix2026'` hardcoded** em `external/metricas` e `external/pedidos`. Deve ir para `.env` (`UNIFLIX_EXTERNAL_API_KEY` ou similar). É um problema de gestão de credenciais separado — fora de escopo da auditoria de tenancy mas crítico por si só.
- `app/api/migrate/**/*` que tocam `payments` — admin one-shot.
- `app/api/cron/{abandoned-cart,drip-campaigns}` — gateado por `CRON_SECRET`, processa todos tenants intencionalmente.

**Verificação pós-fix:**
- `npx tsc --noEmit` limpo nos 5 arquivos modificados.

## Atualização 30/04 — tabela `conversations`

Última tabela "quente" da auditoria. Grep cirúrgico retornou 47 hits; após excluir `migrate/*`, `cron/*`, `admin/*`, `master/*`, sobraram **22 hits em ~18 arquivos**. Análise: 2 críticos + 10 defense-in-depth + 6 OK por design (incluindo arquivos já tocados em rodadas anteriores).

| # | Rota | Categoria | Risco | Fix aplicado |
|---|------|-----------|-------|--------------|
| **🔴 CRÍTICOS (2)** | | | | |
| 1 | `app/api/inbox/conversations/[id]/summarize/route.ts` | B | 🔴 **Cross-tenant via conversationId via LLM** — `auth()` ✅ mas SELECT conversations sem workspace; user passa conv de outro tenant, OpenAI gera summary com PII desse tenant, e `UPDATE conversations SET ai_summary` salva o summary no registro do outro tenant. **Mesmo padrão de `ai-suggestion` da rodada `payments`.** | `getWorkspaceIdSafe()` + `AND workspace_id` em SELECT (19), SELECT messages (43), UPDATE (97) |
| 2 | `app/api/ai/vision/analyze/route.ts` | B | 🔴 **Cross-tenant via messageId via LLM** — auth ✅ mas SELECT messages, conversations e instance todos sem workspace check; OpenAI Vision analisa imagem de outro tenant; INSERT em `conversation_extracted_data` cria registro órfão (`workspace_id=user atual`, `conversation_id=outro tenant`) — **corrupção de dados cross-tenant**. | `AND workspace_id` em SELECT messages (73), conversations (117) e whatsapp_instances (125) |
| **🟡 DEFENSE-IN-DEPTH (10)** | | | | |
| 3 | `app/api/trial/web/route.ts:236` | C/B | 🟡 UPDATE WHERE id; conv vem de SELECT workspace-filtered (224) | `AND workspace_id = $4` no UPDATE |
| 4 | `app/api/inbox/send/route.ts:102` | B | 🟡 UPDATE WHERE id (webchat path); conv vem de SELECT (64) | `AND workspace_id = $3` no UPDATE |
| 5 | `app/api/inbox/conversations/[id]/archive/route.ts:44` | B | 🟡 SELECT secundário (gamificação) sem filtro; UPDATE prévio (36) já workspace-filtered | `AND workspace_id = $2` no SELECT |
| 6 | `app/api/instances/route.ts` (4 subselects) | B | 🟡 4 subselects `c.instance_id = wi.id` em ambas variantes (com/sem allowedIds); transitivamente safe via FK mas frágil | `AND c.workspace_id = wi.workspace_id` nos 4 subselects |
| 7 | `app/api/instances/health/route.ts` (3 hits) | B | 🟡 LEFT JOIN, JOIN aninhado e subselect — todos por `instance_id = wi.id` apenas | `AND c.workspace_id = wi.workspace_id` no LEFT JOIN, no JOIN c2 e no FROM c3 |
| 8 | `app/api/scheduled-messages/stats/route.ts:59` | B | 🟡 SELECT conv `id = ANY($1)`; IDs de scheduled_messages workspace-filtered | `AND workspace_id = $2` no SELECT |
| 9 | `app/api/iptv/extra-screen/route.ts:155` | B | 🟡 SELECT instance_id por id; workspaceId em scope | `AND workspace_id = $2` no SELECT |
| 10 | `app/api/iptv/sigma-activate/route.ts:269` | B | 🟡 Mesmo padrão | `AND workspace_id = $2` no SELECT |
| 11 | `app/api/webchat/start/route.ts:123` | C | 🟡 UPDATE WHERE id; conv vem de SELECT workspace-filtered (107) na mesma tx | `AND workspace_id = $4` no UPDATE |
| 12 | `app/api/webchat/message/route.ts:158` | C | 🟡 UPDATE WHERE id; session.conversation_id e session.workspace_id derivados de webchat_sessions na tx | `AND workspace_id = $3` no UPDATE (usando `session.workspace_id`) |

**Falsos positivos / OK por design (6 hits, 0 fix):**
- `app/api/inbox/conversations/route.ts:66` — `whereClause` dinâmico mas seeded com `workspace_id = $1` em `conditions[0]` (linha 47).
- `app/api/media/[messageId]/route.ts:115` — dual-auth (rodada anterior) já filtra messages por `workspace_id` + `conversation_id`; o instance_id derivado é workspace-validated.
- `app/api/metrics/webhook-worker/route.ts:63` — `requireSuperAdmin()` já gateia (rodada whatsapp_instances).
- `app/api/inbox/conversations/[id]/send-product/route.ts:105` — SELECT prévio já workspace-filtered (rodada whatsapp_instances).
- `app/api/instances/[id]/route.ts:185, 196` — workspace check explícito antes (rodada whatsapp_instances).
- `app/api/iptv/generate-and-send/route.ts:223, 597` — handler com workspaceId em scope (rodada iptv_trials).

**Achados extra desta rodada:**

1. **Padrão LLM-cross-tenant é recorrente**: `summarize` é a 3ª rota desta auditoria com o mesmo bug — `ai-suggestion` (rodada payments), `vision/analyze` (esta rodada) e `summarize` (esta rodada). **Toda rota que envia conversa/mídia/contato a um LLM precisa de workspace check explícito**, mesmo que pareça "interna".

2. **Vision tem o agravante extra de gravar de volta**: ao contrário de `summarize` (que escreve no MESMO registro lido), `vision/analyze` faz `INSERT INTO conversation_extracted_data` com `workspace_id = user` mas `conversation_id = outro tenant`. Isso quebra integridade referencial por tenant — registros órfãos que aparecem no dashboard do user mas apontam para conversa que ele não tem acesso.

3. **`webchat/*` segue o padrão correto Categoria C**: workspace derivado de `webchat_sessions` (não de `getWorkspaceIdSafe()`). Defense-in-depth foi adicionado nos UPDATEs por questão de blindagem, mas o design já estava correto.

## Resumo da auditoria multitenant 30/04 (todas as rodadas)

| Tabela | Críticos | Defense-in-depth | Falsos positivos / OK |
|--------|----------|------------------|------------------------|
| `messages` | 3 (incluindo dual-auth media) | 0 | 0 |
| `contacts` | 4 | 3 | 2 |
| `whatsapp_instances` | 4 | 9 | 5 |
| `iptv_trials` | 7 | 1 | 1 |
| `payments` | 3 | 2 | 8 |
| `conversations` | 2 | 10 | 6 |
| **Total** | **23 críticos** | **25 defense-in-depth** | **22 OK** |

Total: **48 fixes** aplicados em ~50 arquivos. Mais o entregável adicional de dual-auth em `media/[messageId]` (resolveu regressão do webchat).

**Pendências residuais consolidadas:**
- 🔴 API key `'uniflix2026'` hardcoded em `external/*` — para `.env` (`UNIFLIX_EXTERNAL_API_KEY`).
- `app/api/migrate/**/*` que tocam tabelas auditadas — admin one-shot.
- `app/api/cron/*` que agregam cross-tenant — gateados por `CRON_SECRET`, intencional.
- `iptv/link-username/route.ts` PATCH busca `iptv_trials` por `trialId` sem filtro (rodada messages original).
- Webhooks `webhook/connection` UPDATE por `name` podem casar instances cross-workspace se houver colisão (rodada whatsapp_instances).

**Verificação pós-fix:**
- `npx tsc --noEmit` limpo nos 12 arquivos modificados nesta rodada.
- ✅ Smoke-test live de `media/[messageId]` dual-auth validado em prod (3 casos negativos). Detalhes na seção "Fix 30/04 — webchat mídia dual auth".

## Lição final 30/04 — middleware vs handler auth

Ao fazer o smoke-test live do dual-auth do `media/[messageId]`, descobrimos que o NextAuth middleware estava bloqueando a request **antes** do handler executar — meu dual-auth (`auth()` ou `session_token`) nunca rodava no caso visitante porque a request morria no middleware com 401 + cookies de NextAuth no response.

**Causa**: `/api/media/` não estava em `EXCLUDED_PREFIXES` do `middleware.ts`. Resolvido em commit `0f01545d`.

**Lição operacional crítica para futuras rotas dual-auth**: toda rota com auth-interna (Categoria C — token público OU header customizado) **DEVE** estar em `EXCLUDED_PREFIXES`, senão o middleware NextAuth bloqueia upstream e o handler nunca executa. O `/api/webchat/` já segue esse padrão; o `/api/media/` agora também.

**Toda nova rota com fluxo de visitante anônimo (webchat, webhooks externos, magic links) precisa de checklist de 2 passos:**
1. Implementar dual-auth no handler.
2. Adicionar prefix em `EXCLUDED_PREFIXES` do middleware com comentário explicando o motivo.


