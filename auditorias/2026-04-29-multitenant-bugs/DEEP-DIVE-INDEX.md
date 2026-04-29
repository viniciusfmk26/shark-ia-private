# 🦈 Deep Dive — Automações, Funis, IA, Knowledge, Follow-up, Webchat, Sales Brain

**Data:** 2026-04-29
**Repo analisado:** `/root/Zapflix-Tech` + `wp_zapflix-db`
**Workspaces:** shark-panel (principal), Uniflix, diario-das-bruxas, fabrica, iphone, shark, superadmin-sistema

---

## 🎯 Sumário executivo — Top 5 descobertas

1. **🔴 BUG MULTI-TENANT em ≥4 endpoints de IA:** `SELECT openai_api_key FROM ai_provider_settings LIMIT 1` sem `WHERE workspace_id`. Workspace A consome chave do workspace B. Endpoints afetados: `/api/ai/agent-chat`, `/api/ai/assistant`, `/api/ai/generate-followup`, `/api/ai-studio/chat`, `/api/sales-brain/process`. **Prioridade alta — viola CLAUDE.md e expõe chaves.**

2. **🔴 BUG CRÍTICO no cron drip-campaigns:** `INSERT INTO jobs (type, payload_json, ...)` — coluna `payload_json` **não existe** (só `payload`). Toda execução do cron falha silenciosamente (try/catch swallow). Confirmado via `information_schema.columns`. Se ativarem drips, **nenhuma mensagem é enviada**.

3. **🔴 RAG vetorial é cosmético:** `pgvector NÃO instalado`, `knowledge_chunks.embedding text` (não vector). Todo o pipeline de docs/chunks está inerte. Promessa de "RAG" para clientes é falsa hoje. **5 knowledge_bases todas chamadas "aa"** (teste).

4. **Pipeline de vendas semi-quebrado:** 2.600 sales_opportunities mas **0 won + 0 lost**. `lib/sales-brain/pipeline.ts.onPaymentConfirmed()` provavelmente nunca é chamado pelo webhook AmploPay. Customer_journey paralelo (8k rows) reporta 272 converted — discrepância indica dois sistemas duplicados sem reconciliação.

5. **Ecossistema Frankenstein:** ≥7 sistemas paralelos para "follow-up/sequência" — automations intercept, automation_triggers (keyword), guided_funnels (URA), funnels legacy + funnel-processor cron, drip_campaigns, scheduled_messages, followup_campaigns, abandoned_cart_log. Adoption real concentrada em 3 deles (scheduled_messages, followup_campaigns trial_expired, funnels legacy). Resto é dead code ou nunca decolou.

---

## 📚 Por área (8 arquivos)

| # | Área | Arquivo | Status | Adoption |
|---|------|---------|--------|----------|
| 1 | Automações | [deep-automations.md](deep-automations.md) | ✅ Documentado | shark-panel pausado |
| 2 | Funis Guiados | [deep-funnels.md](deep-funnels.md) | ✅ Documentado | shark-panel inactive |
| 3 | Drip Campaigns | [deep-drip.md](deep-drip.md) | ✅ Documentado | **0 — bug crítico** |
| 4 | IA (Agents, Studio, App-Flow) | [deep-ia.md](deep-ia.md) | ✅ Documentado | shark-panel parcial |
| 5 | Knowledge Bases / RAG | [deep-knowledge.md](deep-knowledge.md) | ✅ Documentado | **0** |
| 6 | Follow-up + Scheduled | [deep-followup-scheduled.md](deep-followup-scheduled.md) | ✅ Documentado | **shark-panel ativo** |
| 7 | Webchat + Recorrência | [deep-webchat-recorrencia.md](deep-webchat-recorrencia.md) | ✅ Documentado | shark-panel ativo |
| 8 | Sales Brain | [deep-sales-brain.md](deep-sales-brain.md) | ✅ Documentado | shark-panel ativo |

---

## 🧭 Comparação: quando usar o quê

| Cenário | Use | Engine | Estado |
|---------|-----|--------|--------|
| Cliente envia "preço" → resposta auto | `automation_triggers` (type=keyword) | Worker inbound | Funcional |
| Sequência guiada multi-step (URA) | `guided_funnels` | Worker inbound | Funcional, inactive em prod |
| WhatsApp marketing N dias | `drip_campaigns` | Cron 15min | **🔴 Bugado** |
| Resposta IA contextual | `ai_agents` autonomous + `knowledge_items` | Worker inbound | Inactive em prod |
| Lembrar PIX 24h depois | `scheduled_messages` | Cron 1min | Funcional |
| Carrinho abandonado | `workspace_settings.abandonedCart` + cron `abandoned-cart` | Cron 2h | Não habilitado |
| Webchat público no site | `/api/webchat/*` + widget | API REST CORS | Funcional |
| Cobrança recorrente PIX | AmploPay (externo) + sync `subscriptions` | Webhook | Funcional |
| Detectar cliente em risco | `/api/sales-brain/churn-risk` | Endpoint sob demanda | Funcional |
| Follow-up de trial expirado | `followup_campaigns(trial_expired)` | Cron 1×/dia 10h | **Funcional + 1417 envios** |
| Follow-up de PIX pendente | `followup_campaigns(pix_pending)` | Cron 30min | Funcional + 127 envios |
| Auto-resposta fora do horário | `automations.intercept_trigger_type='any_message'` + schedule | Worker inbound | Pausado |
| Pipeline de vendas (kanban) | `sales_opportunities` + UI sales-brain | Webhook + manual | Semi-funcional (0 won/lost) |

---

## 📊 Adoption por workspace

| Workspace | autom. | triggers | funnels | drips | ai_ag | ai_cfg | KBs | kb_items | sched | webchat | subs | opps | fu_camp |
|-----------|--------|----------|---------|-------|-------|--------|-----|----------|-------|---------|------|------|---------|
| **shark-panel** | 4 | 11 | 2 | 0 | 1 | 1 | 1 | 0 | **3600** | 1 | **288** | **2543** | 3 |
| diario-das-bruxas | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |
| fabrica | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 54 | 0 |
| iphone | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 |
| shark | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| superadmin-sistema | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

**Power user:** `shark-panel` é responsável por ~95% de toda adoption.
**Sandbox/teste:** `fabrica`, `iphone`, `shark`, `diario-das-bruxas` parecem workspaces de teste.
**Workspace principal Uniflix:** `'00000000-0000-0000-0000-000000000002'` aparece como destinatário de configs (webchat_settings) mas não tem features adoptadas — provavelmente foi renomeado para shark-panel sem atualizar todos lugares.

---

## 🐛 Bugs / débitos críticos consolidados

### 🔴 Prioridade ALTA

1. **Multi-tenant breach IA:** queries `LIMIT 1` sem workspace filter em `ai_provider_settings`.
   - Files: `app/api/ai/agent-chat/route.ts:23`, `app/api/ai/assistant/route.ts:62`, `app/api/ai/generate-followup/route.ts:33`, `app/api/ai-studio/chat/route.ts:11`, `app/api/sales-brain/process/route.ts:31`.

2. **Cron drip-campaigns coluna inexistente:** `payload_json` em `jobs.payload`. (`app/api/cron/drip-campaigns/route.ts:118`)

3. **Pipeline.ts pode não estar conectado:** 2600 opps, 0 won/lost. Investigar handler de payment webhook.

4. **workspace_subscriptions de shark-panel vencendo HOJE (2026-04-29).** Sem cron de cobrança automática.

5. **pgvector não instalado** mas schema sugere RAG vetorial.

### 🟡 Prioridade MÉDIA

6. **3 níveis de blacklist** sem unificação (`followup_blacklist`, `contact_blacklist`, `global_blacklist`). Risco de bypass.

7. **Schemas duplicados:** `customer_journey` (8k rows) vs `sales_opportunities` (2.6k) com stages diferentes.

8. **Tabelas de log nunca instrumentadas:**
   - `automation_executions` (0 rows)
   - `automation_execution_logs` (0 rows)
   - `automation_step_logs` (0 rows)
   - `journey_events` (2 rows), `journey_insights` (0)
   - `sales_brain_insights` (0 — endpoint cria via DDL runtime!)
   - `workspace_ai_usage` (0 — token tracking quebrado)
   - `ai_agent_logs` (0)
   - `ai_agent_conversations` (0)
   - `follow_up_log` (0 — cron rodando à toa)

9. **Sessões órfãs:**
   - `automation_flow_sessions`: 112 active em flows pausados
   - `guided_funnel_sessions`: 58 active em funis inativos
   - Sem cron de cleanup.

10. **`ai_suggestions_log: 7866 rows com was_accepted=null/false em todas`** — UI não fecha o feedback loop.

11. **`ai_writing_agents` sem workspace_id** — agentes globais editáveis por qualquer cliente.

12. **`text_triggers` (0 rows) e `funnels` legacy + tabelas relacionadas** — candidatos a DROP.

### 🟢 Prioridade BAIXA

13. Storage não é problema — todo o universo é <100 MB.
14. Comentários `BUGFIX` no worker indicam fixes recentes (`new_contact` antispam, mimetype, etc.).
15. Nomenclatura inconsistente: `phone` vs `phone_e164`, `payload` vs `payload_json`, `step_id` vs `id`.

---

## 💡 Recomendações urgentes

### 1. Consolidar fluxos de mensagem automática
3 motores principais (worker inbound, cron 1min, cron 15min) executam lógica similar. Se essa convergência for clara, dá pra reduzir 7 features paralelas em 3:
- **Mensagens síncronas** (resposta a inbound) → unificar `automations.intercept` + `automation_triggers` + `guided_funnels` em uma engine só (worker já é).
- **Mensagens com delay curto** (segundos a horas) → `scheduled_messages`.
- **Mensagens periódicas** (event-driven) → `followup_campaigns` + crons (reusar para "drip" e "trial-followup").

Deprecate: `drip_campaigns` (bugado), `funnels legacy` (mover dados pra subscriptions+followup_campaigns), `follow_up_log` (dead).

### 2. Fechar pipeline de vendas
Tornar `lib/sales-brain/pipeline.ts.onPaymentConfirmed()` obrigatoriamente chamado pelo webhook AmploPay. Confirmar que opps fecham para `won` quando há pagamento.

### 3. Instrumentar `workspace_ai_usage`
Mover INSERT/UPDATE para fora do bloco `if (agent.status='active')` — registrar TODAS chamadas IA, mesmo as via REST endpoints (suggest, vision, transcribe, generate-followup, sales-brain/process).

### 4. Cleanup
- DROP `text_triggers`, `automation_executions`, `automation_execution_logs`, `automation_step_logs`, `follow_up_log`, `journey_events`, `journey_insights` se confirmadas como dead-code.
- DELETE 5 knowledge_bases "aa" + órfãs.
- DELETE sessions órfãs (`automation_flow_sessions WHERE flow.status='paused'`, idem guided).

### 5. Segurança
- Criptografar `ai_provider_settings.openai_api_key` etc. (pgcrypto ou KMS).
- Rate limit em `/api/webchat/start` (público).
- Adicionar FK constraints faltando (`webchat_blocked_ips → workspaces`, etc.).

### 6. Documentar widget de webchat
1 sessão real em prod (Luiz Carlos) — quem é? Onde tá rodando? Sem documentação interna disso.

---

## 💰 Custo estimado mensal

| Feature | Storage | CPU | Tokens IA | Total est. |
|---------|---------|-----|-----------|------------|
| Automações | <8 MB | <1% vCPU | 0 | <$1 |
| Guided Funnels | <100 kB | <0.1% | <$1 (geração ad-hoc) | <$2 |
| Drip Campaigns | 0 | 0 | 0 | $0 (bugado) |
| IA (suggest, agents, vision, transcribe) | 25 MB | <2% | $5-15 (estimado) | **$5-15** |
| Knowledge | <300 kB | <0.1% | 0 | $0 |
| Follow-up + Scheduled | 3 MB | <0.5% | 0 | <$1 |
| Webchat + Recorrência | <300 kB | <0.5% | 0 | <$1 |
| Sales Brain | 15 MB | <1% | $1-5 (process) | <$5 |
| ElevenLabs (TTS) | 8 MB | — | $1-3 | <$3 |

**Custo IA hoje:** ~$0/mês (agente IA inactive, process não é cron). Picos quando alguém clica "processar conversas hoje".

**Custo IA potencial se tudo ativado:** $20-50/mês para shark-panel sozinho.

---

## 🎬 Sugestão de próximas ações

1. **🔴 HOJE:** corrigir multi-tenant breach em ai_provider_settings.
2. **🔴 HOJE:** investigar workspace_subscriptions vencendo (shark-panel).
3. **Esta semana:** corrigir bug do drip-campaigns (`payload_json` → `payload`).
4. **Esta semana:** validar pipeline de payment → won/lost.
5. **Próximas 2 semanas:** consolidar 3-4 features paralelas (automation flow, drip, followup → single engine).
6. **Mês:** deletar tabelas dead + sessions órfãs.
7. **Mês:** decidir sobre pgvector (instalar ou drop knowledge_documents/chunks).

---

## 📁 Arquivos gerados (8 + 1 índice)

```
/root/deep-automations.md           ~10 KB
/root/deep-funnels.md                ~12 KB
/root/deep-drip.md                   ~9 KB
/root/deep-ia.md                     ~13 KB
/root/deep-knowledge.md              ~10 KB
/root/deep-followup-scheduled.md     ~12 KB
/root/deep-webchat-recorrencia.md    ~12 KB
/root/deep-sales-brain.md            ~10 KB
/root/DEEP-DIVE-INDEX.md             (este arquivo)
```

Total: ~88 KB de documentação técnica.
