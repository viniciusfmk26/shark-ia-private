# bugs.md — Bugs e Problemas Conhecidos

> Registro de bugs conhecidos que ainda não foram corrigidos.
> Problemas de **segurança** estão em [[SECURITY]]. Plano de correção em [[FIXES]].
> Atualizado em 26/04/2026.

---

## Como usar este arquivo

- Registrar bugs que foram identificados mas ainda não corrigidos
- Incluir: descrição, impacto, como reproduzir, arquivo afetado
- Mover para "Corrigidos" quando o fix for aplicado
- Problemas de segurança vão em [[SECURITY]], não aqui

---

## Bugs ativos

### BUG-001 — handleSyncContacts atualiza contatos cross-tenant

**Arquivo:** `apps/worker/src/worker.ts` (função `handleSyncContacts`)
**Severidade:** Alta
**Identificado em:** 25/04/2026

**Descrição:**
O UPDATE final da sincronização de contatos não filtra por `workspace_id`:
```sql
UPDATE contacts SET name=$1, avatar_url=$2
WHERE phone_e164=$3 OR phone=$4
-- falta: AND workspace_id=$5
```

**Impacto:** Sincronização da instância do tenant A pode sobrescrever nome/avatar de um contato do tenant B se ambos tiverem o mesmo número de telefone.

**Fix planejado:** Fix 2.2 no FIXES.md

---

### BUG-002 — automations.workspace_id tem DEFAULT errado

**Arquivo:** Schema do banco (tabela `automations`)
**Severidade:** Média
**Identificado em:** 25/04/2026

**Descrição:**
```sql
-- DEFAULT atual:
workspace_id UUID DEFAULT '00000000-0000-0000-0000-000000000001'
-- ↑ UUID do workspace Superadmin
```

Automações criadas sem `workspace_id` explícito ficam no workspace do Superadmin em vez de retornar erro.

**Impacto:** Automações "perdidas" que somem da visão do tenant mas aparecem no superadmin.

**Fix planejado:** Fix 4.1 (migration `097_fix_automations_default.sql`)

---

### BUG-003 — Três triggers duplicados na tabela jobs

**Tabela:** `jobs`
**Severidade:** Baixa (funcional, mas custoso)
**Identificado em:** 25/04/2026

**Descrição:** A tabela `jobs` tem 3 triggers fazendo a mesma coisa (atualizar `updated_at`):
- `jobs_updated_at`
- `jobs_updated_at_trigger`
- `trg_jobs_updated_at`

**Impacto:** Cada UPDATE na tabela `jobs` dispara 3 triggers em vez de 1, triplicando o custo.

**Fix planejado:** Fix 4.2 (remover 2 dos 3 triggers)

---

### BUG-004 — Crons críticos não estão agendados no supercronic

**Arquivo:** `apps/cron/crontab`
**Severidade:** Média
**Identificado em:** 25/04/2026

**Descrição:** Vários crons existem no código mas não estão agendados:
- `plan-expiry` — vencimentos de planos não verificados automaticamente
- `renewal-check` — renovações não processadas
- `pix-followup` — follow-up de PIX pendentes
- `trial-followup` — follow-up de trials
- `drip-campaigns` — campanhas de gotejamento paradas
- `close-inactive` — conversas inativas não fechadas automaticamente
- `promote-expired-trials` — trials expirados não promovidos

**Impacto:** Funcionalidades de automação silenciosamente inativas.

**Fix planejado:** Fix 3.6

---

### BUG-005 — instância "01" da Fábrica sem número e desconectada

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa
**Identificado em:** 26/04/2026

**Descrição:** A instância "01" do workspace Fábrica está com `phone_number = NULL` e status `disconnected`. Provavelmente foi criada mas nunca configurada.

**Impacto:** Mensagens enviadas para essa instância falharão silenciosamente.

**Ação:** Verificar com cliente se instância deve ser configurada ou excluída.

---

### BUG-006 — "Disparo 01" do Iphone sem número e desconectada

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa
**Identificado em:** 26/04/2026

**Descrição:** Mesma situação do BUG-005 — instância criada mas nunca conectada ao WhatsApp.

**Ação:** Verificar com cliente Iphone.

---

### BUG-007 — "Uniflix Web" usa tipo "webchat" no phone_number

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa (comportamento proposital?)
**Identificado em:** 26/04/2026

**Descrição:** A instância "Uniflix Web" tem `phone_number = 'webchat'` — string literal, não um número. Status `disconnected` desde 23/04/2026.

**Ação:** Confirmar se é comportamento esperado do webchat ou bug de dados.

---

### BUG-008 — zapflix-monitor offline há mais de 3 semanas

**Serviço:** `wp_zapflix-monitor`
**Severidade:** Operacional
**Identificado em:** 25/04/2026

**Descrição:** O serviço de monitoramento (Flask) está com 0/1 réplicas, exit code 255. Nenhum alerta de WhatsApp está sendo disparado.

**Impacto:** Sistema operacionalmente cego — nenhuma notificação em caso de falha.

**Fix planejado:** Fix 3.5 (configurar variáveis de ambiente corretas)

---

## Bugs corrigidos

| ID | Descrição | Corrigido em | Commit |
|----|-----------|-------------|--------|
| — | Auth ausente em /api/debug/* e /api/migrate/* | 26/04/2026 | b102cb02 |
| — | Cron secret hardcoded 'zapflix2026' | 26/04/2026 | — |
| B1 | Anti-ban quebrado — queries SQL filtravam `direction='outbound'` mas banco usa `'out'`, contadores sempre 0 e limite diário nunca disparava (worker.ts linhas 3692, 4592, 4601) | 27/04/2026 | fe65a0ca |
| B2 | AI Agent histórico vazio — SELECT usava coluna `body` (correta é `text`) e filtro JS comparava com `'outbound'` (worker.ts linhas 3299/3306) | 27/04/2026 | e2f5ba16 |
| B3 | Cross-tenant no AI Agent — query `app_flow_nodes JOIN ai_writing_agents` sem filtro de `workspace_id`, prompt do agente vazava nodes de outros tenants (worker.ts linha 3390) | 27/04/2026 | c9d90b87 |
| B4 | Pool de conexões saturado — `handleProcessWebhook` segurava o client do `BEGIN` até o `finally`, mantendo a conexão durante chamadas Whisper/Vision/GPT-4o-mini (10-30s); 5 webhoooks simultâneos travavam o worker. Fix: `safeRelease()` movido para logo após o `COMMIT` (worker.ts linha 1949) | 27/04/2026 | 73d4257f |
| BUG-009 | Sidebar do cliente reorganizada — nova estrutura: Atendimento / Canais / Vendas / IPTV / Automação / IA / Analytics / Equipe / Revendedor / Configurações / Desenvolvedor / Interno. "Vitrine Netflix"→"Vitrine"; Loja de Módulos com roles owner/admin (e fora de viewerPaths); Documentação Webchat e Follow-up Automático removidos do menu; Revendedor consolidado em /reseller único; Meu Setup → Configurações; Faturamento sem dependência de iptv_trials; Painel Master encapsulado em "Interno" com Mapa de Workspaces e Sigma (todos superAdminOnly). `IPTV_RESELLER_ALLOWED_HREFS` atualizado de `/reseller-dashboard` → `/reseller`. (`components/layout/sidebar-nav.tsx`) | 27/04/2026 | eeecb23e |
| BUG-010 | Bipe de notificação tocava em todo carregamento de página — useEffect comparava `unreadCount` contra `prevUnreadRef=-1`, mas o segundo run (após `fetchNotifications` resolver) tinha `prev=0` e `count=N>0`, disparando o som como se fosse notificação nova. Fix: `notifInitializedRef` (true só após primeiro fetch) + `baselineSetRef` (true após gravar baseline pós-fetch) garantem que o som só toca em incremento real (`components/layout/top-bar.tsx`) | 27/04/2026 | b04b09a2 |
| BUG-011 | Flash visual de skeleton "fake-dashboard" em toda navegação entre páginas filhas — `app/(dashboard)/loading.tsx` renderizava header + stats cards + activity grid em todas as transições, mesmo quando navegando para /contacts, /campaigns, etc. Removido o skeleton, mantido o componente retornando `null` (Suspense boundary continua existindo para CSR bailout do `/settings` durante prerender do build). Resultado: navegação mantém a página anterior visível até a nova carregar (`app/(dashboard)/loading.tsx`) | 27/04/2026 | b03eebee |

---

## Template para novo bug

```
### BUG-XXX — [Título curto]

**Arquivo/Serviço:** 
**Severidade:** Crítica / Alta / Média / Baixa / Operacional
**Identificado em:** DD/MM/AAAA

**Descrição:**
[O que acontece]

**Impacto:**
[O que quebra para quem]

**Como reproduzir:**
1. 
2. 

**Fix planejado:** [referência ao FIXES.md ou "a definir"]
```
