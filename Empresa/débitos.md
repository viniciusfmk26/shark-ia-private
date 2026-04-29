# débitos.md — Débitos técnicos

> Bugs e melhorias identificados mas não resolvidos imediatamente. Diferente do [[../Shark-Panel/bugs]] (que registra bugs ativos com plano de fix), este arquivo é o **buffer** de itens conscientemente postergados — sabemos que existem, decidimos não tratar agora.
> Atualizado em 28/04/2026.

---

## Como usar este arquivo

- Registrar débitos técnicos identificados durante uma sessão mas decididos pra próxima
- Sempre incluir **por que** foi adiado (severidade baixa, dependência, escopo, etc.)
- Quando um débito vira prioridade, mover pra [[../Shark-Panel/bugs]] (bug ativo) ou [[roadmap]] (feature)
- Quando resolvido, mover pra "Resolvidos" no fim

---

## Backlog

| ID | Título | Severidade | Por que adiado | Notas |
|----|--------|------------|----------------|-------|
| B-004-rest | 4 callers BAIXOS de Evolution name vs UUID | Baixa | Investigação 28/04 mostrou que não são exercitados | `cron/check-worker-alerts:389` (alerts_triggered=0 sempre) · `cron/reseller-levels:96` (schema sem coluna `level`) · `v1/messages/send:52` (0 api_tokens existentes) · `iptv/generate-and-send:283,576` (caminho raro com conversationId) |
| B-006 | AmploPay URL legada em 3 rotas pendentes | Alta | Fix focado em F-001 Fase 2; outras rotas têm baixo volume | `app/api/workspace/buy-credits` · `app/api/workspace/buy-agent` · `app/api/workspace/plan/subscribe` — todas usam `api.amplopay.com/gateway/pix/receive` (404 hoje). Diff necessário em [[../Shark-Panel/bugs]] B-006. |
| B-008 | `buildSigmaMessage` duplicado | Baixa | Criado helper em F-001 Fase 2.2; webhook ainda usa versão inline | Migrar `app/api/payments/amplopay-webhook/route.ts:1712` pra `lib/sigma/build-message.ts`. Não bloqueante. |
| D-WA-001 | 4 colunas latentes em `whatsapp_instances` | Baixa | Descoberto em auditoria 29/04 ([[../Shark-Panel/whatsapp-instances]]) | `is_backup`, `failover_priority`, `is_paused`, `instance_type` indexados mas não usados em runtime. Decidir: remover ou começar a usar. |
| D-WA-002 | Pattern E não consolidado | Média | Descoberto em auditoria 29/04 | 12+ callers com estratégias variadas de seleção de instância (`resellers/withdraw`, `pedidos/.../recibo`, `cron/weekly-report`, etc). Refactor pra usar helpers padronizados (Pattern A/B/C). |
| D-WA-003 | Bruninhahh órfã | Baixa | Descoberto em auditoria 29/04 | Única instância com `is_payment_confirmation=true` mas DESCONECTADA. Webhook cai pro Tier 3 (qualquer connected). Decidir: desmarcar ou reconectar. |
| reseller-levels-schema | Coluna `level` parece não existir em `resellers` | Investigar | Bloqueador implícito do B-004-rest no item `reseller-levels` | Cron `cron/reseller-levels` referencia coluna `level` mas `\d resellers` não mostra. Verificar se cron está silenciosamente quebrado em outro ponto antes do bug do path. |
| F-001 Fase 2.2 | Ativação manual em `/reseller/clientes` (gastar crédito) | Em desenvolvimento | DDL ✅ aplicada · API+UI prontas (não commitadas) · falta E2E + flag UPDATE + commits | Ver [[roadmap]] F-001 e [[../Shark-Panel/feature-creditos-iptv]] · ADR-001 e ADR-002 em [[decisoes-arquiteturais]] |
| F-001 Fase 3 | Webhook condicional (modo `credit` no link do afiliado) | Produto | Próxima fase de afiliados | Ver [[roadmap]] F-001 |
| F-001 Fase 4 | UI master pra ver/ajustar saldos | Produto | Próxima fase de afiliados | Ver [[roadmap]] F-001 |
| Política de senha fraca | Hoje só exige `length >= 8` | Baixa | Sem incidente reportado | Sem maiúscula/número/símbolo · sem rate limit no `/api/auth/change-password` |
| BUG-001 | `handleSyncContacts` cross-tenant (sem `workspace_id` no UPDATE) | Alta | Fix planejado em FIXES 2.2 | Ver [[../Shark-Panel/bugs]] BUG-001 |
| BUG-002 | `automations.workspace_id` DEFAULT errado | Média | Fix planejado em FIXES 4.1 | Migration `097_fix_automations_default.sql` pendente |
| BUG-003 | 3 triggers duplicados em `jobs` | Baixa | Funcional, mas custoso | FIXES 4.2 |
| BUG-005 | Instância "01" da Fábrica sem número | Baixa | Aguardando confirmação do cliente | |
| BUG-006 | "Disparo 01" do Iphone sem número | Baixa | Aguardando confirmação do cliente | |
| BUG-007 | "Uniflix Web" tem `phone_number = 'webchat'` | Baixa | Confirmar se é proposital | |
| BUG-008 | `zapflix-monitor` Flask offline | Operacional | FIXES 3.5 | Sistema cego sem alertas |
| Monitor que não monitora a si mesmo | Healthcheck externo simples | Média | Falta um watchdog que pague pro monitor — quando o monitor cai (BUG-008), nada notifica | |
| Limpar links `appcineflick.com.br` em automações antigas | UI / Dados | Baixa | Trabalho manual de revisão | |
| Cupons globais visíveis no master | Feature | Média | A definir | |
| Master com tema azulado | Visual | Baixa | Unificar identidade visual master/cliente | Hoje master é dourado (Crown→🦈 já feito) e cliente é cyan |
| Página de obrigado com player IPTV ao vivo | Feature | Baixa | Após F-001 Fase 2/4 | |
| Tag "Mensalista" antes do pagamento confirmado | Bug antigo | Média | Reportado em sessão anterior | Tag aplicada no checkout antes do webhook AmploPay confirmar |
| Blessed Player sem código de ativação | Feature | Média | A investigar | |

---

## Resolvidos

| ID | Resolvido em | Como |
|----|-------------|------|
| (nenhum ainda — arquivo criado em 28/04/2026) | | |
