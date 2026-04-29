# Mapa de Rotas — Shark Panel

> Frontend (Next.js App Router) + Backend (`/api/*`).
> Auditoria de leitura em 2026-04-29.

---

## Frontend

Total de **92 páginas** (`page.tsx`). Quatro grupos:

```
app/page.tsx                    # Landing/redirect
app/(dashboard)/...             # 60+ páginas autenticadas
app/(master)/...                # 16 páginas /master/* (superadmin)
app/(public)/...                # afiliado/cadastro, esqueci-senha, etc.
app/login, /master-login, /registro, /comprar, /pix/[id], /registro-revendedor
```

### Páginas públicas (sem login)

| URL | Página | Função |
|---|---|---|
| `/` | `app/page.tsx` | Landing → redirect (autenticado vai pra `/dashboard`, anônimo vai pra `/login`) |
| `/login` | `app/login/page.tsx` | Login — workspace user |
| `/master-login` | `app/master-login/page.tsx` | Login — superadmin (host `admin.sharkpanel.com.br`) |
| `/registro` | `app/registro/page.tsx` | Cadastro de usuário |
| `/registro-revendedor` | `app/registro-revendedor/page.tsx` | Cadastro de revendedor (alternativa) |
| `/cadastro-revendedor` | `app/(public)/cadastro-revendedor/page.tsx` | Cadastro reseller (landing) |
| `/afiliado/cadastro` | `app/(public)/afiliado/cadastro/page.tsx` | Cadastro de afiliado |
| `/afiliado/cadastro/sucesso` | `…/sucesso/page.tsx` | Confirmação |
| `/esqueci-senha` | `app/(public)/esqueci-senha/page.tsx` | Esqueci senha |
| `/resetar-senha` | `app/(public)/resetar-senha/page.tsx` | Reset com token |
| `/comprar` | `app/comprar/page.tsx` | Checkout PIX (público com `?ref=<code>`) |
| `/pix/[id]` | `app/pix/[id]/page.tsx` | Página de PIX (QR + copia-cola) |

### Páginas autenticadas — Atendimento

| URL | Quem | Função |
|---|---|---|
| `/` (dashboard) | todos | Dashboard inicial |
| `/inbox` | todos | Inbox de conversas WA/webchat |
| `/contacts` | todos | Lista de contatos |
| `/contacts/monthly` | owner/admin | Contatos com plano mensal |
| `/tickets` | todos | Tickets internos |
| `/blacklist` | owner/admin | Blacklist de números |

### Páginas autenticadas — Canais / Vendas / IPTV

| URL | Quem |
|---|---|
| `/whatsapp-instances` | owner/admin |
| `/webchat-settings` | owner/admin |
| `/webchat-docs` | owner/admin |
| `/netflix-store` | owner/admin |
| `/products` | owner/admin |
| `/coupons` | owner/admin |
| `/pedidos` | owner/admin |
| `/recorrencia` | owner/admin |
| `/billing` | owner/admin |
| `/cobranca-rapida` | owner/admin |
| `/financeiro` | owner/admin |
| `/store` | owner/admin |
| `/store-config` | owner/admin |
| `/trials` | owner/admin |
| `/iptv-apps` | owner/admin |
| `/iptv-plans` | owner/admin |
| `/sigma` | superadmin |

### Páginas autenticadas — Automação / IA

| URL | Quem |
|---|---|
| `/automations` | owner/admin |
| `/automations/follow-up` | owner/admin |
| `/guided-funnels` | owner/admin |
| `/guided-funnels/[id]` | owner/admin |
| `/templates` | owner/admin |
| `/agendamentos` | owner/admin |
| `/groups` | owner/admin |
| `/campaigns` | owner/admin |
| `/ai` | owner/admin |
| `/ai-studio` | owner/admin |
| `/ai-assistant` | owner/admin |
| `/sales-brain` | owner/admin |
| `/knowledge` | owner/admin |
| `/alerts` | owner/admin |

### Páginas autenticadas — Analytics / Equipe

| URL | Quem |
|---|---|
| `/analytics` | owner/admin |
| `/analytics/instances` | owner/admin |
| `/metrics` | owner/admin |
| `/metrics/reports` | owner/admin |
| `/monitoring` | owner/admin |
| `/audit-log` | owner/admin |
| `/audit-logs` | owner/admin (alias) |
| `/jobs` | owner/admin |
| `/users` | owner/admin |
| `/team/[userId]` | owner/admin |
| `/gamification` | todos (owner/admin veem performance da equipe; agent vê a sua) |

### Páginas autenticadas — Reseller

| URL | Quem | Notas |
|---|---|---|
| `/reseller` | reseller | Painel principal |
| `/reseller-dashboard` | reseller | Dashboard alternativo (legado?) |
| `/reseller/creditos` | reseller | Compra de créditos via PIX |
| **`/reseller/clientes`** ⭐ | reseller | **NOVO Fase 2.2** — ativar cliente IPTV via crédito |
| `/resellers` | owner/admin | Meus revendedores (donos de workspace gerenciam) |
| `/redemptions` | owner/admin | Resgates da loja |

### Páginas autenticadas — Configurações / Conta

| URL | Quem |
|---|---|
| `/profile` | todos |
| `/configuracoes/senha` | todos |
| `/settings` | owner/admin |
| `/meu-plano` | owner |
| `/meu-setup` | owner/admin/agent |
| `/upgrade` | owner |
| `/help` | todos |
| `/api-tokens` | owner/admin |
| `/webhooks` | owner/admin |
| `/checkout-admin` | owner/admin |
| `/workspaces-map` | superadmin |

### Páginas Master (`/master/*`, superadmin only)

| URL |
|---|
| `/master` |
| `/master/workspaces` |
| `/master/workspace/[id]` |
| `/master/pessoas` |
| `/master/revendedores` |
| `/master/financeiro` |
| `/master/planos` |
| `/master/monitoramento` |
| `/master/tickets` |
| `/master/trials` |
| `/master/jobs` |
| `/master/blacklist` |
| `/master/ai-agents` |
| `/master/ai-agents/[id]` |
| `/master/audit` |
| `/master/configuracoes` |

---

## Backend (APIs)

Total de **595 routes** em `/root/Zapflix-Tech/app/api/`. Agrupadas por domínio.

### Auth & Users (`/api/auth/*`)
- `POST /api/auth/[...nextauth]` — handlers NextAuth (signin, signout, callback, session)
- `POST /api/auth/signup` — registro com `bcrypt.hash(password, 12)`
- `GET /api/auth/check-status` — status de aprovação do usuário
- `POST /api/auth/logout`
- `POST /api/auth/forgot-password` — gera `password_reset_tokens`
- `POST /api/auth/reset-password` — consome token
- `POST /api/auth/change-password` — autenticado, valida senha atual
- `POST /api/auth/callback` — bridge

### Reseller (`/api/resellers/*`, `/api/reseller/*`)
- `POST /api/resellers/register` — cadastro autenticado
- `POST /api/resellers/public-signup` — cadastro público (landing)
- `GET /api/resellers/lookup?ref=<code>` — público, valida referral
- `GET /api/resellers/me` — dados do reseller atual
- `GET /api/resellers/list` — owner/admin
- `GET /api/resellers/clients` — clientes ativados pelo reseller
- **`POST /api/resellers/clients/activate`** ⭐ — Fase 2.2: TX atômica (lock saldo → Sigma → debit + ledger → subscription → WA send → audit)
- `GET /api/resellers/credits/balance`
- `GET /api/resellers/credits/ledger`
- `POST /api/resellers/credits/purchase` — gera PIX via AmploPay
- `POST /api/resellers/withdraw` — saque de comissão
- `GET /api/resellers/my-sales`
- `GET /api/reseller/dashboard`

### Sigma / IPTV (`/api/iptv/*`, `/api/sigma/*`)
- `GET /api/iptv/servers` — lista servers do workspace + globais
- `GET /api/iptv/servers-with-bots`
- `GET /api/iptv/bots`
- `GET /api/iptv/app-configs`
- `POST /api/iptv/sigma-activate` — ativa cliente Sigma direto (legacy?)
- `GET/POST /api/iptv/trials` — listar / criar trial
- `POST /api/iptv/trials/[id]/activate` — converter trial em assinatura
- `POST /api/iptv/trials/[id]/temporary` — extender trial
- `GET /api/iptv/trials/analytics`
- `GET /api/iptv/trials/stats`
- `POST /api/iptv/generate-and-send` — cria trial + envia mensagem
- `POST /api/iptv/link-username`, `/verify`, `/unlink-username`
- `GET /api/iptv/extra-screen`
- `GET /api/iptv/favorites`
- `GET /api/iptv/message-templates`
- `GET /api/iptv/payments`
- `GET/POST /api/sigma/servers`, `/api/sigma/servers/[id]`, `/api/sigma/servers/[id]/mappings`
- `GET /api/sigma/mappings/[id]`

### Payments (`/api/payments/*`, `/api/checkout/*`)
- `POST /api/payments/amplopay-webhook` — **webhook principal** (autenticado por token JSON)
- `POST /api/payments/webhook` — webhook secundário (legado, autenticado por `PAYMENT_WEBHOOK_SECRET`)
- `POST /api/payments/register` — registra pagamento manual
- `POST /api/payments/send-receipt`
- `GET /api/payments/stats`, `/hourly`
- `GET /api/checkout/config`
- `GET /api/checkout/plans`
- `POST /api/checkout/create-pix` — cria order + pede PIX na AmploPay
- `GET /api/checkout/status/[id]` — polling
- `POST /api/checkout/orders/[id]/cancel`
- `GET/POST /api/checkout-admin/{config,plans,plans/[id],orders,orders/[id],orders/manual}` — admin do checkout
- `GET /api/pix/checkout-plans`, `/api/pix/plans`
- `GET /api/pix-page` — render da página `/pix/[id]`

### WhatsApp / Evolution (`/api/whatsapp/*`, `/api/instances/*`)
- `GET /api/instances` — lista instâncias do workspace
- `GET /api/instances/[id]` — detalhes
- `POST /api/instances/[id]/connect` — gera QR
- `GET /api/instances/[id]/health`
- `POST /api/instances/[id]/pause`, `/resume`
- `POST /api/instances/[id]/sync`, `/sync-contacts`, `/sync-profile`
- `GET /api/instances/[id]/import-history`
- `POST /api/instances/[id]/payment-confirmation` — flagar como instance dedicada
- `POST /api/instances/[id]/test-send`
- `GET /api/instances/[id]/webhook` — config webhook
- `POST /api/instances/[id]/tag-color`
- `GET /api/instances/health`
- `GET /api/instances/status`
- `POST /api/instances/sync-evolution`
- `POST /api/whatsapp/instances/[id]/logout`, `/reconnect`
- `POST /api/webhook` — recebe webhook Evolution (`/api/webhook/...`)
- `POST /api/webhook/connection`

### Inbox (`/api/inbox/*`)
- `GET /api/inbox/conversations` — listagem com filtros
- `GET /api/inbox/conversations/[id]` — detalhe
- `POST /api/inbox/conversations/[id]/{ai-mode,ai-suggestion,archive,assign,avatar,block,cancel-followups,charge-pix,clear,delete,favorite,funnels-sent,mark-read,mark-unread,message-statuses,messages,mute,note,pending-automations,pending-jobs-count,pin,schedule,send,send-product,status,summarize,tags,transfer,transfer-instance,typing}`
- `DELETE /api/inbox/conversations/[id]/messages/[messageId]/delete`
- `POST /api/inbox/send` — envio simples
- `GET /api/inbox/messages`
- `GET /api/inbox/quick-replies`
- `GET /api/inbox/tags`
- `POST /api/inbox/typing`
- `GET /api/inbox/global-block`
- `GET /api/inbox/last-payment`
- `GET /api/inbox/alerts`, `/churn-alerts`
- `GET /api/sse/inbox` — Server-Sent Events para inbox real-time

### Contacts (`/api/contacts/*`)
- `GET/POST /api/contacts`
- `GET/PATCH/DELETE /api/contacts/[id]`
- `GET/POST /api/contacts/[id]/notes`, `/notes/[noteId]`
- `GET /api/contacts/[id]/payment-history`
- `GET /api/contacts/[id]/plan`
- `GET /api/contacts/[id]/reseller`
- `GET/POST /api/contacts/[id]/tags`
- `POST /api/contacts/auto-tags`
- `POST /api/contacts/backfill-clients`
- `GET /api/contacts/counts`
- `GET /api/contacts/export`
- `POST /api/contacts/import`
- `GET /api/contacts/monthly`
- `POST /api/contacts/monthly/send-renewal`
- `GET/POST /api/contacts/tags`, `/tags/[id]`, `/tags/sync-from-conversations`
- `GET /api/contacts/tested`

### Automações / Funis (`/api/automations/*`, `/api/guided-funnels/*`, `/api/campaigns/*`)
- `GET/POST /api/automations`, `/[id]`, `/[id]/logs`, `/[id]/stats`, `/[id]/steps`
- `GET/POST /api/automations/{audios,documentos,midias,media/[type]}` — assets
- `POST /api/automations/audios/[id]`, `/documentos/[id]`, `/midias/[id]`
- `POST /api/automations/funis/enroll`, `/cancel-funnel`
- `GET /api/automations/funis`, `/[id]`, `/analytics`, `/stages/[stageId]`
- `POST /api/automations/generate-audio`
- `GET /api/automations/logs/[log_id]/steps`
- `GET/POST /api/automations/quick-triggers`, `/text-triggers`, `/triggers`, `/triggers/[id]`, `/triggers/[id]/fire`
- `POST /api/automations/schedule-delete-audio`, `/upload`
- `GET /api/automations/trial-followup-stats`
- `GET/POST /api/guided-funnels`, `/[id]`, `/[id]/{export,positions,simulate,steps,steps/[stepId]}`, `/generate-ai`, `/import`, `/templates`, `/templates/install`
- `GET/POST /api/campaigns`, `/[id]`, `/[id]/recipients`, `/[id]/send`, `/blacklist`, `/blacklist/import`, `/drip`, `/drip/[id]`, `/drip/[id]/enroll`, `/preview-count`, `/segments`, `/segments/[id]`, `/segments/[id]/count`

### IA (`/api/ai/*`, `/api/ai-studio/*`)
- `POST /api/ai/chat`, `/agent-chat`, `/assistant`, `/suggest`, `/transcribe`
- `POST /api/ai/agent-app-flow`, `/agent-knowledge-map`
- `POST /api/ai/generate-agent-prompt`, `/generate-followup`
- `GET/POST /api/ai/agents`
- `POST /api/ai/process-conversations`
- `GET /api/ai/dashboard`, `/usage`, `/plan`
- `POST /api/ai/vision/analyze`
- `GET/POST /api/ai/knowledge`
- `GET/POST /api/ai-studio/agents`, `/chat`, `/conversations`, `/conversations/[id]`
- `POST /api/elevenlabs/settings`
- `GET /api/elevenlabs/voices`
- `GET/POST /api/master/elevenlabs-voices`, `/[id]`

### Knowledge / RAG (`/api/knowledge/*`)
- `GET/POST /api/knowledge/{bases,categories,categories/[id],documents,items,items/[id],items/bulk,search,templates,templates/install,upload}`

### Analytics / Métricas (`/api/analytics/*`, `/api/metrics/*`, `/api/dashboard/*`, `/api/sales-brain/*`)
- `GET /api/analytics/{churn,funnel,heatmap,instances,overview,revenue}`
- `GET /api/dashboard/overview`
- `GET /api/metrics`, `/instances`, `/snapshot`, `/supabase`, `/webhook-worker`, `/weekly-report`, `/worker`
- `GET /api/sales-brain/{churn-risk,credentials,dashboard,extract-credentials,funnel,graph,insights,journeys,live-feed,opportunities,overview,problems,process,timeline}`

### Workspace (`/api/workspace/*`, `/api/workspaces/*`, `/api/workspace-settings/*`, `/api/workspace-notes/*`)
- `GET/POST /api/workspaces`, `/active`, `/clone`, `/members`, `/members/create`, `/members/instance-permissions`
- `POST /api/workspace/activate-module`, `/buy-agent`, `/buy-credits`
- `GET /api/workspace/export`, `/plan`, `/report-preview`, `/trial-status`, `/whitelabel`, `/whitelabel/logo`
- `POST /api/workspace/plan/subscribe`
- `GET/PATCH /api/workspace-settings/{auto-close,auto-send-receipt,chat-widget,checkout-message-template,funnel-alert,instance-transfer-message,payment-messages,pix-custom-message,receipt-template,status-url,subscription-cost,support-message,tela-extra-message}`
- `GET/POST /api/workspace-notes`, `/[id]`

### Cron (`/api/cron/*` — 26 endpoints, ver Seção 11 do mapa principal)

### Master (`/api/master/*`, `/api/admin/*`)
- `GET /api/master/{ai-agents,audit-logs,financeiro,financeiro/global,global-blacklist,instances,jobs,monitoring,overview,plans,resellers,settings,tickets,topbar-stats,trials,workspaces}`
- `POST /api/master/{ai-agents/[id]/app-flow,app-flow/chat,financeiro/resellers/payout,instances/[id]/move,workspaces/copy-settings}`
- `GET /api/master/pessoas/{clientes,clientes/[id],funcionarios,funcionarios/[id],revendedores,revendedores/[id]}`
- `GET /api/master/workspace/[id]`
- `POST /api/master/workspace/[id]/action`
- `GET/POST /api/admin/{ai-plans,audit,debug-jobs,financeiro,fix-contact-plans,job-analysis,media-debug,payouts,payouts/commissions,payouts/discount-days,payouts/reverse-commissions,pending-users,redemptions,redemptions/[id],requeue-dead-jobs,resellers,resellers/[id],resellers/financial,resellers/withdrawals,resellers/withdrawals/[id],run-migration,store-items,store-items/[id],workspaces-map,workspaces-map/move-instance}`

### Outras
- `GET/POST /api/api-tokens`, `/[id]`
- `GET /api/audit-log`, `/audit-logs`
- `GET/POST /api/coupons`, `/[id]`, `/validate`
- `GET /api/credits/{balance,redeem,spend,store,transactions}` — créditos internos
- `POST /api/feature-access/admin`
- `GET/POST /api/followup/{blacklist,blacklist/[phone],campaigns,campaigns/[id],cancel,dashboard,funnel,logs,monitor,pause,preview-data,upcoming}`
- `GET /api/gamification/{config,leaderboard,my-stats,withdraw}`
- `GET/POST /api/groups`, `/[id]/{extract-contacts,messages,participants,send}`, `/bulk-send`, `/bulk-send/[id]`, `/bulk-send/[id]/items`, `/bulk-send/config`, `/bulk-send/improve-message`, `/bulk-send/stats`, `/contact-lists`, `/contact-lists/[id]`, `/contact-lists/[id]/members`, `/contacts`
- `GET /api/health`, `/health/full`, `/version`
- `GET/POST /api/jobs/cleanup`, `/clear-failed`, `/list`, `/retry-all`, `/stats`, `/status`, `/[jobId]/retry`
- `POST /api/links/shorten`
- `GET /api/me/permissions`
- `GET /api/media/[messageId]`
- `GET /api/migrate/*` — 50+ rotas de migração/diagnóstico (⚠️ sem auth na maioria)
- `GET /api/monitoring`, `/monitoring/message-status`
- `GET/POST /api/notifications`, `/[id]` (⚠️ sem auth via `x-internal-token`)
- `GET /api/onboarding/status`
- `GET/POST /api/preset-messages`, `/setup/preset-messages`
- `GET/POST /api/products`, `/[id]`, `/store-products`
- `GET /api/profile`, `/avatar`, `/notification-prefs`, `/stats`
- `GET/POST /api/recorrencia/{calendar,dashboard,history,subscriptions,subscriptions/[id],sync}`
- `POST /api/renewal/config`, `/pause-contact`, `/send-now`
- `GET /api/renewals/list`, `/projection`
- `POST /api/rotation/{instances,next,stats,status}` — autenticado por `ROTATION_API_KEY`
- `POST /api/scheduled-messages/dashboard`, `/dashboard/update`, `/stats`
- `GET /api/search`
- `GET /api/settings`, `/export`, `/modules`, `/sessions/revoke`, `/test-evolution`, `/test-webhook`
- `GET/POST /api/tags`, `/[id]`
- `GET /api/team/[userId]`, `/conversations`, `/credits`, `/financial`, `/metrics`
- `GET/POST /api/templates`, `/categories`, `/generate-ai`, `/match-trigger`
- `GET/POST /api/tickets`, `/[id]`, `/[id]/messages`, `/bulk-resolve`
- `GET /api/trial/apps`, `/trial/web` — público (CORS aberto)
- `POST /api/upload/media`, `/uploads/presign`
- `GET /api/user-settings`, `/[userId]`, `/stats`
- `GET /api/v1/contacts`, `/v1/messages/send` — API externa v1
- `POST /api/webchat/{block-ip,checkout,config,message,messages,plans,settings,start}`, `/webchat-settings`
- `GET/POST /api/webhooks`, `/[id]`, `/[id]/logs`, `/[id]/test`
- `GET /api/worker-alerts/{check,configs,configs/[id],logs}`
- `GET /api/external/{instances,metricas,pedidos}` — autenticado por `x-api-key`
- `GET /api/internal/resellers` — autenticado por `x-internal-token`

---

## Resumo numérico

| Categoria | Count |
|---|---|
| Pages totais | 92 |
| Pages públicas (sem login) | 12 |
| Pages dashboard (autenticadas) | 60 |
| Pages master (superadmin) | 16 |
| Pages public (`(public)/`) | 4 |
| API routes totais | 595 |
| API auth | 8 |
| API reseller | ~20 |
| API IPTV/Sigma | ~30 |
| API checkout/payments | ~22 |
| API inbox/contacts | ~70 |
| API automations/funis/campaigns | ~40 |
| API IA / knowledge | ~30 |
| API analytics / metrics | ~20 |
| API workspace / settings | ~30 |
| API cron | 26 |
| API master / admin | ~50 |
| API migrate / debug | ~55 (⚠️) |
