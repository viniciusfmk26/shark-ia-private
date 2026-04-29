# roadmap.md — Próximas Features e Melhorias

> Visão de produto e prioridades. Separado do [[FIXES]] (que é plano técnico de segurança).
> Relacionado: [[clientes]] · [[AUDITORIA_2026-04-28]]
> Atualizado em 28/04/2026 (auditoria contra estado real do servidor).

---

## Status atual do produto

O Zapflix Tech está funcional com os seguintes módulos:
- Atendimento via WhatsApp (multi-instância)
- Automações e funis guiados
- IA agent por workspace
- Checkout PIX integrado (AmploPay)
- IPTV trials e assinaturas
- Gamificação de atendentes (XP, níveis, créditos)
- Painel master (Vinicius) e painel de tenant

---

## Prioridade 1 — Segurança e estabilidade (Semana 1–2)

> Antes de qualquer feature nova, terminar os fixes críticos.

| Item | Status | Referência |
|------|--------|-----------|
| Portas fechadas via iptables | ✅ Concluído | Fix 1.1 |
| Auth em /api/debug/* e /api/migrate/* | ✅ Concluído | Fix 1.2 |
| Cron secret hardcoded removido | ✅ Concluído | Fix 1.3 |
| Rotacionar PAT do GitHub | ✅ Concluído | Fix 1.4 |
| Rotacionar CRON_SECRET / CRON_TOKEN | ✅ Concluído | Fix 1.4 |
| Rotacionar MinIO `S3_SECRET_KEY` | ✅ Decidido manter (28/04/2026) | Fix 1.4 |
| Auth em /api/notifications | ✅ Concluído | Fix 1.5 |
| IDOR analytics corrigido | ✅ Concluído | Fix 2.1 |
| handleSyncContacts com workspace_id | ✅ Concluído | Fix 2.2 |
| Backups automáticos configurados | ✅ Concluído | Fix 2.5 |

---

## Prioridade 2 — Operacional (Semana 3)

| Item | Status | Referência |
|------|--------|-----------|
| Stack Supabase legado desligado | ✅ Concluído | Fix 3.1 |
| PostgREST desligado | ✅ Concluído | Fix 3.2 |
| short-url.ts usando crypto | ✅ Concluído | Fix 3.3 |
| Redis com keyPrefix `shark:` | ✅ Concluído | Fix 3.4 |
| zapflix-monitor reativado | ✅ Concluído (28/04/2026 — imagem rebuildada) | Fix 3.5 |
| Crons críticos agendados | ✅ Concluído (28/04/2026 — 27 ativos + cutoff) | Fix 3.6 |

---

## Prioridade 3 — Features de produto

### F-001 — Sistema de afiliados

**O que é:** Cada revendedor pode ter um link de afiliado para indicar novos clientes. Comissão automática no checkout.

**Motivação:** Crescimento orgânico via rede de revendedores.

**Estimativa:** Médio porte (3–5 dias). Impacta: `resellers`, `checkout_orders`, novo job de comissão.

**Status:**
- ✅ Fase 1 (28/04/2026) — cadastro público + filtro UI no master. Ver [[feature-afiliados]].
- ✅ B-001 fix (28/04/2026) — Opção C2 + change-password + skip workspace pra afiliado. Ver [[bugs]] B-001 e [[auth-change-password]].
- ✅ Fase 2 (28/04/2026) — compra de crédito IPTV via PIX + ledger + UI completa. E2E validado em prod. Ver [[../Shark-Panel/feature-creditos-iptv]].
- 🚧 Fase 2.2 (29/04/2026) — ativação manual em `/reseller/clientes` gastando crédito. **DDL aplicada** + API/UI prontas (não commitadas). **Falta:** E2E + UPDATE flag `is_payment_confirmation` + commits. Ver [[../Empresa/decisoes-arquiteturais]] ADR-001 e ADR-002.
- ⏳ Fase 3 — webhook condicional (modo `credit` no link do afiliado)
- ⏳ Fase 4 — UI master pra ver/ajustar saldos
- ⏳ Fase 5 — notificação WhatsApp ao aprovar (já tem via reuso do approve do reseller)
- ⏳ Fase 6 — auto-aprovação opcional (toggle no master)

---

### F-002 — Crons automáticos não agendados

**O que é:** Ligar os crons que existem mas não rodam:
- `plan-expiry` — avisar clientes antes do vencimento
- `trial-followup` — follow-up automático de trials
- `drip-campaigns` — campanhas de gotejamento
- `pix-followup` — cobrar PIX expirado

**Motivação:** Funcionalidades já codificadas, só precisam ser ativadas.

**Estimativa:** Pequeno porte (1 dia). Ver Fix 3.6.

**Status:** Pendente

---

### F-003 — Dashboard de saúde operacional

**O que é:** Reativar e melhorar o `zapflix-monitor`. Alertas via WhatsApp quando:
- Instância desconecta
- Worker para de processar
- Banco não responde
- Taxa de erros sobe

**Motivação:** Sistema atualmente cego — nenhuma notificação em falhas.

**Estimativa:** Pequeno porte (reativar monitor + configurar env vars).

**Status:** Ver Fix 3.5

---

### F-004 — Política de retenção de dados

**O que é:** Cron semanal que limpa dados antigos para evitar crescimento infinito do banco:
- `audit_logs` > 90 dias (hoje: 347 MB sem retenção)
- `processed_events` > 30 dias (hoje: 127 MB)
- `worker_runs` > 14 dias (hoje: 44 MB)
- `jobs` succeeded/failed > 30 dias

**Motivação:** Banco crescendo sem controle, backup ficará inviável.

**Estimativa:** Pequeno porte. Ver Fix 2.4.

**Status:** Pendente

---

### F-005 — Webchat público por workspace

**O que é:** Canal de atendimento via chat no browser, sem precisar de WhatsApp. A instância "Uniflix Web" sugere que isso já existe parcialmente.

**Motivação:** Clientes que não têm WhatsApp precisam de atendimento.

**Estimativa:** A investigar (código do webchat já existe em `/api/webchat`)

**Status:** A investigar

---

### F-006 — Refatorar worker.ts

**O que é:** Quebrar o arquivo monolítico de 7.669 linhas em módulos por tipo de job.

**Motivação:** Manutenção difícil, PR reviews lentos, risco de conflito.

**Prioridade:** Baixa — funciona, não tem bugs conhecidos por causa do tamanho.

**Estimativa:** Grande porte (2–3 semanas). Fazer somente quando necessário.

**Status:** Backlog

---

## Ideias para validar com Vinicius

- **Multi-idioma:** Painel em PT/ES para clientes fora do Brasil
- **App mobile:** Atendimento via app (hoje só web)
- **Integrações:** CRM externo (HubSpot, RD Station)
- **Relatórios PDF:** Exportação de analytics por período
- **Planos e billing:** Cobrança recorrente dentro da plataforma (hoje é manual)

---

## Histórico de features entregues

| Feature | Data | Observação |
|---------|------|-----------|
| F-001 Fase 2 (compra crédito IPTV) | 28/04/2026 | E2E validado em prod (Vinicius pagou R$5 PIX real, saldo 0→1) · pacotes 1/10/50/100 · webhook idempotente via UNIQUE pix_identifier · ver [[../Shark-Panel/feature-creditos-iptv]] · commits 78eebc96 + dae155a2 + f26d383e + 914f8a51 |
| B-005 fix completo (phone E.164 BR) | 28/04/2026 | helper `normalizeBrPhone` + migration backfill (3 rows) + 7 fluxos de escrita sanitizados + refactor forgot-password · ver [[../Shark-Panel/bugs]] B-005 · commits 33bf9052 |
| B-004 fix expandido (Evolution name vs UUID) | 28/04/2026 | 7/11 callers fixados (4 BAIXA pendentes em débitos.md). Inclui caller ATIVO em admin/resellers approve · ver [[../Shark-Panel/bugs]] B-004 · commits d799ce4b + f1a6e667 |
| F-001 Afiliados Fase 1 | 28/04/2026 | reuso resellers + filtro UI · ver [[feature-afiliados]] · commit 38b6f587 |
| B-001 fix (afiliados + revendedores) | 28/04/2026 | C2 + change-password + skip workspace · ver [[auth-change-password]] · commits c92dc777 + d1a82488 |
| B-002 fix (workspace seed superadmin) | 28/04/2026 | seed workspace `…0001` + filtros em 6 listagens master · ver [[bugs]] B-002 · commit 4002699d |
| B-003 fix (audit cast user_id uuid) | 28/04/2026 | `$2::text → $2::uuid` desbloqueou ~10 callers de logAudit · ver [[bugs]] B-003 · commit 4dd33d45 |
| Esqueci senha (WhatsApp) | 28/04/2026 | token 1h + rate limit 3/h + envio Evolution · ver [[auth-change-password]] · commits 9a14ede6 + e8f5e1fe + 4dd33d45 + e97acdbe |
| B-004 fix parcial (Evolution name vs UUID) | 28/04/2026 | resolvido em forgot-password; pendente em 3 outros call-sites · ver [[bugs]] B-004 · commit 4dd33d45 |
| B-005 fix parcial (phone E.164 BR) | 28/04/2026 | quick fix em forgot-password; sanitização na escrita + migração pendentes · ver [[bugs]] B-005 · commit e97acdbe |
| Aba Problemas no Sales Brain | 26/04/2026 | commit 33c21a4a |
| Botão cancelar funil no badge "Inscrito" | 26/04/2026 | commit ecde0f1a |
| Fix cobrança avulsa vs plano mensal (webhook) | 26/04/2026 | commit ecde0f1a |
| Auth /api/debug e /api/migrate | 26/04/2026 | commit b102cb02 |
| Shark Panel — documentação técnica | 26/04/2026 | commit b598eef0 |
