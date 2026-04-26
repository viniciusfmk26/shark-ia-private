# roadmap.md — Próximas Features e Melhorias

> Visão de produto e prioridades. Separado do [[FIXES]] (que é plano técnico de segurança).
> Relacionado: [[clientes]]
> Atualizado em 26/04/2026.

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
| Rotacionar credenciais (PAT, MinIO, CRON) | ⏳ Pendente | Fix 1.4 |
| Auth em /api/notifications | ⏳ Pendente | Fix 1.5 |
| IDOR analytics corrigido | ⏳ Pendente | Fix 2.1 |
| handleSyncContacts com workspace_id | ⏳ Pendente | Fix 2.2 |
| Backups automáticos configurados | ⏳ Pendente | Fix 2.5 |

---

## Prioridade 2 — Operacional (Semana 3)

| Item | Status | Referência |
|------|--------|-----------|
| Stack Supabase legado desligado | ⏳ Pendente | Fix 3.1 |
| PostgREST desligado | ⏳ Pendente | Fix 3.2 |
| short-url.ts usando crypto | ⏳ Pendente | Fix 3.3 |
| Redis com keyPrefix zapflix: | ⏳ Pendente | Fix 3.4 |
| zapflix-monitor reativado | ⏳ Pendente | Fix 3.5 |
| Crons críticos agendados | ⏳ Pendente | Fix 3.6 |

---

## Prioridade 3 — Features de produto

### F-001 — Sistema de afiliados

**O que é:** Cada revendedor pode ter um link de afiliado para indicar novos clientes. Comissão automática no checkout.

**Motivação:** Crescimento orgânico via rede de revendedores.

**Estimativa:** Médio porte (3–5 dias). Impacta: `resellers`, `checkout_orders`, novo job de comissão.

**Status:** A definir

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
| Botão cancelar funil no badge "Inscrito" | 26/04/2026 | commit ecde0f1a |
| Fix cobrança avulsa vs plano mensal (webhook) | 26/04/2026 | commit ecde0f1a |
| Auth /api/debug e /api/migrate | 26/04/2026 | commit b102cb02 |
| Shark Panel — documentação técnica | 26/04/2026 | commit b598eef0 |
