# 🦈 Deep Dive — Webchat + Recorrência

**Escopo:** widget de chat para websites (`/api/webchat/*`) e dashboard de recorrência/MRR (`/api/recorrencia/*`). Tabelas: `webchat_settings`, `webchat_sessions`, `webchat_blocked_ips`, `webchat_plans`, `subscriptions`, `subscription_payments`, `workspace_subscriptions`.

**TL;DR:**
- **Webchat funciona em produção:** 1 session ativa real (Luiz Carlos, IP 45.163...) — alguém usando o widget AGORA.
- 1 webchat_settings configurada (workspace `Uniflix`/`shark-panel`), 3 planos (Mensal R$17, Trimestral R$45, Anual R$120).
- **Recorrência (MRR/ARR/churn) é dashboard read-only** — gerado a partir de `subscriptions` (288 active). Não é "cobrança recorrente PIX" — é tracking de assinaturas pagas.
- 288 subscriptions todas em shark-panel, sources: amplopay (189), contacts_sync (61), payments_sync (35), credits (3).
- 3 workspace_subscriptions (cobrança da plataforma para os clientes Zapflix): R$397/mês plano "enterprise" para shark-panel, iphone, diario-das-bruxas.

---

## 1. Webchat — Schema

### 1.1 `webchat_settings`
```
id, workspace_id UNIQUE
business_hours (jsonb)
timezone default 'America/Sao_Paulo'
welcome_message default 'Olá! Sou a Mariana 👋 Como posso te ajudar?'
offline_message default 'Nosso atendimento é das 10h às 22h 🕘'
away_message default 'Em instantes um atendente irá te atender!'
agent_name default 'Mariana'
agent_avatar_url
primary_color default '#7c3aed'
position default 'right'
```

### 1.2 `webchat_sessions`
```
id, workspace_id
conversation_id (FK conversations)
contact_id (FK contacts)
session_token UNIQUE   -- random UUID gerado no /start
visitor_name, visitor_phone
ip_address (text)
status default 'active'
last_seen_at
pwa_installed (boolean)
```

### 1.3 `webchat_blocked_ips`
```
workspace_id, ip_address (text NOT NULL)
reason, blocked_by (uuid)
UNIQUE (workspace_id, ip_address)
```

### 1.4 `webchat_plans` — planos exibidos para checkout no widget
```
workspace_id, name, price_cents, duration_days
description, features (jsonb)
is_active, sort_order
```

---

## 2. Webchat — Estado em prod

```
webchat_settings:    1 (workspace_id=Uniflix '...0002', mas slug='shark-panel'?? — verificar)
webchat_sessions:    1 (status=active, visitor=Luiz Carlos Ribeiro, IP 45.163.113.44)
webchat_blocked_ips: 0
webchat_plans:       3
  Mensal     R$  17,00 (30 days)
  Trimestral R$  45,00 (90 days)
  Anual      R$ 120,00 (365 days)
```

⚠️ **Inconsistência:** webchat_settings tem `workspace_id='00000000-0000-0000-0000-000000000002'` (Uniflix), mas o JOIN com `workspaces` mostra slug=`shark-panel`. Investigar — pode ser que o workspace_id da Uniflix foi reassociado.

---

## 3. Webchat — Endpoints (8 rotas)

| Rota | Linhas | Função |
|------|--------|--------|
| `POST /api/webchat/start` | 180 | **Inicia sessão**: cria contact + conversation (channel='webchat') + session_token |
| `POST /api/webchat/message` | 341 | Envia mensagem (text + media base64 ou URL); upload S3 |
| `GET /api/webchat/messages` | 95 | Lista mensagens da sessão (polling/SSE) |
| `GET /api/webchat/config` | 160 | Carrega settings + plans + agent info |
| `GET /api/webchat/settings` | 139 | Settings CRUD (admin) |
| `GET /api/webchat/plans` | 79 | List plans |
| `POST /api/webchat/checkout` | 309 | Inicia checkout PIX para um plano |
| `POST /api/webchat/block-ip` | 87 | Bloqueia IP (admin) |

**TODOS suportam CORS** (`OPTIONS` + headers `Access-Control-Allow-Origin: *`) — necessário pois o widget roda no site cliente, não no domínio Zapflix.

### 3.1 `/api/webchat/start` (180 linhas)

```
Body: { workspace_id?, name, phone, initial_message }

1. Resolve workspace:
   - Por UUID (rawWorkspace é UUID válido)
   - Por slug
   - Fallback: env WEBCHAT_DEFAULT_WORKSPACE_SLUG ou 'uniflix'
2. Check IP em webchat_blocked_ips → bloqueia se bate
3. UPSERT contact (workspace_id, phone, name)
4. Cria conversation (channel='webchat', instance_id=NULL, contact_id)
5. Gera session_token (UUID v4)
6. INSERT webchat_sessions
7. INSERT primeira message (direction='in', from contact)
```

**Sem autenticação** (público) — protegido só por IP block + rate limit (Next.js default).

### 3.2 `/api/webchat/message` (341 linhas)

Suporta:
- `text`: mensagem texto.
- `media_url`: URL externa já hospedada.
- `base64`: data URL `data:image/jpeg;base64,...` → upload para S3 (MinIO).
- Atributos: `mime`, `filename`.

Upload S3 com client `@aws-sdk/client-s3`, bucket `S3_BUCKET` env. Key path: `webchat/<timestamp>-<random>.<ext>`.

### 3.3 `/api/webchat/checkout` (309 linhas)

Cria `payment_intent` PIX para um `webchat_plans.id`. Integração com AmploPay. Se confirmado:
- INSERT em `payments` (status=confirmed)
- Trigger UPDATE `contacts.plan_expires_at`
- (Posteriormente) cron `recorrencia/sync` cria `subscriptions` row.

---

## 4. Webchat Widget (frontend cliente)

**Não está no repo principal.** Provavelmente:
- Hospedado em `shark-landing` ou injetado via `<script src="...widget.js">`.
- Faz fetch para `/api/webchat/*` com CORS.
- UI: "agent name" (Mariana), "primary color", "position" (right/left).

`app/(dashboard)/webchat-settings/` é o painel admin (não confirmei conteúdo).

`app/(dashboard)/webchat-docs/` provavelmente documentação para integração.

---

## 5. Webchat — Fluxo E2E

```
Cliente abre site → widget aparece
1. Click "Start chat"
2. Form: nome + telefone + mensagem inicial
3. Frontend: POST /api/webchat/start
4. Server cria contact + conversation + session
5. Retorna session_token ao widget
6. Widget guarda session_token no localStorage
7. Widget faz polling (5s?) GET /api/webchat/messages?session_token=...
8. Operador no painel Zapflix vê conversa em /inbox como qualquer outra
9. Operador responde → message persistida → widget vê na próxima poll
10. Cliente quer assinar → POST /api/webchat/checkout {plan_id}
11. Server cria PIX → retorna QR/link
12. Após pagamento → webhook AmploPay → confirma
```

---

## 6. Recorrência — Schema

### 6.1 `subscriptions` (288 rows em shark-panel)
```
workspace_id, contact_id (FK)
plan_name, plan_price_cents
billing_cycle default 'monthly'   -- monthly|yearly|quarterly|semiannual|lifetime
status default 'active'
started_at, next_billing_at, cancelled_at, churned_at
source                              -- manual|amplopay|contacts_sync|payments_sync|credits
payment_id (uuid)
iptv_username, iptv_password, iptv_server, iptv_app, iptv_expires_at
notes
```

### 6.2 `subscription_payments` (199 rows)
```
subscription_id (FK CASCADE)
amount_cents, status default 'pending'
paid_at, payment_id (FK payments SET NULL)
```

### 6.3 `workspace_subscriptions` (3 rows)
```
workspace_id UNIQUE
plan default 'reseller'
amount_cents default 19700 (R$197)
status default 'active'
current_period_start (date), current_period_end (date, default +30d)
```

**Esta é a cobrança da PLATAFORMA Zapflix dos seus clientes** — não a cobrança que cada cliente faz dos seus end-users.

---

## 7. Recorrência — Estado em prod

### 7.1 Subscriptions (assinaturas dos clientes finais)
```
288 rows | TODAS em shark-panel
```

Por source:
| source | count |
|--------|-------|
| amplopay | 189 |
| contacts_sync | 61 |
| payments_sync | 35 |
| credits | 3 |

`contacts_sync` e `payments_sync` foram criados pelo cron `recorrencia/sync` que reconcilia contatos com `plan_expires_at` em `subscriptions`.

### 7.2 Workspace_subscriptions (cobrança da plataforma)
```
shark-panel       | enterprise | R$ 397,00/mês | active | até 2026-04-29
iphone            | enterprise | R$ 397,00/mês | active | até 2026-05-02
diario-das-bruxas | enterprise | R$ 397,00/mês | active | até 2026-05-23
```

**Hoje é 2026-04-29**: shark-panel está vencendo HOJE.

---

## 8. Recorrência — Endpoints (5 rotas)

| Rota | Linhas | Função |
|------|--------|--------|
| `GET /api/recorrencia/dashboard` | 270 | KPIs: MRR, ARR, ARPU, churn rate, active_count |
| `GET /api/recorrencia/calendar` | 142 | Próximos vencimentos (calendar view) |
| `GET /api/recorrencia/history` | 78 | Histórico de pagamentos |
| `GET/POST /api/recorrencia/subscriptions` | 156 | List/create |
| `GET/PATCH/DELETE /api/recorrencia/subscriptions/[id]` | n/a | CRUD |
| `POST /api/recorrencia/sync` | 172 | **Reconciliation:** cria subscriptions a partir de contacts/payments |

### 8.1 `/api/recorrencia/dashboard` — cálculo de MRR

```sql
WITH active AS (
  SELECT plan_price_cents, billing_cycle
  FROM subscriptions WHERE workspace_id=$1 AND status='active'
),
month_factor AS (
  SELECT plan_price_cents,
    CASE billing_cycle
      WHEN 'yearly' THEN plan_price_cents / 12.0
      WHEN 'quarterly' THEN plan_price_cents / 3.0
      WHEN 'semiannual' THEN plan_price_cents / 6.0
      WHEN 'lifetime' THEN 0
      ELSE plan_price_cents
    END AS monthly_cents
  FROM active
)
SELECT SUM(monthly_cents) AS mrr_cents,
       COUNT(*) AS active_count,
       AVG(monthly_cents) AS arpu_cents
FROM month_factor;
```

Calcula:
- **MRR** (Monthly Recurring Revenue): soma normalizada para mensal.
- **ARR**: MRR × 12.
- **ARPU**: avg per user.
- **Churn rate** (período selecionado): `cancelled / (start_count + new)`.

### 8.2 `/api/recorrencia/sync`

Roda manualmente (não é cron, é endpoint disparado pela UI):
1. Para cada `contacts.plan_expires_at IS NOT NULL` sem subscription:
   - Pega último payment confirmado (3 dias).
   - Sanitiza description (remove `RefXXX`, `SellerXXX`, troca "Zapflix" pela brand_name).
   - Detecta billing_cycle por price/keyword.
   - INSERT subscriptions com source='contacts_sync' ou 'payments_sync'.

Padrões de detecção:
```
'%vital%' OR '%lifetime%' OR amount >= R$110: lifetime
'%anual%' OR '%annual%': yearly
'%semest%': semiannual
'%trimestr%': quarterly
'%avulso%' OR amount entre R$40-109: yearly (avulso = "vendido sem renovação")
default: monthly
```

---

## 9. UI

`app/(dashboard)/recorrencia/page.tsx` (129 linhas) — orquestra 4 sub-componentes:
- `components/recorrencia/dashboard.tsx` — KPIs
- `components/recorrencia/subscribers.tsx` — lista
- `components/recorrencia/calendar.tsx` — vencimentos por dia
- `components/recorrencia/history.tsx` — pagamentos

`app/(dashboard)/webchat-settings/` — admin de webchat_settings + webchat_plans.

---

## 10. Diferença: subscriptions IPTV vs recorrência PIX

A confusão original era: "recorrência é cobrança recorrente PIX?".

**Resposta:** NÃO.

- `subscriptions` = registro contábil/CRM de "este cliente está num plano". Pagamento real é one-shot (PIX, cartão), com `next_billing_at` tracking de quando pedir nova cobrança.
- A "cobrança recorrente" real é feita por **AmploPay** (gateway externo) com webhooks que populam `payments` e disparam o sync.
- Não há cron interno que dispara cobrança PIX recorrente — depende do gateway.

```
contact paga PIX via AmploPay
  ↓ webhook
INSERT payments (status=confirmed)
  ↓ trigger ou cron sync
INSERT subscriptions OU UPDATE existing subscription.next_billing_at
  ↓ trigger ou contact_update
UPDATE contacts.plan_expires_at
```

---

## 11. Bugs / débitos

### 11.1 BUG: webchat_settings.workspace_id aponta para Uniflix mas slug retorna shark-panel
Investigar via:
```sql
SELECT s.workspace_id, w.id, w.slug, w.name 
FROM webchat_settings s LEFT JOIN workspaces w ON w.id=s.workspace_id;
```

Se inconsistente, é dump corrupto ou rename de workspace que não foi propagado.

### 11.2 🔴 BUG potencial: workspace_subscriptions de shark-panel vence HOJE (2026-04-29)
`current_period_end = 2026-04-29`. Sem cron de cobrança automática (verificar). Cliente pode perder acesso amanhã se não houver renovação manual.

### 11.3 BUG: 0 IPs bloqueados mas widget é público (DDoS risk)
`webchat_blocked_ips: 0`. Sem rate limit explícito no `/start`, atacante pode criar milhões de sessions. Necessário rate limit por IP.

### 11.4 BUG: `webchat_sessions` sem cleanup
1 session active hoje, mas tabela cresce indefinidamente. Sem retenção, sem `last_seen_at < N days → archive`.

### 11.5 BUG: webchat permite phone sem validação E.164
`normalizePhone` só remove caracteres não-numéricos. Aceita "0" ou "12345" como phone válido. Pode poluir contacts.

### 11.6 BUG: `subscriptions.iptv_password` em texto puro
Como ai_provider_settings, sem criptografia. Dump = vazamento massivo.

### 11.7 INCONSISTÊNCIA: 3 caminhos para subscription
- AmploPay webhook → direct INSERT
- payments_sync via cron/manual sync
- contacts_sync via plan_expires_at lookup

Cada um tem regras diferentes de detecção (billing_cycle, plan_name). Pode gerar duplicatas se source mudar.

### 11.8 BUG: `subscription_payments.subscription_id` pode ser NULL
Schema permite NULL — pagamento sem subscription ligada. Provavelmente legacy, mas dificulta agregações.

### 11.9 BUG: workspace_subscriptions sem trigger de cobrança
3 rows com `current_period_end` próximo, mas não há cron `workspace-billing` que extenda período após cobrança. Renovação 100% manual.

### 11.10 BUG: webchat workspace fallback usa env `WEBCHAT_DEFAULT_WORKSPACE_SLUG`
Se env não configurada, usa 'uniflix' hardcoded. Se workspace 'uniflix' não existe, throw 'workspace_not_found'. **Configurar env em prod.**

---

## 12. Custos

### Storage
- webchat_sessions, webchat_settings, webchat_plans: <50 kB.
- subscriptions: 288 × ~500B ≈ 150 kB.
- subscription_payments: 199 × ~200B ≈ 40 kB.

**Total: <300 kB.**

### CPU
- /webchat/start: 1 transaction, ~50ms.
- /webchat/message: depende de S3 upload (~100-500ms).
- /webchat/messages polling (5s): pequeno SELECT, negligenciável.
- /recorrencia/dashboard: queries pesadas com CASE/SUM, mas sob 100ms.

### Tokens IA
- Webchat NÃO usa IA por default. Mas pode acionar guided_funnel (channel='webchat') que executa `search_knowledge` ou AI agent.

**Custo total: <$2/mês.**

---

## 13. Resumo executivo

1. **Webchat funciona em prod:** 1 visitante REAL ativo agora (Luiz Carlos). 3 planos configurados. Widget injetado em algum site cliente — **não está documentado onde**.
2. **MRR/ARR dashboard implementado:** cálculos corretos com normalização por billing_cycle. Useful para o dono.
3. **Recorrência ≠ PIX recorrente:** dashboard de assinaturas com sync de payments. AmploPay faz a cobrança real.
4. **🔴 workspace_subscriptions de shark-panel vence HOJE.** Verificar processo de renovação.
5. **288 subscriptions em shark-panel** — feature de tracking funciona, sources múltiplos consolidados.
6. **Riscos de segurança:** webchat sem rate limit, IPs sem cleanup, senhas iptv em texto puro.
7. **Outros workspaces (Uniflix, etc) não usam recorrência** — só shark-panel popula subscriptions.
