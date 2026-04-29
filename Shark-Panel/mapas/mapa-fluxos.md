# Mapa de Fluxos E2E — Shark Panel

> Fluxos críticos rastreados código-a-código. Auditoria de leitura em 2026-04-29.

---

## F1 — Reseller ativa cliente IPTV (Fase 2.2 — 29/04/2026)

**Entrada:** reseller logado em `app.sharkpanel.com.br` com saldo `iptv_credits >= credits_cost`.

```
[Frontend]
1.  Login em /login
    POST /api/auth/[...nextauth]
    → set cookie __Secure-authjs.session-token (JWT)

2.  Navega pra /reseller/clientes
    Sidebar "Revendedor" → "Meus Clientes"
    Page chama GET /api/resellers/clients (lista clientes ativados)

3.  Click "Ativar Cliente" → modal com form
    Campos: nome, phone (DDD obrigatório), planSlug
    GET /api/resellers/credits/balance → mostra saldo atual

4.  Submit
    POST /api/resellers/clients/activate
    body: { name, phone, planSlug }

[Backend — app/api/resellers/clients/activate/route.ts]
5.  auth() → userId
6.  Validações:
    - customerName não-vazio
    - phoneDigits ≥ 12 (normalizeBrPhone)
    - planSlug presente
7.  workspaceId = await getWorkspaceIdSafe()
8.  SELECT id, name, type FROM resellers
       WHERE user_id=$1 AND workspace_id=$2 AND status='approved'
         AND type IN ('reseller', 'affiliate')
    → 404 se não achar
9.  SELECT plan FROM special_iptv_plans WHERE workspace_id, slug, is_active=true
    → 404 se não achar
10. Pre-check saldo (best-effort, sem lock):
    SELECT iptv_credits FROM resellers WHERE id=$1
    → 402 se < credits_cost
11. findOrCreateContact(workspace, phoneDigits, customerName)
    UPSERT contacts ON CONFLICT (workspace_id, phone_e164)
12. logAudit('clients.activate.requested', …)

[TX atômica — lib/db.ts:tx()]
13. SELECT iptv_credits FROM resellers WHERE id=$1 FOR UPDATE   ← LOCK
14. Re-check saldo. Se insuficiente → throw 'insufficient_balance' → ROLLBACK
15. provisionSigmaByPackage({ serverId, packageId, customerName, phoneDigits, workspaceId })
    [lib/sigma/provision.ts]
    a) SELECT sigma_servers WHERE id=$1 → server (panel_url, token, user_id)
    b) findCustomer(server, phoneDigits)  via GET <panel>/webhook/customer?note=<phone>&token&userId
    c) Se já existe: renewCustomer
       Se não existe: createCustomer (POST <panel>/webhook/customer)
    d) Retorna { username, password, expires_at, action: 'created'|'renewed', server, mapping }
16. UPDATE resellers SET iptv_credits = newBalance, updated_at=NOW() WHERE id=$1
17. INSERT INTO reseller_credit_ledger (reseller_id, kind='usage', amount=-cost,
       balance_after, iptv_customer_id=username, special_plan_id, months_sigma_activated,
       description, performed_by) RETURNING id
18. COMMIT

[Pós-TX (não-transacional, fire-and-forget)]
19. INSERT INTO subscriptions (workspace_id, contact_id, plan_name, plan_price_cents=0,
       billing_cycle='manual', status='active', started_at=NOW(),
       iptv_username, iptv_password, iptv_server, iptv_expires_at,
       source='credits', notes='Ativado por <reseller> via créditos (X cred)')
    Se falhar → logAudit('clients.activate.subscription_insert_failed') + retorna 500
              (creds devolvidas no payload pra backfill manual)

20. pickEvolutionInstance(workspaceId, phoneDigits) → tier híbrido B+A:
    Tier 1 (conversation):
      SELECT wi.name FROM conversations c JOIN whatsapp_instances wi ON wi.id=c.instance_id
       WHERE c.workspace_id=$1 AND digits(c.contact_phone)=$2 AND wi.status='connected'
       ORDER BY c.updated_at DESC LIMIT 1
    Tier 2 (dedicated):
      SELECT name FROM whatsapp_instances WHERE workspace_id=$1 AND status='connected'
        AND payment_confirmation_enabled=true AND is_payment_confirmation=true LIMIT 1
    Tier 3 (fallback):
      SELECT name … AND payment_confirmation_enabled=true LIMIT 1

21. sendWhatsappCredentials:
    POST <EVOLUTION_API_URL>/message/sendText/<instance>
    headers: { apikey: EVOLUTION_API_KEY }
    body: { number: phoneDigits, text: buildSigmaMessage(...) }

22. logAudit('clients.activate.success', { ledgerId, sigmaUsername, tier, instance, sent })

23. Response 200:
    { ok: true, plan, sigma: { username, password, expires_at, server, isVip },
      newBalance, ledgerId, whatsapp: { sent, tier, instance } }

[Frontend — pós-resposta]
24. Toast verde "Cliente ativado!"
25. SWR revalida /api/resellers/clients (mostra novo cliente na lista)
26. SWR revalida /api/resellers/credits/balance (saldo atualizado)
```

**Pontos de falha tratados:**
- Sigma timeout/erro → throw `sigma_failed` → ROLLBACK do débito → 502
- Saldo insuficiente em race → ROLLBACK → 402
- INSERT subscription falha → 500 com creds no payload + audit (não rollback, Sigma já criou)
- Evolution API falha/sem instance → response retorna `whatsapp.sent=false, reason: 'no_instance'|'evolution_<status>'|'network'` mas a ativação continua válida

**Bug fix recente (29/04):** parser DD/MM/YYYY do Sigma — `parseSigmaDate()` em `provision.ts`.

---

## F2 — Cliente compra IPTV via PIX (checkout público)

```
[Cliente final, sem login]
1.  Acessa app.sharkpanel.com.br/comprar?ref=<referral_code>
    (ou checkout.appcineflick.com.br — sistema legado Vite/tRPC)

2.  Page chama:
    GET /api/checkout/config           → workspace branding + plans disponíveis
    GET /api/resellers/lookup?ref=X    → valida referral code (público)

3.  Cliente preenche: nome, whatsapp, plano, telas extras
    Submit → POST /api/checkout/create-pix
    body: { customer_name, whatsapp, plan_key, extra_screens, sale_type }

[Backend — app/api/checkout/create-pix/route.ts]
4.  Genera CPF/email/phone fake (ou usa do request)
5.  INSERT INTO checkout_orders (..., status='pending')
6.  SELECT amplopay_public_key, amplopay_secret_key FROM checkout_config
7.  POST https://app.amplopay.com/api/v1/gateway/pix/receive
    headers: { 'x-public-key', 'x-secret-key' }
    body: { customer, amount, externalId: order_id, postbackUrl: /api/payments/amplopay-webhook }
8.  Recebe { transactionId, pix: { qrCodeBase64, copyPaste, expiresAt } }
9.  UPDATE checkout_orders SET amplopay_transaction_id=$1, status='pending'
10. Response: { order_id, pix }

[Cliente]
11. Mostra QR Code + copia-cola
    Frontend faz polling: GET /api/checkout/status/[id] a cada 5-10s

[Cliente paga PIX no banco]
12. AmploPay → POST <PUBLIC_WEBHOOK_BASE_URL>/api/payments/amplopay-webhook
    body: { event: 'transaction.paid', token: <AMPLOPAY_WEBHOOK_TOKEN>, transactionId, externalId, ... }

[Backend — app/api/payments/amplopay-webhook/route.ts]
13. Valida token no body contra AMPLOPAY_WEBHOOK_TOKEN env
14. SELECT * FROM checkout_orders WHERE amplopay_external_id=$1 OR amplopay_transaction_id=$1
15. UPDATE checkout_orders SET status='paid'
16. INSERT INTO payments (workspace_id, amount_cents, source='amplopay', metadata, ...)
17. provisionSigmaCustomer({ workspaceId, planKey, phone, customerName })
    [lib/sigma/provision.ts findSigmaMapping → createOrRenewCustomer]
    → { username, password, expires_at, server, mapping }
18. Salva credenciais em payments.metadata + checkout_orders.metadata
    ⚠️ B-AMPLOPAY-001: NÃO salva em subscriptions.iptv_username/password
    INSERT/UPDATE subscriptions só com plan_name, plan_price_cents, billing_cycle, next_billing_at
19. pickEvolutionInstance + send WA com credenciais
    (mesma lógica tier híbrido B+A do F1)
20. Atualiza reseller (se ref): credita comissão em resellers.balance_cents + reseller_sales row
21. logAudit('payment.received', ...)
22. 200 OK pro AmploPay

[Cliente]
23. Polling pega status='paid' → mostra success page
24. Recebe WhatsApp com credenciais
```

---

## F3 — Mensagem WhatsApp recebida do cliente

```
[WhatsApp do cliente]
1.  Cliente envia msg pro número conectado em wp_evolution-api-2

[Evolution API]
2.  Detecta mensagem → POST <PUBLIC_WEBHOOK_BASE_URL>/api/webhook/<event>
    headers: Authorization: Bearer <EVOLUTION_API_KEY>
    body: payload Evolution (event: 'messages.upsert', instance, data, ...)

[Backend — app/api/webhook/route.ts]
3.  Valida token (header)
4.  Insere job na tabela jobs:
    INSERT INTO jobs (workspace_id, type='process_webhook', payload, status='pending')
5.  Retorna 200 imediatamente

[Worker — apps/worker/src/worker.ts]
6.  Loop: SELECT * FROM jobs WHERE status='pending' AND run_at<=NOW()
        FOR UPDATE SKIP LOCKED LIMIT 1
7.  UPDATE jobs SET status='running', locked_by=$hostname, locked_at=NOW()
8.  Executa handler 'process_webhook':
    a) Identifica instance pelo evolution_instance_id
    b) Identifica/cria contact (workspace_id + phone_e164)
    c) Identifica/cria conversation (workspace_id + contact_id + instance_id)
    d) INSERT messages (com direction='inbound', media via MinIO se aplicável)
    e) UPDATE conversations SET last_message, updated_at, unread_count++
    f) Avalia text_triggers, quick_trigger_config, automation_triggers
       Se match → INSERT job 'send_message' ou 'process_guided_funnel'
    g) Avalia ai_agents enabled em conversation_analysis (autopilot)
       Se ativo → INSERT job 'ai_response'
    h) Push SSE pra /api/sse/inbox (clientes web)
9.  UPDATE jobs SET status='succeeded'

[Frontend — /inbox]
10. SSE conecta em /api/sse/inbox
11. Recebe evento → SWR revalida /api/inbox/conversations
12. Mostra nova mensagem em tempo real
```

---

## F4 — Conversa nova chega ao inbox

```
1-9. Idem F3 (worker processa o webhook)

[Worker — INSERT da primeira mensagem]
10. Como conversation acabou de ser criada (passo 6c do F3),
    o worker dispara:
    a) text_triggers WHERE workspace_id AND match_type='greeting' OR é primeira msg
       → enviar mensagem de saudação + funnel inicial se configurado
    b) Se há quick_trigger_config(active=true, type='auto_greet')
       → INSERT job 'send_message'
    c) automation_triggers WHERE event='conversation_created'
       → INSERT job 'process_guided_funnel'
    d) Avalia agent_assignment_strategy em workspace_settings:
       - 'round_robin'        → busca próximo agent disponível
       - 'least_busy'         → conta open conversations por agent
       - 'unassigned'         → deixa sem dono pra agente pegar manual
       Se atribuído → INSERT conversation_transfers + UPDATE conversations.assigned_to

[Sistema de notificação interna]
11. Se conversation tem alerts (churn, payment_overdue, etc.)
    → INSERT churn_alerts ou inbox_alerts
    → Worker dispara push notification (notifications table)

[Frontend]
12. /inbox SSE → revalida → conversation aparece com badge "novo"
13. Agent designado vê notificação no top-bar
```

---

## F5 — Login com bloqueio por status

```
1.  POST /api/auth/[...nextauth] (provider 'credentials')
    body: { email, password, csrfToken }

[auth.ts authorize()]
2.  SELECT id, name, email, password, status FROM nextauth_users WHERE email=$1
3.  Se !user || !user.password → return null (login falha)
4.  Se status='pending'  → throw new Error('Conta pendente de aprovação')
5.  Se status='rejected' → throw new Error('Conta rejeitada')
6.  bcrypt.compare(password, user.password) → false → return null
7.  Sucesso → retorna { id, name, email }

[NextAuth jwt callback]
8.  Carrega name, nickname, phone_whatsapp, avatar_url do banco no token
9.  Set-Cookie __Secure-authjs.session-token (JWT)

[Middleware nas próximas requests]
10. Cookie presente + válido → request.auth.user.id setado → next()
```

---

## F6 — Reset de senha

```
[Usuário clica "Esqueci senha"]
1.  Page /esqueci-senha → form com email
    POST /api/auth/forgot-password { email }

[Backend]
2.  SELECT id FROM nextauth_users WHERE email=$1
    Se não existe → ainda retorna 200 (não revela existência)
3.  Gera token via crypto.randomUUID() + hash
    INSERT password_reset_tokens (user_id, token, expires_at=NOW()+1h, used=false)
4.  Envia email com link:
    https://app.sharkpanel.com.br/resetar-senha?token=<token>
    [via SMTP — config não detalhada nesta auditoria]

[Usuário clica link]
5.  Page /resetar-senha?token=X → form com nova senha + confirmação
    POST /api/auth/reset-password { token, newPassword }

[Backend]
6.  SELECT user_id FROM password_reset_tokens WHERE token=$1 AND used=false AND expires_at>NOW()
    → 400 se inválido/expirado
7.  Valida newPassword.length >= 6 (⚠️ política fraca, ver password-policy.md)
8.  bcrypt.hash(newPassword, 12)
9.  UPDATE nextauth_users SET password=$hash WHERE id=$user_id
10. UPDATE password_reset_tokens SET used=true WHERE token=$1
11. logAudit('user.password_reset')
12. Redirect → /login
```

---

## F7 — Cron `pix-followup` (PIX abandonado)

```
[supercronic, */30 * * * *]
1.  curl -H "x-cron-secret: $CRON_TOKEN" $URL/api/cron/pix-followup

[Backend — app/api/cron/pix-followup/route.ts]
2.  Valida x-cron-secret == CRON_TOKEN
3.  SELECT * FROM checkout_orders
     WHERE status='pending'
       AND created_at < NOW() - INTERVAL '15 min'
       AND created_at > NOW() - INTERVAL '24 hour'
       AND (pix_followup_last_at IS NULL OR pix_followup_last_at < NOW() - INTERVAL '4 hour')
       AND pix_followup_sent < 3
4.  Para cada order:
    a) Identifica instance pelo workspace + payment_confirmation
    b) Monta mensagem (workspace_settings/pix-custom-message)
    c) INSERT jobs (type='send_message', payload: { to, text, instance })
    d) UPDATE checkout_orders SET pix_followup_sent++, pix_followup_last_at=NOW()
5.  Worker pega o job, envia via Evolution
```

---

## F8 — Provisão Sigma (compartilhado por F1, F2 e iptv-trial)

```
[lib/sigma/provision.ts]

provisionSigmaByPackage({ serverId, packageId, customerName, phoneDigits, workspaceId })
  Usado por F1 (reseller-activate). Pula sigma_plan_mapping legado.
  1. SELECT sigma_servers WHERE id=$1 AND is_active
  2. findCustomer(server, phoneDigits)
     GET <panel>/webhook/customer?note=<phone>&token&userId
     → array | { customer } | null
  3. Se exists: renewCustomer(server, packageId, username)
     POST <panel>/webhook/renew
     body: { username, package: packageId, token, userId, note: phone }
  4. Se não: createCustomer(server, packageId, phone, customerName)
     POST <panel>/webhook/customer
     body: { name, note: phone, username: gerado, password: gerado,
             package: packageId, token, userId }
  5. Resposta da API Sigma vem com { username, password, expiresAt: 'DD/MM/YYYY HH:MM:SS' }
  6. parseSigmaDate(expiresAt) — converte BR → ISO   ⭐ fix de 29/04
  7. Retorna { username, password, expires_at, action, server, mapping }

provisionSigmaCustomer({ workspaceId, planKey, phone, customerName })
  Usado por F2 (amplopay-webhook). Lookup via sigma_plan_mapping.
  1. findSigmaMapping(workspaceId, planKey)
     a) SELECT sigma_servers WHERE workspace_id=$1 OR is_global=true ORDER BY own>global LIMIT 1
     b) lookupKey = ownServer ? planKey : baseKey(planKey)   # strip "-<8hex>"
     c) SELECT m.* FROM sigma_plan_mapping m JOIN checkout_plans p ON p.id=m.checkout_plan_id
         WHERE m.server_id=$1 AND p.key=$2 LIMIT 1
  2. (igual a provisionSigmaByPackage do passo 2 em diante, com mapping.sigma_package_id)
```

---

## F9 — Worker pega job

```
[Worker loop, cada N ms]
1.  BEGIN
2.  SELECT id, type, payload, attempts, max_attempts FROM jobs
     WHERE status='pending' AND run_at<=NOW()
     FOR UPDATE SKIP LOCKED LIMIT 1
3.  UPDATE jobs SET status='running', locked_by=$hostname, locked_at=NOW(),
                    attempts=attempts+1
                WHERE id=$1
4.  COMMIT (libera lock pra outros workers)
5.  Switch type:
    'send_message'           → POST Evolution /message/sendText
    'send_audio'             → POST Evolution /message/sendWhatsAppAudio
    'send_image'             → POST Evolution /message/sendMedia (image)
    'send_video'             → POST Evolution /message/sendMedia (video)
    'send_document'          → POST Evolution /message/sendMedia (document)
    'sync_instance'          → GET Evolution /instance/fetchInstances → atualiza whatsapp_instances
    'sync_contacts'          → GET Evolution /chat/findContacts/<instance>
    'process_webhook'        → idem F3 passo 8
    'ai_response'            → chama OpenAI/Claude com contexto da conversation
    'check_delivery'         → GET Evolution /chat/findStatusMessage → atualiza messages.status
    'process_guided_funnel'  → avança guided_funnel_sessions, dispara próximo step
    'send_followup_trial'    → envia trial-followup template
6.  Sucesso:
    UPDATE jobs SET status='succeeded', updated_at=NOW(), error=NULL WHERE id=$1
    INSERT worker_runs (job_id, type, status='succeeded', duration_ms, ...)
7.  Erro:
    Se attempts < max_attempts:
      next_retry_at = NOW() + exponential_backoff(attempts)
      UPDATE jobs SET status='pending', last_error, next_retry_at, run_at=next_retry_at
    Senão:
      UPDATE jobs SET status='dead', last_error
      INSERT worker_alert_logs (job_id, type, error)
```
