# 05 — Fluxos Principais

> Os 5 fluxos mais importantes do SharkPanel / Zapflix-Tech  
> Atualizado: 2026-05-20

---

## Fluxo 1 — Onboarding de nova workspace

```
Usuário acessa /registro
  │
  ▼
POST /api/auth/signup
  ├── Cria nextauth_users com status='pending'
  └── Retorna "aguardando aprovação"
  │
  ▼
Admin (Master Panel) aprova em /api/admin/pending-users
  ├── UPDATE nextauth_users SET status='active'
  └── (Opcional) Define plano inicial em workspace_plans
  │
  ▼
Usuário faz login → POST /api/auth/signin (NextAuth)
  ├── SELECT email + bcrypt compare
  ├── Gera JWT com workspace_id, role, name
  └── Cookie httpOnly
  │
  ▼
Middleware.ts verifica JWT em todas as rotas protegidas
  │
  ▼
/onboarding → POST /api/workspace/configure-niche
  ├── Configura business_type (iptv/infoproduto/servicos)
  └── Define preset de features ativas
  │
  ▼
Criação de instância WhatsApp
  POST /api/instances
  ├── checkInstanceLimit (verifica plano)
  ├── INSERT whatsapp_instances
  └── Registra na Evolution API
  │
  ▼
Conectar WhatsApp
  POST /api/instances/[id]/connect
  ├── Solicita QR Code da Evolution API
  └── Retorna QR para o frontend exibir
  │
  ▼
Evolution API notifica via webhook quando conectado
  POST /api/webhook/connection
  └── UPDATE whatsapp_instances SET status='connected'
  │
  ▼
Workspace operacional ✅
```

**Páginas:** `app/registro/page.tsx` → `app/(dashboard)/dashboard/page.tsx` → `whatsapp-instances/page.tsx`  
**Arquivos chave:** `app/api/auth/signup/route.ts`, `auth.ts`, `middleware.ts`, `app/api/instances/route.ts`

---

## Fluxo 2 — Venda IPTV (geração e ativação de trial)

```
Atendente recebe mensagem no Inbox
  │
  ▼
Atendente abre conversa → GET /api/inbox/conversations
  ├── Identifica contato interessado em IPTV
  └── Verifica plano atual do contato: GET /api/contacts/[id]/plan
  │
  ▼
Atendente gera trial
  POST /api/iptv/generate-and-send
  ├── Seleciona servidor (sigma_servers / iptv_servers)
  ├── Gera usuário/senha no servidor IPTV via bot
  ├── INSERT iptv_generated_tests
  ├── INSERT iptv_trials (status='active', expires_at=NOW()+Xhoras)
  ├── sold_by_user_id = atendente logado
  └── Envia credenciais via WhatsApp (POST /api/inbox/conversations/[id]/send)
  │
  ▼
Worker processa job 'send_message'
  ├── Envia mensagem na Evolution API
  └── UPDATE messages SET status='sent'/'delivered'/'read'
  │
  ▼
Cliente experimenta por X horas/dias
  │
  ├─── NÃO converteu → cron trial-followup
  │    └── /api/cron/trial-followup
  │         └── Dispara automação de follow-up configurada
  │
  └─── Converteu → Atendente ativa plano
       POST /api/iptv/trials/[id]/activate
       ├── UPDATE iptv_trials SET status='converted'
       ├── POST /api/payments/register (pagamento manual) ou
       │   POST /api/iptv/payments (PIX via Amplo Pay)
       ├── Calcula comissão → INSERT agent_commissions
       └── Notifica gamificação → UPDATE agent_xp_log
```

**Páginas:** `app/(dashboard)/inbox/page.tsx`, `trials/page.tsx`  
**Arquivos chave:** `app/api/iptv/generate-and-send/route.ts`, `app/api/iptv/trials/[id]/activate/route.ts`, `app/api/iptv/payments/route.ts`  
**⚠️ Bug ativo:** `app/api/iptv/payments/route.ts:100` — se `sold_by_user_id` for null, comissão vai ao admin logado (Bug #6)

---

## Fluxo 3 — Automação (funil guiado disparado por trigger)

```
Trigger configurado (ex: palavra-chave "quero saber")
  │
  ▼
Evolution API recebe mensagem do cliente
  │ webhook
  ▼
POST /api/webhook (Evolution)
  └── INSERT jobs (type='process_webhook', payload={instanceId, message})
  │
  ▼
Worker (apps/worker/src/worker.ts)
  Polling: SELECT * FROM jobs WHERE status='pending' FOR UPDATE SKIP LOCKED
  │
  ▼
Handler: webhook (apps/worker/src/handlers/webhook.ts)
  ├── Upsert conversation + message
  ├── Verificar triggers ativos → automation_triggers
  │   ├── Match? → INSERT jobs (type='process_guided_funnel')
  │   └── No match → verificar AI agent
  │
  ▼
Handler: process_guided_funnel
  ├── SELECT guided_funnel + guided_funnel_steps ORDER BY position
  ├── INSERT automation_flow_sessions (estado da sessão)
  └── Para cada step:
      ├── Tipo 'send_message' → INSERT jobs (send_message)
      ├── Tipo 'wait' → UPDATE session SET run_at=NOW()+delay
      ├── Tipo 'condition' → avaliar condição, escolher branch
      └── Tipo 'tag' → INSERT contact_tag_assignments
  │
  ▼
Handler: send_message
  ├── POST Evolution API /message/sendText (ou sendMedia)
  ├── UPDATE messages SET status='sent'
  └── INSERT audit_logs
  │
  ▼
INSERT automation_logs (resultado de cada execução)
```

**Páginas:** `app/(dashboard)/guided-funnels/page.tsx`, `automacoes/page.tsx`  
**Arquivos chave:** `apps/worker/src/handlers/webhook.ts`, `apps/worker/src/handlers/funnel.ts`, `app/api/automations/triggers/route.ts`

---

## Fluxo 4 — Comissão de revendedor

```
Revendedor cadastrado: /api/resellers/register
  ├── INSERT resellers
  └── Vincula workspace_id do revendedor
  │
  ▼
Venda acontece (IPTV ou checkout)
  │
  ▼
Em /api/iptv/payments ou /api/payments/amplopay-webhook:
  ├── Identifica reseller_id do contato: contacts.reseller_id
  ├── Calcula comissão (% configurado)
  └── INSERT reseller_sales (workspace_id, reseller_id, amount, commission_amount)
  │
  ▼
Cron mensal: /api/cron/monthly-payroll
  ├── Agrega reseller_sales do período
  ├── INSERT reseller_ledger (saldo acumulado)
  └── Notifica revendedor via WhatsApp
  │
  ▼
Revendedor solicita saque: POST /api/resellers/withdraw
  ├── INSERT reseller_withdrawals (status='pending')
  └── Notifica admin
  │
  ▼
Admin aprova: PATCH /api/admin/resellers/withdrawals/[id]
  ├── UPDATE reseller_withdrawals SET status='approved'
  ├── INSERT reseller_ledger (débito)
  └── Registra pagamento realizado
  │
  ▼
Revendedor acompanha em /reseller/creditos
```

**Páginas:** `app/(dashboard)/reseller/`, `reseller/clientes/`, `reseller/creditos/`  
**Arquivos chave:** `app/api/resellers/withdraw/route.ts`, `app/api/admin/resellers/withdrawals/route.ts`, `app/api/cron/monthly-payroll/route.ts`  
**⚠️ Fluxo parcialmente incompleto** — withdraw UI existe mas fluxo de aprovação pode ter gaps

---

## Fluxo 5 — Checkout PIX (venda de produto via link público)

```
Usuário configura produto: /checkout/produtos/novo
  ├── INSERT checkout_products
  ├── Define preço, imagem, descrição
  └── Ativa página pública: /p/[product_slug]
  │
  ▼
Cliente acessa link público: /p/[product_slug]
  ├── GET /api/checkout/products/[id] (dados do produto)
  └── Formulário de dados do cliente
  │
  ▼
Cliente clica "Comprar": POST /api/checkout/products/[id]/checkout
  ├── INSERT checkout_orders (status='pending')
  ├── POST Amplo Pay API /gateway/pix/receive
  │   ├── Retorna QR Code + código copia-e-cola
  │   └── UPDATE checkout_orders SET amplopay_external_id=...
  └── Redireciona para /pix/[id]
  │
  ▼
Cliente paga o PIX
  │
  ▼
Amplo Pay dispara webhook: POST /api/payments/amplopay-webhook
  ├── Verifica PAYMENT_WEBHOOK_SECRET
  ├── Busca checkout_orders por amplopay_external_id
  ├── UPDATE checkout_orders SET status='paid'
  ├── INSERT payments (registro financeiro)
  ├── Dispara automação de pós-venda (se configurada)
  │   └── INSERT jobs (process_guided_funnel)
  ├── Calcula comissão de revendedor (se aplicável)
  └── Notifica workspace via sino no app (SSE)
  │
  ▼
Cliente vê página /p/[slug]/obrigado
Atendente vê pagamento em /dashboard e /financeiro
```

**Páginas:** `app/(dashboard)/checkout/produtos/`, `app/p/[product_slug]/page.tsx`, `app/pix/[id]/page.tsx`  
**Arquivos chave:** `app/api/checkout/products/[id]/checkout/route.ts`, `app/api/payments/amplopay-webhook/route.ts`  
**⚠️ Bug ativo:** Se `amplopay_external_id` não encontrar pedido, pagamento vai ao primeiro workspace (Bug #1)  
**⚠️ Dupla rota:** `/api/payments/webhook` legado ainda ativo — risco de double-processing (Bug #13)

---

## Fluxo Bônus — Mensagem recebida com Agente IA (modo autonomous)

```
Mensagem do cliente chega via Evolution API webhook
  │
  ▼
Worker: handler/webhook.ts
  ├── Verifica se conversa tem ai_mode='autonomous'
  ├── Verifica se workspace tem agente IA configurado
  └── INSERT jobs (type='ai_response')
  │
  ▼
Worker: handler/ai.ts
  ├── Busca ai_agents WHERE workspace_id + instance_id matching
  ├── Monta contexto: system_prompt + histórico de mensagens
  ├── Busca knowledge_chunks relevantes (RAG — se pgvector OK)
  ├── POST LLM API (Claude/OpenAI) com contexto
  ├── Recebe resposta
  └── INSERT jobs (send_message, payload={text=resposta})
  │
  ▼
Worker: handler/send_message → Evolution API → WhatsApp do cliente
  │
  ▼
INSERT ai_agent_logs (input, output, tokens, model)
```

**⚠️ RAG bloqueado** pelo Bug #14 (pgvector). Agente funciona, mas sem base de conhecimento vetorial.  
**Arquivos chave:** `apps/worker/src/handlers/ai.ts`, `lib/chatbot/engine.ts`, `app/api/ai/agent-chat/route.ts`

---

## Mapa de dependências entre fluxos

```
Onboarding → WhatsApp conectado
     │
     └──► Inbox operacional
               │
     ┌─────────┼─────────────┐
     │         │             │
  Venda IPTV  Automação   Checkout PIX
     │         │             │
     └─────────┼─────────────┘
               │
          Comissões (Revendedor / Gamificação)
               │
          Relatórios / Analytics / Sales Brain
```

---

*Veja também: [[00-visao-geral]] | [[01-modulos]] | [[02-api-routes]] | [[03-banco-de-dados]] | [[04-pendencias]]*
