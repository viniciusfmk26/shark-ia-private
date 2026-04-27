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
| `/master/revendedores` | `/reseller` + `/reseller-dashboard` + `/resellers` | **3 páginas de afiliado no cliente** — provável duplicação (reseller × reseller-dashboard). |
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

1. **`/ai` × `/ai-studio` × `/ai-assistant`** — 3 superfícies de IA, todas com chat/agentes.
2. **`/reseller` × `/reseller-dashboard`** — ambos painel do próprio afiliado, com headers diferentes ("Meu Painel" vs "Dashboard Afiliado").
3. **`/audit-log` × `/audit-logs`** — `/audit-logs` cai em mock quando API falha. **Resolvido em 27/04/2026** (ver bugs.md): sidebar agora aponta para `/audit-log` e `/audit-logs` redireciona.
4. **`/monitoring`** — nome OK (tem conteúdo real de monitoramento), mas duplica 3 tabs de settings no rodapé (notifications/security/webhooks). Já existem em `/settings`. Refactor pendente para limpar o rodapé. **Não está no menu** — orfã, acessível só por URL direta.

---

## Recomendações priorizadas

1. ~~Investigar `/audit-logs`~~ — feito (redirect) em 27/04/2026.
2. Decidir destino de `/reseller` vs `/reseller-dashboard` — manter um.
3. Auditar `/ai` × `/ai-studio` × `/ai-assistant` — definir responsabilidade de cada um.
4. Remover tabs de settings duplicadas do rodapé de `/monitoring` (notifications, security, webhooks).
5. Adicionar no cliente: blacklist do workspace + página "Meu Plano".
6. Adicionar no master: visão global de tickets, trials, jobs e cupons.
