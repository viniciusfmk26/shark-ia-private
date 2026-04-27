# Mapeamento Master × Painel Cliente

> Snapshot de análise estratégica — 27/04/2026.
> **Não é doc vivo.** Fotografia das páginas existentes em ambas as áreas, com diagnóstico de duplicações, lacunas e sobreposições.
> Relacionado: [[CLAUDE]] | [[bugs]]

---

## Páginas do Master (13)

| Rota | Função |
|------|--------|
| `/master` | Painel Master (overview global, KPIs, MRR) |
| `/master/workspaces` | Lista de todos os workspaces |
| `/master/workspace/[id]` | Detalhe/admin de 1 workspace |
| `/master/financeiro` | Financeiro **global** (MRR total, saques, comissões) |
| `/master/monitoramento` | Monitoramento de infra (workers, Redis, DB, instâncias) |
| `/master/planos` | Planos por workspace (IA) |
| `/master/pessoas` | Gestão global de usuários |
| `/master/revendedores` | Revendedores/afiliados (global) |
| `/master/audit` | Auditoria global (cross-workspace) |
| `/master/blacklist` | Blacklist global |
| `/master/configuracoes` | Plataforma (API keys, limites padrão) |
| `/master/ai-agents` | Agentes IA + vozes ElevenLabs (globais) |
| `/master/ai-agents/[id]` | Editor de fluxo de agente |

## Páginas do Cliente (~58 grupos)

- **Operacional:** inbox, contacts, contacts/monthly, groups, agendamentos, automations, automations/follow-up, guided-funnels, guided-funnels/[id], campaigns, templates, tickets, alerts
- **Vendas/E-commerce:** checkout-admin, cobranca-rapida, products, pedidos, store, store-config, netflix-store, iptv-apps, iptv-plans, coupons, recorrencia, redemptions, sigma, sales-brain, gamification
- **Financeiro/Afiliados:** billing, financeiro, reseller, reseller-dashboard, resellers, trials, upgrade
- **IA:** ai, ai-assistant, ai-studio, knowledge
- **Infra/Config:** settings, monitoring, whatsapp-instances, webhooks, webchat-settings, webchat-docs, api-tokens, jobs, audit-log, audit-logs, meu-setup, profile, help, workspaces-map
- **Métricas:** analytics, analytics/instances, metrics, metrics/reports
- **Pessoas:** users, team/[userId]

---

## Diagnóstico cruzado

### ✅ Só no Master (correto — escopo plataforma)
- `/master/workspaces`, `/master/workspace/[id]` — gestão cross-tenant
- `/master/blacklist` (global)
- `/master/configuracoes` (API keys da plataforma, limites padrão)
- `/master/ai-agents` + `[id]` (biblioteca global + ElevenLabs)
- `/master/planos` (visão de planos atribuídos por workspace)

### ✅ Só no Cliente (correto — escopo workspace)
inbox, contacts, groups, automations, guided-funnels, campaigns, templates, tickets, alerts, store, products, pedidos, checkout-admin, coupons, sigma, gamification, sales-brain, iptv-apps, iptv-plans, netflix-store, knowledge, profile, help, meu-setup, whatsapp-instances, webhooks, webchat-settings, api-tokens, analytics, metrics

### ⚠️ Nos dois — escopo legítimo, mas naming pode confundir

| Master | Cliente | Diagnóstico |
|--------|---------|-------------|
| `/master/financeiro` (MRR plataforma) | `/financeiro` (saldo de revendedores próprios) + `/billing` (receita de vendas) | Escopos diferentes — OK. Naming `financeiro` repetido em master e cliente gera ambiguidade. |
| `/master/monitoramento` (workers/redis/db) | `/monitoring` (monitoramento de instâncias/jobs/mensagens + 3 tabs de settings ao final) | Escopos diferentes — OK. Cliente tem ressaca de tabs de settings duplicadas no rodapé. |
| `/master/audit` (cross-ws) | `/audit-log` (real, por ws) + `/audit-logs` (com fallback para MOCK data) | `/audit-logs` tem `generateMockLogs` como fallback quando API falha — confunde com dados reais. |
| `/master/pessoas` | `/users` + `/team/[userId]` | OK por escopo. Naming inconsistente (pessoas vs users). |
| `/master/revendedores` | `/reseller` + `/reseller-dashboard` + `/resellers` | **3 páginas de afiliado no cliente** — provável duplicação (reseller × reseller-dashboard). `/resellers` plugado no sidebar (Revendedor → Meus Revendedores) em 27/04/2026; aprovação de saque removida da página (fica só em `/master/revendedores`). |
| `/master/ai-agents` | `/ai` + `/ai-assistant` + `/ai-studio` | **3 páginas de IA no cliente** — alta chance de sobreposição. |

### ❌ Falta no Master
- Tickets/Suporte global
- Trials/Upgrade global (pipeline de conversão)
- Jobs/Filas global (fila por workspace)
- Cupons/Coupons global
- Webhooks global
- IPTV Plans/Apps global

### ❌ Falta no Cliente
- Blacklist do workspace (só existe global)
- Página "Meu Plano" (cliente não tem visão clara do plano/limites — só `/upgrade`)

---

## Suspeitas fortes de duplicação dentro do Cliente

1. ~~**`/ai` × `/ai-studio` × `/ai-assistant`**~~ — investigado em 27/04/2026: `/ai` (config + 3 tabs) e `/ai-studio` (editor visual ReactFlow) consomem APIs **separadas** (`/api/ai/*` vs `/api/ai-studio/*`), são páginas legítimas. `/ai-assistant` era órfã do sidebar; **plugada como "Assistente IA"** na seção IA (commit `243de1b6`).
2. ~~**`/reseller` × `/reseller-dashboard`**~~ — **Resolvido em 27/04/2026** (commit `243de1b6`): features ricas do `/reseller-dashboard` (níveis, gráfico, clientes) migradas para `/reseller`; `/reseller-dashboard` virou redirect.
3. ~~**`/audit-log` × `/audit-logs`**~~ — **Resolvido em 27/04/2026** (commit `07923218`).
4. ~~**`/monitoring`**~~ — **Resolvido em 27/04/2026** (commit `ce1a3617`).

---

## Recomendações priorizadas

1. ~~Investigar `/audit-logs`~~ — feito (redirect) em 27/04/2026 (commit `07923218`).
2. ~~Decidir destino de `/reseller` vs `/reseller-dashboard`~~ — feito em 27/04/2026 (commit `243de1b6`); features migradas para `/reseller`, dashboard virou redirect.
3. ~~Auditar `/ai` × `/ai-studio` × `/ai-assistant`~~ — feito em 27/04/2026 (commit `243de1b6`); APIs diferentes (não são duplicação real); `/ai-assistant` plugada no sidebar.
4. ~~Remover tabs de settings duplicadas do rodapé de `/monitoring`~~ — feito em 27/04/2026 (commit `ce1a3617`); página agora está no menu (Analytics).
5. Adicionar no cliente: blacklist do workspace + página "Meu Plano".
6. Adicionar no master: visão global de tickets, trials, jobs e cupons.
7. Avaliar `/resellers` (admin client de revendedores) — duplica `/master/revendedores`. **Mantido em 27/04/2026**: plugado no sidebar como "Meus Revendedores" e aprovação/rejeição de saque removida (fica exclusiva no master).
