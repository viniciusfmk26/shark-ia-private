# 01 — Módulos do Zapflix-Tech

> Status: ✅ Completo | 🔧 Parcial | ❌ Faltando/Quebrado  
> Atualizado: 2026-05-20

---

## Atendimento

### Inbox (Conversas)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo — núcleo do produto |
| Tabelas | `conversations`, `messages`, `tickets`, `conversation_notes` |
| Rotas API | `/api/inbox/*` (~60 rotas) |
| Componentes | `components/inbox/` |
| Páginas | `app/(dashboard)/inbox/page.tsx` |
| Observações | Robusto. Suporta: atribuição de agentes, transferência de instância, AI mode, arquivamento, schedule, charge-pix, resumo por IA, sugestão de resposta, presença, typing |

### Contatos
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `contacts`, `contact_tags`, `contact_tag_assignments`, `contact_notes` |
| Rotas API | `/api/contacts/*` (~15 rotas) |
| Componentes | `components/contacts/` |
| Páginas | `app/(dashboard)/contacts/` |
| Observações | Import CSV, export, health-score, monthly view, saúde |

### Kanban
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Tabelas | `kanban_contacts` (implícito via conversations) |
| Rotas API | `/api/kanban/contacts`, `/api/kanban/contacts/[id]/move` |
| Páginas | `app/(dashboard)/kanban/page.tsx` |
| Observações | Backend existe; UI básica presente |

### CRM (Deals/Pipeline)
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial — 0 deals em prod |
| Tabelas | `crm_pipelines`, `crm_stages`, `crm_deals`, `crm_activities` |
| Rotas API | `/api/crm/*` |
| Páginas | `app/(dashboard)/crm/page.tsx` |
| Observações | 1 pipeline, 6 stages, 0 deals. Falta importar leads de conversas e drag-drop entre stages |

### Tickets (Suporte interno SaaS)
| Campo | Valor |
|-------|-------|
| Status | 🔧 Esqueleto — 0 tickets em uso |
| Tabelas | `saas_tickets`, `ticket_messages` |
| Rotas API | `/api/saas-tickets/*`, `/api/tickets/*` |
| Páginas | `app/(dashboard)/tickets/page.tsx` |

---

## Canais (WhatsApp)

### Instâncias WhatsApp
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `whatsapp_instances`, `instance_metrics`, `instance_health_log` |
| Rotas API | `/api/instances/*` (~15 rotas), `/api/whatsapp/instances/*` |
| Componentes | `components/instances/` |
| Páginas | `app/(dashboard)/whatsapp-instances/page.tsx` |
| Observações | Connect, health check, sync contacts, sync profile, tag-color, rotation (load balancer de instâncias) |

### Grupos
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Rotas API | `/api/groups/*`, `/api/grupos/*` |
| Páginas | `app/(dashboard)/groups/page.tsx`, `grupos/page.tsx` |
| Observações | Extração de contatos, bulk send de mensagens para grupos |

### Webchat (Widget público)
| Campo | Valor |
|-------|-------|
| Status | 🔧 Implementado, sem snippet embed |
| Tabelas | `webchat_sessions`, `webchat_settings`, `webchat_plans`, `webchat_blocked_ips` |
| Rotas API | `/api/webchat/*` |
| Páginas | `app/(dashboard)/webchat-settings/page.tsx` |
| Observações | Falta snippet `<script>` para embed externo e analytics |

---

## Automação

### Automações / Funis
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo — usado intensamente |
| Tabelas | `automations`, `automation_steps`, `automation_triggers`, `automation_flow_sessions`, `automation_logs` |
| Rotas API | `/api/automations/*` (~20 rotas) |
| Componentes | `components/automations/` |
| Páginas | `app/(dashboard)/automacoes/`, `automations/` |
| Observações | 11.802 logs de execução. Suporta: triggers, quick-triggers, text-triggers, upload de mídia, geração de áudio (ElevenLabs) |

### Funis Guiados
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `guided_funnels`, `guided_funnel_steps`, `guided_funnel_positions` |
| Rotas API | `/api/guided-funnels/*` (~10 rotas) |
| Páginas | `app/(dashboard)/guided-funnels/` |
| Observações | Builder visual (xyflow), import/export, templates, simulação, geração por IA |

### Follow-up / Drip Leads
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Tabelas | `followups`, `followup_queue`, `followup_campaigns` |
| Rotas API | `/api/followup/*`, `/api/followups/*` |
| Páginas | `app/(dashboard)/automations/follow-up/page.tsx` |
| Observações | Backend completo; adoção low |

### Templates
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `templates`, `template_categories` |
| Rotas API | `/api/templates/*` |
| Páginas | `app/(dashboard)/templates/page.tsx` |

### Agendamentos
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `scheduled_messages` |
| Rotas API | `/api/scheduled-messages/*` |
| Páginas | `app/(dashboard)/agendamentos/page.tsx` |

---

## Marketing

### Campanhas (Bulk + Drip)
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial — código pronto, 0 campanhas em prod |
| Tabelas | `campaigns`, `campaign_recipients`, `drip_campaigns`, `bulk_send_batches` |
| Rotas API | `/api/campaigns/*` (~10 rotas) |
| Páginas | `app/(dashboard)/campanhas/page.tsx`, `campaigns/page.tsx` |
| Observações | Suporte a segmentos, blacklist, preview de count, envio por instância |

### Campanhas ADs
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Tabelas | `ad_campaigns` |
| Rotas API | `/api/ad-campaigns/*` |
| Páginas | `app/(dashboard)/ad-campanhas/page.tsx` |

### Reengajamento
| Campo | Valor |
|-------|-------|
| Status | ✅ Funcional |
| Tabelas | `reengagement_configs` |
| Rotas API | `/api/reengagement/*` |
| Páginas | `app/(dashboard)/reengajamento/page.tsx` |

### NPS
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial — 0 respostas em prod |
| Tabelas | `nps_responses` |
| Rotas API | `/api/nps/*` |
| Páginas | `app/(dashboard)/nps/page.tsx` |
| Observações | Falta cron de disparo e UI de configuração de gatilho |

### Links Curtos
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `links`, `link_clicks` |
| Rotas API | `/api/links`, `/api/links/shorten`, `/api/r/[code]` |
| Páginas | `app/(dashboard)/links/page.tsx` |

---

## IA

### AI Agents (agente conversacional)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo — 5 agentes ativos |
| Tabelas | `ai_agents`, `ai_agent_conversations`, `ai_agent_logs`, `agent_contexts`, `ai_writing_agents` |
| Rotas API | `/api/ai/*` (~15 rotas), `/api/ai-studio/*` |
| Páginas | `app/(dashboard)/ai/`, `ai-studio/`, `ai-assistant/` |
| Observações | Modos: suggestion / copilot / autonomous. Vision (prints IPTV), transcrição áudio, geração de prompt, AI Studio |

### Sales Brain
| Campo | Valor |
|-------|-------|
| Status | 🔧 Embrionário |
| Tabelas | `sales_brain_insights`, `sales_opportunities` (3.169), `journey_events`, `customer_journey` |
| Rotas API | `/api/sales-brain/*` (~12 rotas) |
| Páginas | `app/(dashboard)/sales-brain/page.tsx` |
| Observações | UI existe; backend parcial; dados-mestre vazios em parte |

### Knowledge / RAG
| Campo | Valor |
|-------|-------|
| Status | 🔧 Bloqueado — pgvector quebrado |
| Tabelas | `knowledge_items`, `knowledge_categories`, `knowledge_bases`, `knowledge_chunks`, `knowledge_documents` |
| Rotas API | `/api/knowledge/*` (~10 rotas) |
| Páginas | `app/(dashboard)/knowledge/page.tsx` |
| Observações | 15 itens; `knowledge_chunks` = 0 (embedding falha — `could not access file "$libdir/vector"`) |

### Marketplace de Agentes IA
| Campo | Valor |
|-------|-------|
| Status | ❌ Esqueleto — 0 agentes publicados |
| Tabelas | `marketplace_agents`, `workspace_marketplace_subscriptions` |
| Rotas API | `/api/marketplace/*`, `/api/master/marketplace-agents/*` |
| Páginas | `app/(dashboard)/marketplace/page.tsx` |

---

## IPTV

### Trials (testes IPTV)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo — diferencial competitivo |
| Tabelas | `iptv_trials`, `iptv_generated_tests`, `iptv_active_trials` (view) |
| Rotas API | `/api/iptv/trials/*` (~8 rotas) |
| Componentes | `components/trials/` |
| Páginas | `app/(dashboard)/trials/page.tsx` |
| Observações | 1.287 trials / 2.872 testes gerados em prod |

### Apps / Bots IPTV
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `iptv_app_configs`, `iptv_server_bots`, `iptv_bots_by_app` |
| Rotas API | `/api/iptv/app-configs/*`, `/api/iptv/bots` |
| Páginas | `app/(dashboard)/iptv-apps/page.tsx` |

### Servidores IPTV / Sigma
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `sigma_servers`, `sigma_mappings` |
| Rotas API | `/api/iptv/servers`, `/api/sigma/*` |
| Páginas | `app/(dashboard)/sigma/page.tsx`, `iptv-plans/` |
| Observações | `server` é int legado 1/2 (1=megabox, 2=tps) — sem FK — mapeado por slug |

### Renovações IPTV
| Campo | Valor |
|-------|-------|
| Status | ✅ Funcional |
| Rotas API | `/api/iptv/renewals`, `/api/renewals/*` |
| Páginas | `app/(dashboard)/iptv/renovacoes/page.tsx` |

---

## Loja / Checkout

### Checkout PIX (produtos)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `checkout_orders`, `checkout_plans`, `payments`, `lowticket_orders` |
| Rotas API | `/api/checkout/*`, `/api/payments/amplopay-webhook`, `/api/lowticket/*` |
| Páginas | `app/(dashboard)/checkout/`, `/p/[product_slug]/`, `app/pix/[id]/` |
| Observações | Webhook Amplo Pay atual. Webhook legado `/api/payments/webhook` ainda exposto — risco de double-processing |

### Produtos / Loja
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `products`, `store_products`, `checkout_products` |
| Rotas API | `/api/products/*`, `/api/store-products`, `/api/checkout/products/*` |
| Páginas | `app/(dashboard)/products/page.tsx`, `store/`, `store-config/` |

### Recorrência (assinaturas)
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Tabelas | `subscriptions`, `subscription_payments`, `renewal_messages` |
| Rotas API | `/api/recorrencia/*` |
| Páginas | `app/(dashboard)/recorrencia/page.tsx` |
| Observações | 1.743 subs no banco; cron `recorrencia-sync` ativo; integração Amplo Pay subscription ausente |

### Cupons
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `coupons` |
| Rotas API | `/api/coupons/*` |
| Páginas | `app/(dashboard)/coupons/page.tsx` |

---

## Analytics / Dashboard

### Dashboard Principal
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Rotas API | `/api/dashboard/*` (~6 rotas) |
| Páginas | `app/(dashboard)/dashboard/page.tsx` |

### Analytics
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Rotas API | `/api/analytics/*` (~7 rotas), `/api/metrics/*` |
| Páginas | `app/(dashboard)/analytics/`, `metrics/`, `relatorios/` |
| Observações | Heatmap de conversão, comparação mensal, funil, receita, instâncias |

### Financeiro
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Rotas API | `/api/payments/*` |
| Páginas | `app/(dashboard)/financeiro/page.tsx` |

---

## Equipe

### Usuários / Membros
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `nextauth_users`, `workspace_memberships`, `user_settings` |
| Rotas API | `/api/team/*`, `/api/workspaces/members/*` |
| Páginas | `app/(dashboard)/users/page.tsx`, `team/[userId]/` |

### Gamificação (comissões + XP)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo — ativo em Shark Panel |
| Tabelas | `agent_levels`, `agent_xp_log`, `agent_badges`, `agent_commissions` (867 linhas), `agent_performance_daily` |
| Rotas API | `/api/gamification/*` |
| Páginas | `app/(dashboard)/gamification/page.tsx` |

---

## Configurações / Planos

### Configurações do Workspace
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `workspace_settings`, `workspace_notes` |
| Rotas API | `/api/workspace-settings/*`, `/api/settings/*` |
| Páginas | `app/(dashboard)/settings/page.tsx` |

### Planos SaaS / Cobrança
| Campo | Valor |
|-------|-------|
| Status | ❌ Monetização quebrada |
| Tabelas | `workspace_plans` (7), `workspace_subscriptions` (4), `workspace_plan_payments` (1), `workspace_module_addons` (1) |
| Rotas API | `/api/workspace/plan/*` |
| Páginas | `app/(dashboard)/meu-plano/page.tsx`, `upgrade/page.tsx` |
| Observações | Webhook não ativa subscription ao pagar; planos têm `price_cents=0`; enforcement de limites ausente |

### Módulos / Features (Feature Flags)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `workspace_features`, `module_trials` |
| Rotas API | `/api/workspace/features`, `/api/feature-access/admin` |

---

## Painel Reseller / Master

### Painel Reseller
| Campo | Valor |
|-------|-------|
| Status | 🔧 Parcial |
| Tabelas | `resellers` (4), `reseller_sales` (272), `reseller_ledger` (110), `reseller_credit_ledger`, `reseller_withdrawals` |
| Rotas API | `/api/resellers/*` (~10 rotas) |
| Páginas | `app/(dashboard)/reseller/`, `resellers/` |
| Observações | Pagamentos a revendedor existem; withdraw flow incompleto |

### Painel Master (Admin)
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Rotas API | `/api/master/*` (~40 rotas), `/api/admin/*` |
| Páginas | `app/(master)/master/*` |
| Observações | Gerencia workspaces, planos, trials, usuários, financeiro global, monitoramento, blacklist global, marketplace |

---

## Infraestrutura / Sistema

### Worker / Jobs
| Campo | Valor |
|-------|-------|
| Status | ✅ Saudável |
| Tabelas | `jobs` (17.571), `worker_runs`, `worker_heartbeats`, `worker_alert_configs` |
| Rotas API | `/api/jobs/*`, `/api/worker-alerts/*` |
| Páginas | `app/(dashboard)/jobs/page.tsx` |
| Observações | 16.439 succeeded, 10 queued; worker daemon em `apps/worker/src/worker.ts` |

### Webhooks externos
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Tabelas | `webhooks`, `webhook_logs` |
| Rotas API | `/api/webhooks/*`, `/api/webhook/*` |
| Páginas | `app/(dashboard)/webhooks/page.tsx` |

### API Tokens (API externa v1)
| Campo | Valor |
|-------|-------|
| Status | ❌ 0 tokens emitidos |
| Tabelas | `api_tokens` (0 linhas) |
| Rotas API | `/api/api-tokens/*`, `/api/v1/*`, `/api/external/*` |
| Páginas | `app/(dashboard)/api-tokens/page.tsx` |

### Monitoramento
| Campo | Valor |
|-------|-------|
| Status | ✅ Completo |
| Rotas API | `/api/monitoring/*`, `/api/metrics/*`, `/api/health/*` |
| Páginas | `app/(dashboard)/monitoring/page.tsx` |

---

*Veja também: [[00-visao-geral]] | [[02-api-routes]] | [[04-pendencias]]*
