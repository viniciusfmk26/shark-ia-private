# 🦈 Deep Dive — Sales Brain

**Escopo:** dashboard de vendas com IA — pipeline visual, churn risk, oportunidades, journey de cliente, extração de credenciais. 14 endpoints em `/api/sales-brain/*`. Tabelas: `sales_opportunities`, `sales_events`, `sales_brain_insights`, `sales_funnel_config`, `customer_journey`, `journey_events`, `journey_insights`, `app_problems_learned`. Base de dados: `conversation_analysis` (8.864 conversas) + `conversation_knowledge` (9.190).

**TL;DR:**
- Sistema **maduro e populado:** 2.600 oportunidades de venda, 2.636 sales_events, 8.219 contatos no customer_journey.
- **Dois sistemas de "journey" coexistem:** `sales_opportunities` + `sales_events` (mais novo) e `customer_journey` + `journey_events` (mais antigo, agora com 2 events apenas).
- 18 `app_problems_learned` catalogados (FAQ-ish para problemas IPTV).
- **`sales_brain_insights` 0 rows** — endpoint `/process` cria-os mas ninguém disparou em prod.
- **0 oportunidades won/lost** — pipeline tá só populando, sem ninguém marcando o resultado final.
- Page UI gigante: `app/(dashboard)/sales-brain/page.tsx` (2.119 linhas).

---

## 1. Schema das tabelas core

### 1.1 `sales_opportunities` (2.600 rows)
```
id, workspace_id, conversation_id (FK CASCADE) UNIQUE
contact_id (FK), contact_name, contact_phone
detected_plan, estimated_value_cents
stage default 'lead'                  -- lead|qualified|trial|negotiation|won|lost
lead_score (0-100)
source                                -- detection origin
stage_changed_at, won_at, lost_at, lost_reason
```

### 1.2 `sales_events` (2.636 rows)
```
workspace_id, conversation_id (FK CASCADE), contact_id, opportunity_id (FK CASCADE)
event_type (text NOT NULL)
description
metadata (jsonb)
```

Event types em prod:
| event_type | count |
|------------|-------|
| trial_requested | 1494 |
| interest_detected | 1085 |
| auto_analyzed | 38 |
| churn_signal | 19 |

### 1.3 `sales_brain_insights` (0 rows)
```
workspace_id, conversation_id UNIQUE (partial WHERE NOT NULL)
contact_phone, contact_name
sentiment (varchar(20)), intent (varchar(50))
summary, tags text[]
opportunity (text)
churn_risk (int 0-100)
next_action (text)
raw_analysis (jsonb)
```

Endpoint `/process` cria (CREATE TABLE IF NOT EXISTS na linha 124!), mas ninguém ainda rodou em prod.

### 1.4 `sales_funnel_config` — kanban stages config (6 rows)
```
workspace_id, stage_key, stage_name, stage_order, color
auto_move_rules (jsonb)
UNIQUE (workspace_id, stage_key)
```

Em prod:
| stage_key | stage_name | order | color |
|-----------|------------|-------|-------|
| lead | Lead | 1 | #8b5cf6 |
| qualified | Qualificado | 2 | #3b82f6 |
| trial | Em Teste | 3 | #f59e0b |
| negotiation | Negociacao | 4 | #f97316 |
| won | Convertido | 5 | #10b981 |
| lost | Perdido | 6 | #ef4444 |

### 1.5 `customer_journey` (8.219 rows aprox.)
```
workspace_id, contact_id NOT NULL
stage default 'new'
  -- CHECK: new|trial|negotiating|objection|closing|converted|lost|churned
previous_stage, score
first_contact_at, last_interaction_at, converted_at, lost_at, lost_reason
metadata (jsonb)
UNIQUE (workspace_id, contact_id)
```

Distribuição:
| stage | count |
|-------|-------|
| new | 6116 |
| negotiating | 1213 |
| closing | 599 |
| converted | 272 |
| trial | 22 |

⚠️ **Stages não batem com `sales_funnel_config`!** customer_journey usa `negotiating` e `closing`, sales_funnel_config tem `qualified` e `negotiation`. **Schema duplicado e inconsistente.**

### 1.6 `journey_events` (2 rows) — basicamente vazia
### 1.7 `journey_insights` (0 rows)

### 1.8 `app_problems_learned` (18 rows)
```
workspace_id, category, problem, solution
keywords text[] GIN index
times_detected, times_resolved, success_rate (3,2)
last_detected_at, source default 'manual'
is_active, metadata
UNIQUE (workspace_id, problem)
```

18 problemas catalogados. Funciona como FAQ contextual para o sales brain.

---

## 2. Endpoints (14 rotas, 1842 linhas)

| Rota | Linhas | Função |
|------|--------|--------|
| `GET /api/sales-brain/dashboard` | 168 | KPIs gerais |
| `GET /api/sales-brain/overview` | 169 | Stage counts + recent events + insights + problems |
| `GET /api/sales-brain/opportunities` | 130 | List sales_opportunities filtered by stage |
| `GET /api/sales-brain/funnel` | 72 | Funnel chart (counts por stage) |
| `GET /api/sales-brain/timeline` | 49 | Timeline de eventos |
| `GET /api/sales-brain/journeys` | 63 | List customer_journey |
| `GET /api/sales-brain/graph` | 233 | **Grafo de relacionamento** (contacts × topics) |
| `GET /api/sales-brain/churn-risk` | 152 | Contatos com plano expirando 14d |
| `GET /api/sales-brain/insights` | 93 | Aggregated stats from conversation_analysis |
| `GET /api/sales-brain/problems` | 95 | List app_problems_learned + counts |
| `GET /api/sales-brain/credentials` | 70 | Lista credenciais IPTV extraídas |
| `POST /api/sales-brain/extract-credentials` | 157 | **Extrai credenciais de mensagens via regex** |
| `GET /api/sales-brain/live-feed` | 50 | Stream de eventos em tempo real |
| `POST /api/sales-brain/process` | 341 | **Roda gpt-4o-mini sobre conversas do dia, popula sales_brain_insights** (streaming response) |

### 2.1 `/api/sales-brain/process` (341 linhas)

```
1. Auth
2. Get AI settings (LIMIT 1 — bug multi-tenant ver Area 4)
3. SELECT conversations com messages hoje LIMIT 50
4. CREATE TABLE IF NOT EXISTS sales_brain_insights (no runtime!)
5. Para cada conv:
   - Get last 20 messages
   - callAI com ANALYSIS_PROMPT pedindo JSON com 7 campos
   - INSERT/UPDATE sales_brain_insights ON CONFLICT (conversation_id)
6. Stream response (NDJSON)
```

System prompt:
```
Você é um analista de vendas especializado em IPTV...
JSON com sentiment, intent, summary, tags, opportunity, churn_risk (0-100), next_action
```

⚠️ **DDL em runtime** (CREATE TABLE IF NOT EXISTS) é anti-pattern do CLAUDE.md ("Não rodar ALTER TABLE em produção via código").

### 2.2 `/api/sales-brain/extract-credentials` (157 linhas)

Regex puro sobre `messages.text`:
```ts
PATTERNS = {
  username: /(?:Usu[aá]rio|User|Login)\s*[:\-=]\s*(\S+)/i,
  password: /(?:Senha|Password|Pass)\s*[:\-=]\s*(\S+)/i,
  dns_url:  /(?:DNS|URL|Server|...)\s*[:\-=]\s*(https?:\/\/\S+)/i,
  expiration: /(?:Vencimento|Expira(?:ção|tion)?|...)/i,
}
```

Detecta tipo (trial/renewal/mensal/anual/semestral/trimestral) por keywords.

Não usa IA — regex puro. Salva em tabela específica (provavelmente `iptv_credentials_extracted`, não confirmei).

### 2.3 `/api/sales-brain/churn-risk` (152 linhas)

```sql
SELECT contacts WHERE
  workspace_id = $1
  AND plan_expires_at IS NOT NULL
  AND plan_expires_at > NOW() - 3 days   -- já churned há mais de 3d, exclui
  AND plan_expires_at < NOW() + 14 days   -- vence até 14d
LIMIT 100
```

Para cada contato calcula churn_risk score baseado em:
- Tempo desde last_message_at
- Total de pagamentos confirmados
- Próximo do vencimento

### 2.4 `/api/sales-brain/graph` (233 linhas)

**Grafo de conexões** entre contacts e topics (`conversation_knowledge.topics[]`):
- Nodes: contacts + topics distintos.
- Edges: contact → topic se conversation_knowledge tem aquele topic.

Possivelmente renderizado como force-directed graph no UI (D3, etc.).

---

## 3. Lib: `lib/sales-brain/pipeline.ts` (127 linhas)

**Auto-move logic** chamado por webhooks:

| Função | Disparada por | Efeito |
|--------|--------------|--------|
| `onPaymentConfirmed(workspaceId, conversationId, contactId, amount)` | Webhook AmploPay | UPDATE opp.stage='won', INSERT sales_event 'payment_received' |
| `onTrialCreated(workspaceId, conversationId, contactId, contactName)` | Trial generation | UPDATE opp.stage='trial', INSERT sales_event 'trial_created' |
| (provavelmente outras: onChurnSignal, onTicketResolved...) | | |

Esses **events estão sendo populados** (2.636 rows), então o pipeline está integrado nos pontos de venda do sistema.

---

## 4. Estado em prod

```
sales_opportunities:    2600 (1494 trial, 640 qualified, 466 lead, 0 won, 0 lost)
sales_events:           2636
sales_brain_insights:      0
sales_funnel_config:       6
customer_journey:       ~8.2k rows (multi-stage)
journey_events:            2
journey_insights:          0
app_problems_learned:     18
```

**Contradição interessante:**
- `customer_journey` mostra **272 converted, 0 lost**.
- `sales_opportunities` mostra **0 won, 0 lost**.

Os dois sistemas reportam realidades diferentes. `customer_journey` parece ser populado por algum trigger/cron, enquanto `sales_opportunities` é populado pelos pipeline.ts handlers.

Ninguém na equipe está marcando opps como "won"/"lost" manualmente — todos ficam em lead/qualified/trial perpetuamente.

---

## 5. UI

`app/(dashboard)/sales-brain/page.tsx` (2.119 linhas, **uma das maiores pages do sistema**):
- Múltiplas tabs: Pipeline (kanban), Insights, Journeys, Churn, Graph, Problems, Live Feed, Credentials.
- Renderização do funnel-chart, kanban drag-drop entre stages.
- Live feed via polling (não SSE).

---

## 6. Fluxo E2E

### Caso 1: Cliente envia "quero comprar plano anual"
```
1. Inbound message → process_webhook (worker)
2. Worker (priority 4): handleAIAgentResponse → 0 (agent inactive)
3. Conversa fica como está, sem ação automática

DEPOIS (admin abre /sales-brain):
4. Click "Processar conversas hoje"
5. Frontend POST /api/sales-brain/process
6. Endpoint roda gpt-4o-mini sobre cada conv (até 50)
7. Para a conv em questão, IA detecta:
   {sentiment:'positive', intent:'buy', tags:['anual','plano'], opportunity:'cliente quer plano anual'}
8. INSERT sales_brain_insights ON CONFLICT UPDATE
9. Frontend exibe stream de progresso
```

### Caso 2: Trial criado para a conversa
```
1. Worker process_guided_funnel job → cria iptv_trial
2. Code chama lib/sales-brain/pipeline.ts onTrialCreated()
3. UPDATE sales_opportunities SET stage='trial' WHERE conversation_id=$1
4. INSERT sales_events (event_type='trial_requested')
5. Aparece no funnel kanban como "Em Teste"
```

### Caso 3: Pagamento confirmado
```
1. AmploPay webhook → /api/webhooks/amplopay
2. Update payments.status='confirmed'
3. Calls onPaymentConfirmed(workspace, conv, contact, amount)
4. UPDATE sales_opportunities SET stage='won', won_at=NOW()
5. INSERT sales_events (event_type='payment_received')
```

⚠️ Mas **0 won/lost em prod** — sugere que ou:
- Webhook nunca chama `onPaymentConfirmed`, ou
- Confirmação de pagamento não está chegando para criar opps no momento certo (só depois que conv termina).

---

## 7. Bugs / débitos

### 7.1 🔴 BUG: 0 won/lost — pipeline.ts não está sendo invocado
2.600 opps mas nenhuma fechada. Verificar:
```bash
grep -rn "onPaymentConfirmed\|onTrialCreated" app/api lib worker.ts
```

Se webhooks de payment NÃO chamam `onPaymentConfirmed`, opps nunca evoluem.

### 7.2 BUG: Schema duplicado `customer_journey` vs `sales_opportunities`
Stages diferentes:
- customer_journey: new|trial|negotiating|objection|closing|converted|lost|churned
- sales_opportunities: lead|qualified|trial|negotiation|won|lost

Schemas inconsistentes. **Decisão: consolidar em uma só tabela.**

### 7.3 BUG: `journey_events: 2 rows`, `journey_insights: 0 rows`
customer_journey tem 8k rows mas events e insights estão vazios. Sugere que o sistema antigo (`customer_journey`) parou de receber eventos quando o novo (`sales_*`) entrou. Migrar dados ou deprecate o antigo.

### 7.4 BUG: `/process` cria tabela em runtime (CREATE TABLE IF NOT EXISTS)
Anti-pattern. Migration deveria fazer isso. Verificar migration `0xxx_sales_brain_insights.sql`.

### 7.5 BUG: `/process` tem mesmo bug multi-tenant que outras AI routes
`SELECT openai_api_key FROM ai_provider_settings LIMIT 1` (linha 31) — sem WHERE workspace_id.

### 7.6 BUG: `extract-credentials` regex pode ser bypassed por cases especiais
Senha "123 (com espaço)" não matcha por `\S+`. URLs com espaços encoded também falham.

### 7.7 BUG: `app_problems_learned` cresce só manualmente
Coluna `source` default 'manual'. Não há cron que detecta problemas comuns automaticamente. 18 rows após meses de operação sugere baixa adoption.

### 7.8 BUG: `live-feed` faz polling, não SSE
50 linhas — provavelmente retorna últimas N events. Cliente faz fetch a cada X seg. Nada de WebSocket/SSE/long-polling.

### 7.9 BUG: `sales_opportunities` UNIQUE(conversation_id) pode bloquear casos legítimos
Cliente que tem 2 oportunidades distintas na mesma conversa (raras, mas existem) — bloqueado por constraint.

### 7.10 BUG: contagem por workspace em endpoints provavelmente conta dados de outros workspaces
Não confirmei mas `/insights`, `/problems`, etc. fazem JOIN. Se algum INNER JOIN cross-workspace existir, bug de privacidade.

---

## 8. Custos

### Storage
- sales_opportunities: 2600 × ~500B ≈ 1.3 MB
- sales_events: 2636 × ~300B ≈ 800 kB
- customer_journey: 8.2k × ~400B ≈ 3 MB
- conversation_analysis (consumo): 8.8k × ~500B ≈ 4 MB
- conversation_knowledge: 9.2k × 700B ≈ 6 MB

**Total: ~15 MB.**

### CPU
- /process: pesado (até 50 conversas × 1 OpenAI call ≈ 30-90s).
- /graph: pesado (cross-join contacts × topics).
- Outros: leves.

### Tokens IA
- /process: 50 convs × ~3000 tokens = 150k tokens × $0.15/1M ≈ $0.05/run.
- Se rodar 1×/dia × 30 dias = $1.5/mês.

**Custo total estimado: $5-15/mês se sales-brain for usado intensivamente.**

---

## 9. Resumo executivo

1. **Sistema rico em dados, pobre em closing:** 2.600 opps mas 0 won/lost. **Pipeline.ts handlers não estão sendo chamados nos webhooks.**
2. **Dois "journey" sistemas duplicam:** customer_journey (8k) vs sales_opportunities (2.6k). Consolidar.
3. **/process** é endpoint manual (admin clica botão) — não há automação para gerar insights diariamente.
4. **app_problems_learned** subutilizada (18 rows, manual).
5. **UI é gigante** (2.119 linhas) — oportunidade de refatorar em sub-páginas/componentes.
6. **/extract-credentials regex** é simples mas serve. Vulnerável a edge cases.
7. **Webhook AmploPay** provavelmente não chama `onPaymentConfirmed` — verificar e corrigir para fechar pipeline.
