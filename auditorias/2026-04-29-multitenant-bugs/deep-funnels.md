# 🦈 Deep Dive — Funis (Guided Funnels + Sales Funnels legado)

**Escopo:** dois sistemas distintos que compartilham a palavra "funnel":
1. **Guided Funnels** (interactive WhatsApp menu / URA) — `guided_funnels`, `guided_funnel_steps`, `guided_funnel_sessions`. Editado via xyflow no painel `/guided-funnels`.
2. **Sales Funnels (legado IPTV)** — `funnels`, `funnel_stages`, `funnel_contacts`, `funnel_execution_log`. Cron `/api/cron/funnel-processor` processa.

São dois mundos separados sem integração direta.

**TL;DR:**
- Guided: 2 funis em prod, **ambos INATIVOS** (`is_active=false`), 18+11 steps, 59 sessions registradas (58 active+1 transferred).
- Sales legacy: 1 funnel + 5 stages + 1298 funnel_contacts + 6062 execution_logs + 3715 conversation_funnels_sent. **Em uso pesado** (este é o coração do follow-up de trial IPTV).
- 3 templates pré-configurados (Atendimento IPTV, Clínica/Saúde, E-commerce).
- Geração com IA: gpt-4o-mini, prompt fixo no código.

---

## 1. Guided Funnels (WhatsApp menu / URA interativa)

### 1.1 Schema

#### `guided_funnels`
```
id                | uuid PK
workspace_id      | uuid → workspaces(id) CASCADE
name              | varchar(255)
description       | text
trigger_keyword   | varchar(255)         -- legacy single keyword
trigger_keywords  | text[]               -- novo: lista de keywords
is_active         | boolean default false
is_default        | boolean default false  -- fallback se nenhuma keyword bate
channel           | text default 'all'    -- 'all'|'whatsapp'|'webchat'
created_by        | text → nextauth_users
```

#### `guided_funnel_steps`
```
id              | uuid PK
funnel_id       | uuid → guided_funnels(id) CASCADE
step_key        | varchar(100) NOT NULL  -- ex: 'welcome', 'celular_android'
parent_step_key | varchar(100)
step_order      | integer
content         | jsonb                  -- ver shape abaixo
position_x      | double precision        -- xyflow node position
position_y      | double precision
is_disabled     | boolean
UNIQUE (funnel_id, step_key)
```

**Shape do `content`:**
```json
{
  "text": "Olá! 👋 Em qual dispositivo?",
  "image_url": null,
  "video_url": null,
  "audio_url": null,
  "document_url": null,
  "image_with_text": false,           // image como caption do text?
  "options": [
    { "key": "1", "label": "📱 Celular", "next_step": "celular_android", "action": "" },
    { "key": "2", "label": "📺 TV", "next_step": "tvbox" }
  ],
  "free_input": false,                 // aceitar texto livre em vez de opção
  "action": null,                      // ação ao chegar (transfer_to_human, generate_trial, etc)
  "goto_step": null,                   // pular para step (com action=goto_step)
  "timeout_seconds": 300,
  "timeout_message": "Ainda precisa de ajuda? Digite menu para recomeçar.",
  // Novo formato (sequência):
  "items": [
    { "type": "message", "text": "Pague via PIX:", "delay_seconds": 0 },
    { "type": "pix", "amount_cents": 990 },
    { "type": "checkout", "amount_cents": 990, "text": "Ou cartão:" }
  ]
}
```

#### `guided_funnel_sessions`
```
id                  | uuid PK
funnel_id           | uuid → guided_funnels(id) CASCADE
conversation_id     | uuid                  -- NULL para sessões webchat antes de conversar
contact_id          | uuid
workspace_id        | uuid → workspaces(id) CASCADE
current_step_key    | varchar(100) default 'welcome'
status              | varchar(20)            -- CHECK: active|completed|transferred|timeout|cancelled
started_at          | timestamptz
last_interaction_at | timestamptz
metadata            | jsonb                  -- ex: {"device":"tvbox"}
```

#### `guided_funnel_templates`
```
id          | uuid PK
name        | varchar(255)
icon        | varchar(10)    -- emoji
description | text
color       | varchar(50)
steps       | jsonb          -- array de steps no shape acima
```

### 1.2 Estado prod

```
shark-panel:
  Atendimento IPTV - Uniflix    | inactive | trigger_keywords=[teste gratis, trial gratis,...] | channel=webchat | 18 steps | 59 sessions
  Funil IA - Faltou botão...    | inactive | trigger_keyword=menu                              | channel=all     | 11 steps | 0  sessions
```

Sessions: 58 `active` + 1 `transferred`. **Os 58 active são órfãos** (funis inactive não disparam nem expiram).

Step content em prod:
| Campo | Steps com valor |
|-------|-----------------|
| text  | 27 |
| audio_url | 0 |
| image_url | 1 |
| video_url | 0 |
| document_url | 0 |
| options (≥1) | 23 |
| free_input | 0 |
| action | 3 |

Ações usadas: `end_conversation` (1), `generate_trial` (1), `transfer_to_human` (1), null (26).

Templates em prod:
| Template | Icon | Steps |
|----------|------|-------|
| Atendimento IPTV | 📺 | 10 |
| Clínica / Saúde  | 🏥 | 5 |
| E-commerce / Loja | 🛒 | 5 |

### 1.3 API

| Rota | Arquivo | Função |
|------|---------|--------|
| `GET/POST /api/guided-funnels` | route.ts | List/create |
| `GET/PUT/DELETE /api/guided-funnels/[id]` | [id]/route.ts | CRUD |
| `GET/POST /api/guided-funnels/[id]/steps` | [id]/steps/route.ts | Steps |
| `PUT/DELETE /api/guided-funnels/[id]/steps/[stepId]` | individual step CRUD |
| `PUT /api/guided-funnels/[id]/positions` | positions/route.ts | Salva position_x/y do xyflow |
| `POST /api/guided-funnels/[id]/simulate` | simulate/route.ts (77 lin.) | Simulação para teste |
| `GET /api/guided-funnels/[id]/export` | export | Dump JSON do funnel |
| `POST /api/guided-funnels/import` | import | Importar JSON |
| `GET /api/guided-funnels/templates` | templates/route.ts | Lista templates |
| `POST /api/guided-funnels/templates/install` | templates/install/route.ts:51 | Cria funnel a partir do template |
| `POST /api/guided-funnels/generate-ai` | generate-ai/route.ts:126 | **Gera via OpenAI** |

### 1.4 Editor visual (xyflow/react)

`app/(dashboard)/guided-funnels/[id]/page.tsx` (1229 linhas):
- Imports `@xyflow/react ^12.10.2`, `Node`, `Edge`, `Connection`.
- Renderiza cada step como **Node** posicionado em (`position_x`, `position_y`).
- Edges derivados de `options[].next_step` + `parent_step_key`.
- Save: PUT `/positions` (apenas coordenadas) ou PATCH no step (conteúdo).
- Auto-layout opcional (não confirmado).

### 1.5 Geração com IA

`/api/guided-funnels/generate-ai` (126 linhas):
- Lê `ai_provider_settings.openai_api_key` do workspace.
- Modelo: **gpt-4o-mini**, max_tokens=3000, temperature=0.7.
- Prompt fixo (em PT-BR) instrui formato JSON, regras (welcome obrigatório, actions disponíveis, opção "Voltar" em sub-menus, 8-15 steps).
- Após resposta, parseia JSON, cria `guided_funnels` + `guided_funnel_steps` em transação.
- **Funnel criado com `is_active=false`** — usuário precisa ativar.

### 1.6 Fluxo E2E (em runtime)

Toda lógica de execução está no **worker** (`apps/worker/src/worker.ts`), função `handleGuidedFunnel`:

```
inbound message → process_webhook job
↓
[Priority 1] handleGuidedFunnel(activeSessionOnly=true)
  └─ SELECT FROM guided_funnel_sessions WHERE conversation_id=... AND status='active'
     └─ Se existe: processa input atual

[Priority 3] handleGuidedFunnel(activeSessionOnly=false)
  └─ Procura keyword match em guided_funnels (trigger_keyword OR trigger_keywords[])
     └─ Cria session com current_step_key='welcome'
     └─ sendGuidedFunnelStep('welcome')
```

**Detecção de keyword (worker.ts:2789-2806):**
```sql
WITH matched AS (
  SELECT *, 
    (trigger_keyword IS NOT NULL AND $text LIKE '%' || LTRIM(trigger_keyword,'/') || '%') AS kw_hit,
    EXISTS (SELECT 1 FROM unnest(COALESCE(trigger_keywords,'{}'::text[])) kw 
            WHERE $text LIKE '%' || LTRIM(kw,'/') || '%') AS kws_hit
  FROM guided_funnels
  WHERE workspace_id=$1 AND is_active=true 
    AND (channel='all' OR channel=$3)
)
SELECT * FROM matched WHERE kw_hit OR kws_hit OR is_default=true
ORDER BY (kw_hit OR kws_hit) DESC LIMIT 1
```

Strip leading slash: `/menu` e `menu` matched igual.

**Processamento de input** (worker.ts:2880+):
1. Busca step atual.
2. Match input contra `options[].key` ou `options[].label` (lowercase).
3. Sem match: re-envia menu com "❌ Opção inválida".
4. Match com `action`: executa
   - `transfer_to_human`: status='transferred', `conversations.ai_mode='off'`
   - `end_conversation`: status='completed'
   - `activate_ai`: status='completed', `conversations.ai_mode='autonomous'` (deixa AI assumir)
   - `search_knowledge`: SELECT em `knowledge_items` (full-text + keywords array), envia 1 resultado
   - `goto_step`: pula para step específico
   - `generate_trial`: enfileira job `process_guided_funnel` (worker.ts:4307)
5. Sem action: avança para `next_step`. Auto-tag de device em `metadata.device` se step_key matchear (`celular_android`, `tvbox`, `firestick`, `iphone`, `smart_tv`).

**Envio de step** (`sendGuidedFunnelStep`, worker.ts:3036):
- Se `content.items[]`: envia em sequência (message/pix/checkout) com delays.
- Senão: text + image (caption ou separado) + audio + video + document.
- Usa Evolution API: `sendText`, `sendMedia`, `sendWhatsAppAudio`.

### 1.7 Job `process_guided_funnel`

Disparado quando step tem `action='generate_trial'`. Worker handler (worker.ts:4307+):
- Cria trial IPTV (chamada para Sigma/Megabox).
- Persiste em `iptv_trials`.
- Agenda 2 follow-ups (jobs `send_followup_trial`).

---

## 2. Sales Funnels (legado IPTV)

### 2.1 Schema

#### `funnels`
```
id            | uuid PK
workspace_id  | uuid (default '00000000-...001' = superadmin)
name          | text
description   | text
status        | text default 'active'
is_active     | boolean
is_auto       | boolean default false
trigger_event | varchar(100) default 'manual'
```

#### `funnel_stages`
```
id, funnel_id, name, stage_order, color
automation_id   | uuid → automations(id)  -- opcional, link cruzado!
delay_minutes   | integer
message_template| text
auto_send       | boolean
trigger_type    | varchar(50)             -- 'delay'|...
is_active       | boolean
pix_config      | jsonb
checkout_config | jsonb
audio_config    | jsonb
```

#### `funnel_contacts` (1298 rows)
```
id, funnel_id, stage_id, contact_id, phone, status (active|completed|...)
current_stage_id, next_action_at, enrolled_at, completed_at, trial_id (FK iptv_trials)
```

#### `funnel_execution_log` (6062 rows)
```
funnel_id, stage_id, contact_id, phone, action, message_sent, status, error_message, executed_at
```

#### `conversation_funnels_sent` (3715 rows)
Log de quando um agente disparou um trigger no inbox: `(conversation_id, trigger_id, trigger_name, fired_by_user_id, fired_at)`.

#### `sales_funnel_config` (6 rows)
Stages do "kanban de vendas" (configurável por workspace, separado dos funnels acima).

### 2.2 Cron `/api/cron/funnel-processor`

`app/api/cron/funnel-processor/route.ts` (598 linhas), executado **a cada 1 min**:

```
SELECT funnel_contacts WHERE status='active' AND next_action_at <= NOW() LIMIT 20 FOR UPDATE SKIP LOCKED
↓
para cada enrollment:
  Se auto_send=true:
    - pix_config: scheduleFunnelPixMessages (2 mensagens — tabela de planos + chave PIX)
    - checkout_config: scheduleFunnelCheckoutMessage
    - message_template: scheduleFunnelMessage
    → INSERT em scheduled_messages (status='pending')
  ↓
  Avança para próxima stage (UPDATE current_stage_id, next_action_at = NOW() + delay_minutes)
  Se for última stage: status='completed', completed_at=NOW()
  ↓
  INSERT funnel_execution_log
```

**O envio real é feito pelo cron `scheduled-messages`**, não por este. Operador pode cancelar antes do envio na tela `/agendamentos`.

### 2.3 Diferença Guided vs Sales

| Aspecto | Guided Funnels | Sales Funnels |
|---------|---------------|---------------|
| Trigger | Mensagem inbound match keyword | Enrollment manual ou via trigger_event |
| Cadência | Síncrona (resposta imediata) | Assíncrona (delay_minutes entre stages) |
| Estado | `current_step_key` | `current_stage_id` |
| UI | xyflow visual | Lista de stages |
| Engine | Worker (no inbound) | Cron 1min |
| Templates | 3 (DB) | Não tem |
| IA | Geração de funil via gpt-4o-mini | Não |
| Em uso | Não (2 inactive) | Sim (1298 enrollments) |

---

## 3. Bugs / débitos

### 3.1 BUG: 58 sessions órfãs
58 `guided_funnel_sessions` com status=`active` em funnels `is_active=false`. Como funnel não dispara, sessões nunca avançam nem expiram. Bloqueia AI agent (Priority 1 do worker checa active session).

```sql
UPDATE guided_funnel_sessions
SET status='cancelled'
WHERE funnel_id IN (SELECT id FROM guided_funnels WHERE is_active=false)
  AND status='active';
```

### 3.2 BUG: Sales funnels usa workspace_id default '0001' (superadmin)
`funnels.workspace_id` default é `'00000000-0000-0000-0000-000000000001'` — não é multi-tenant correto. Em prod, todas linhas devem estar em workspace específico, mas default sugere bug de migração.

### 3.3 INCONSISTÊNCIA: dois processadores de funil
- Worker (guided): real-time, em mensagem inbound.
- Cron (sales): batch, 1min.

Não conversam. Um funil que precise de "5 minutos depois mande PIX" precisa ser sales legacy. Um funil interativo precisa ser guided. Não dá pra misturar (ex: "responder URA agora, 24h depois mandar follow-up via cron").

### 3.4 BUG: `generate-ai` cria funnel inactive sem aviso ao usuário
Após geração, retorna 201 mas funnel `is_active=false`. UI precisa mostrar claramente "Funil gerado em rascunho - ativar manualmente".

### 3.5 BUG: tabela `conversation_funnels_sent` cresce sem retenção (3715 rows, 1 ano de dados)
Não há cleanup. Pequeno (~500kB), mas degrada index ao longo do tempo.

### 3.6 BUG: `funnel_execution_log` 6062 rows sem retenção
Idem.

### 3.7 BUG: `step_id` nos pares (funnel_id, step_key)
Step lookup feito sempre por (funnel_id, step_key) — não por id. PK uuid `id` é redundante para esta tabela. Não é crítico mas adiciona um índice desnecessário.

### 3.8 BUG: Search knowledge dentro de funnel é raso
`action='search_knowledge'` faz `ILIKE '%term%'` simples — sem RAG, sem ranking. Se `knowledge_items.is_active=false`, ignorado.

### 3.9 INCONSISTÊNCIA: `trigger_keyword` (singular) vs `trigger_keywords` (array)
Banco tem ambos. Worker checa os dois (OR), mas UI provavelmente edita apenas um. Migrar tudo para array.

---

## 4. Custos estimados

### Storage
- `guided_funnels` (2) + `guided_funnel_steps` (29) + `guided_funnel_templates` (3): <100 kB.
- `guided_funnel_sessions` (59): ~10 kB.
- `funnel_contacts` (1298) + `funnel_execution_log` (6062): ~3-5 MB.
- `conversation_funnels_sent` (3715): ~500 kB.

**Total: <10 MB.**

### CPU
- Worker: 1 query por inbound (`SELECT FROM guided_funnels WHERE...`). Custo <1ms.
- Cron funnel-processor: 1× por minuto, batch de 20. SKIP LOCKED. Custo desprezível.

### Tokens IA
- `generate-ai`: gpt-4o-mini ~3000 max_tokens/request × volume (manual, raro). Custo $0.15/1M input + $0.60/1M output. **<$1/mês**.
- `search_knowledge` action: SQL puro, sem IA.

**Custo total: <$5/mês mesmo com uso pesado de geração.**

---

## 5. Fluxo E2E — exemplo: cliente envia "/menu"

```
1. Evolution webhook → POST /api/webhooks/evolution → INSERT jobs(type='process_webhook')
2. Worker pega job
3. handleProcessWebhook → processAutomaticTriggers (vê triggers de keyword)
4. Priority 1: handleGuidedFunnel(activeSessionOnly=true)
   → 0 sessões active → return false
5. Priority 2: handleFlowInterception (automations)
   → 0 active → return false
6. Priority 3: handleGuidedFunnel(activeSessionOnly=false)
   → strip slash: 'menu'
   → SQL: SELECT * FROM guided_funnels WHERE workspace='shark' AND active=true AND (kw_hit OR kws_hit)
   → match: 'Funil IA - ...' (mas inactive em prod, então fallback default — também none)
   → return false
7. Priority 4: handleAIAgentResponse
```

Como ambos funis estão inactive, mensagem cai no AI agent (se configurado) ou nada acontece.

---

## 6. Resumo executivo

1. **Guided funnels prontos mas dormindo:** 2 funis criados, ambos inativos. **Decisão: ativar `Atendimento IPTV - Uniflix` ou desistir.**
2. **Sales legacy é o motor real do follow-up de trial:** 1298 enrollments ativos, cron batendo de minuto em minuto. **Não mexer sem cuidado.**
3. **Editor xyflow é robusto** (1229 linhas em uma page) mas pesado — pode ser oportunidade de refatorar em sub-componentes.
4. **Geração de IA é barata** mas não diferenciada. Usa gpt-4o-mini com prompt fixo. Pode-se elevar para gpt-4o ou customizar prompt por workspace.
5. **Sessions órfãs (58) precisam de cleanup** semanal. Adicionar cron.
