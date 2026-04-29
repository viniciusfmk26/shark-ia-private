# 🦈 Deep Dive — Automações (triggers, intercept flows, quick triggers)

**Escopo:** tabela `automations`, `automation_triggers`, `text_triggers`, `quick_trigger_config`, e o pipeline do worker que detecta gatilhos em mensagens inbound.

**TL;DR:**
- A área tem **3 sistemas paralelos** mal-definidos: (1) `automations` + `automation_steps` (intercept flows), (2) `automation_triggers` (texto/áudio/imagem como gatilho), (3) `text_triggers` (LEGADO, **0 rows em prod, deprecado**).
- Em prod: **4 automations** (todas `paused`), **11 automation_triggers ativos**, **189 quick_trigger_config**, **482 sessions** acumuladas (273 `expired` + 112 `active` + 97 `agent_replied`).
- Não há logs em `automation_execution_logs` (0 rows) — o sistema novo de logging nunca foi usado. O caminho de execução real é via tabela `jobs` (send_message com `payload.trigger_id`).
- Adoption está concentrada em **shark-panel**. Uniflix (workspace principal) não usa nada disso ainda.

---

## 1. Schema completo

### 1.1 `automations` — fluxo "intercept" (auto-resposta com sessão)

```
Column                    | Type       | Default
--------------------------|------------|--------
id                        | uuid PK    | gen_random_uuid()
workspace_id              | uuid       | NOT NULL
name                      | text       | NOT NULL
description               | text       |
status                    | text       | 'draft'   -- draft|active|paused|inactive
trigger_type              | text       | NOT NULL  -- valor em prod: 'any_message'
trigger_config            | jsonb      | '{}'
version                   | integer    | 1
last_published_at         | timestamptz|
intercept_instance_id     | uuid       |           -- limita a 1 instância WhatsApp
intercept_trigger_type    | varchar(30)| 'manual'  -- manual|any_message|first_message|keyword
intercept_mode            | boolean    | false     -- bloquear AI/funil quando intercept dispara
intercept_keywords        | text       | ''        -- CSV de keywords
re_trigger_enabled        | boolean    | false
re_trigger_delay_seconds  | integer    | 60
escape_keyword            | varchar(50)| '1'
escape_action             | varchar(30)| 'transfer_human'  -- transfer_human|activate_ai
schedule_enabled          | boolean    | false
schedule_start            | time       | '00:00'
schedule_end              | time       | '23:59'
schedule_timezone         | varchar(50)| 'America/Sao_Paulo'
created_by                | text       | FK nextauth_users
```

FKs OUT: `created_by → nextauth_users(id)`.
FKs IN: cascade delete em `automation_steps`, `automation_triggers`, `automation_executions`, `automation_execution_logs`, `automation_step_logs`, `automation_flow_sessions`, `funnel_stages`.

### 1.2 `automation_steps` — passos do flow

```
id            | uuid PK
automation_id | uuid → automations(id) ON DELETE CASCADE
step_order    | integer NOT NULL
type          | text NOT NULL          -- ÚNICO valor em prod: 'send_message'
config        | jsonb                   -- {message, text, media_url, delay_value, delay_unit}
deleted_at    | timestamptz
step_id       | uuid                    -- ID interno duplicado (uuid_generate_v4)
media_type    | varchar(20)
media_url     | text
media_id      | uuid
```

### 1.3 `automation_triggers` — gatilhos standalone (NÃO ligados a flow obrigatoriamente)

```
id            | uuid PK
name          | text NOT NULL
type          | text NOT NULL  -- valores em prod: 'keyword' (8), 'trigger' (3)
config        | jsonb          -- {contents:[{type:'text|audio|image|document', media_id, text, delay_value, delay_unit}], keyword, ignore_case, is_text_trigger:true}
automation_id | uuid           -- pode ser NULL (gatilho standalone)
workspace_id  | uuid
is_active     | boolean
created_by    | text FK
```

⚠️ **Confusão de nomenclatura:** A coluna `type` aqui não é o "tipo de mensagem" — é o **modo de detecção**:
- `keyword`: dispara quando texto da mensagem contém `config.keyword`
- `trigger` (alias usado pelo `text-triggers` API): dispara manualmente, marcado por `config.is_text_trigger=true`
- `new_contact`: dispara na primeira mensagem (suportado no worker mas **0 rows em prod**)

### 1.4 `text_triggers` — **DEPRECATED, 0 rows em prod**

```
id            | uuid PK
workspace_id  | uuid → workspaces(id) ON DELETE CASCADE
name          | text NOT NULL
message       | text NOT NULL
is_active     | boolean
sort_order    | integer
```

A API `/api/automations/text-triggers/route.ts` **não usa esta tabela** — escreve em `automation_triggers` com `config.is_text_trigger=true`. A tabela foi mantida como artefato. **Recomendação: DROP.**

### 1.5 `quick_trigger_config` — pin/sort de gatilhos no inbox

```
id            | uuid PK
workspace_id  | uuid → workspaces(id) ON DELETE CASCADE
trigger_type  | text   -- CHECK: ('audio'|'image'|'document'|'automation')
reference_id  | uuid   -- aponta para automation_media OU automation_triggers
label, icon, color, sort_order, is_favorite, is_visible
UNIQUE (workspace_id, trigger_type, reference_id)
```

Não é uma tabela de gatilhos — é só o **layout/pin** dos botões de envio rápido na UI do inbox.

### 1.6 `automation_executions` (legado, 0 rows) e `automation_execution_logs` (0 rows)

Tabelas de logging projetadas mas nunca instrumentadas pelo worker. O worker enfileira jobs em `jobs` mas não escreve em `automation_execution_logs`. **Toda observabilidade hoje é por logs do worker (`[Worker] trigger_fired ...`)**.

### 1.7 `automation_flow_sessions` — estado por conversa

```
id                  | uuid PK
flow_id             | uuid → automations(id) CASCADE
conversation_id     | uuid NOT NULL
contact_phone       | varchar(50)
workspace_id        | uuid
status              | varchar(20) -- 'active'|'expired'|'agent_replied'|'escaped'
last_triggered_at   | timestamptz
trigger_count       | integer
UNIQUE (flow_id, conversation_id)
```

### 1.8 `automation_media` — biblioteca de mídia (audio/image/document)

```
id, workspace_id, type (audio|image|document), name, file_url, file_size, mime_type
metadata (jsonb), tags text[], folder, created_by
```

Suporta busca por tags (GIN index), por type+folder.

---

## 2. Tipos de step (em prod)

```sql
SELECT type, count(*) FROM automation_steps GROUP BY type;
```
| step_type | count |
|-----------|-------|
| send_message | 4 |

**Apenas `send_message` está em uso.** O worker (`apps/worker/src/worker.ts:2685`) faz fallback `step.type || 'send_message'` e enfileira como type do job. Possíveis tipos no job (mas não vistos em prod): `send_audio`, `send_image`, `send_video`, `send_document` (citados no CLAUDE.md como handlers do worker).

Step config (jsonb), shape conhecido:
```json
{
  "message": "olá",
  "text": "olá",
  "media_url": "...",
  "delay_value": 5,
  "delay_unit": "s"  // s|m|ms
}
```

---

## 3. Estado em prod (workspace shark-panel)

### 3.1 Automations

```
shark-panel | total=4 | ativas=0 | pausadas=4 | draft=0
```

Os 4 fluxos:
| Nome | trigger | intercept_mode | sessions ativas | last fire |
|------|---------|----------------|-----------------|-----------|
| Aviso de Manutenção | any_message | true | 77 | 2026-04-10 |
| Fora do Horário     | any_message | true | 35 | 2026-04-15 |
| Atendimento Feriado | any_message | true | 0  | 2026-04-04 |
| Estou na Academia   | any_message | true | 0  | 2026-04-06 |

Todos `paused` mas com sessões `active` residuais — o worker checa `status='active'` em `handleFlowInterception` (worker.ts:2521), então `paused` corretamente não dispara. As sessions ficam órfãs mas não são limpas.

### 3.2 Automation triggers

`shark-panel`: 11 triggers ativos = 3 text_triggers + 8 media_triggers.

Distribuição por type:
| type | count |
|------|-------|
| keyword | 8 |
| trigger | 3 |

### 3.3 Quick triggers (189 rows)

| trigger_type | count |
|--------------|-------|
| audio | 168 |
| automation | 11 |
| image | 10 |

Esses 189 rows são auto-discovered (ver `/api/automations/quick-triggers/route.ts:54-106`): toda mídia em `automation_media` + todo `automation_triggers` ativo é automaticamente listado, e o GET cria entradas em `quick_trigger_config` para tudo. Por isso o número é alto — **não é "189 quick triggers configurados pelo usuário", é o catálogo inteiro de mídias+triggers**.

### 3.4 Mídia

```
audio: 65 itens, 7969 kB
image: 10 itens, 174 kB
```

### 3.5 Volume/storage

| Tabela | rows | size |
|--------|------|------|
| automation_execution_logs | 0 | 32 kB |
| automation_step_logs | 0 | 16 kB |
| automation_executions | 0 | (vazio) |
| automation_flow_sessions | 482 | — |
| jobs (send_message com trigger_id) | 163 | total jobs send_message=2618, último 24h=2209 |

---

## 4. Código relevante

### 4.1 API (Next.js, `app/api/automations/`)

| Rota | Arquivo | Função |
|------|---------|--------|
| `GET/POST /api/automations` | route.ts:23-141 | List/create automation |
| `GET/PUT/DELETE /api/automations/[id]` | [id]/route.ts | CRUD por id |
| `GET/POST /api/automations/[id]/steps` | [id]/steps/route.ts | Steps do flow |
| `GET /api/automations/[id]/logs` | [id]/logs/route.ts | Logs (lê automation_execution_logs — vazio) |
| `GET /api/automations/[id]/stats` | [id]/stats/route.ts | Métricas do flow |
| `GET/POST /api/automations/triggers` | triggers/route.ts | CRUD trigger |
| `POST /api/automations/triggers/[id]/fire` | triggers/[id]/fire/route.ts | **Disparo manual** (do inbox) |
| `POST /api/automations/triggers/cancel-funnel` | triggers/cancel-funnel/route.ts | Cancela sessão de funil |
| `GET/POST /api/automations/text-triggers` | text-triggers/route.ts:11-247 | Wrappers em automation_triggers (is_text_trigger=true) |
| `GET/PATCH /api/automations/quick-triggers` | quick-triggers/route.ts:14-515 | Auto-discovery + ordenação |
| `GET/POST /api/automations/audios` | audios/route.ts | Upload audio |
| `POST /api/automations/upload` | upload/route.ts | Upload genérico → S3 |
| `POST /api/automations/generate-audio` | generate-audio/route.ts | TTS via ElevenLabs |
| `GET /api/automations/midias`, `documentos` | tabs equivalentes |
| `GET /api/automations/funis` | funis/route.ts | (legado de funis OLD, não confundir com guided_funnels) |
| `GET /api/automations/trial-followup-stats` | stats agregadas |
| `POST /api/automations/schedule-delete-audio` | TTL para áudios gerados |

### 4.2 UI (Next.js dashboard)

`app/(dashboard)/automations/page.tsx` (76 linhas) — 9 abas:
1. **Fluxos** — `components/automations/tabs/fluxos-tab.tsx` (CRUD de `automations`)
2. **Áudios** — `audios-tab.tsx` (gerencia `automation_media` type=audio)
3. **Mídias** — `midias-tab.tsx` (images)
4. **Documentos** — `documentos-tab.tsx`
5. **Gatilhos** — `gatilhos-tab.tsx` (CRUD `automation_triggers`)
6. **Funis** — `funis-tab.tsx` (legado old funis)
7. **Etiquetas** — `etiquetas-tab.tsx` (contact tags)
8. **Mensagens** — `PresetMessagesTab` (tabela `preset_messages`, separada)
9. **Quick Triggers** — `quick-triggers-tab.tsx` (drag/drop com @dnd-kit)

Editor visual de fluxo: `components/automations/flow-editor.tsx` (445 linhas).

### 4.3 Worker (apps/worker/src/worker.ts, 7675 linhas)

**Pipeline de inbound message** (worker.ts:2000-2080):

```
process_webhook job processado
  ↓
isNewMessage && !fromMe?
  ↓
[1] processAutomaticTriggers   (worker.ts:1232)
    └─ matches automation_triggers (keyword|new_contact)
    └─ enqueue jobs send_message (com trigger_id em payload)

[2] handleGuidedFunnel(activeSessionOnly=true)   (Priority 1)
    └─ se sessão ativa de funil, processa, RETORNA (bloqueia outros)

[3] handleFlowInterception   (Priority 2, worker.ts:2509)
    └─ procura automations status=active + intercept_trigger_type≠manual
    └─ checa schedule (timezone)
    └─ checa escape_keyword
    └─ upsert automation_flow_sessions
    └─ enqueue cada step como job (send_message etc)
    └─ se intercept_mode=true, RETORNA true (bloqueia)

[4] handleGuidedFunnel(activeSessionOnly=false)   (Priority 3)
    └─ tenta matar nova sessão por keyword

[5] handleAIAgentResponse   (Priority 4)
```

**Anti-spam:** `processAutomaticTriggers` checa `jobs` (últimos 1h pra keyword, 24h pra new_contact) com `payload->>'trigger_id'` antes de re-disparar.

**Detecção de keyword:**
```ts
const ignoreCase = config.ignore_case !== false;  // default true
text.includes(keyword)  // não regex, contains simples
```

**Delay entre conteúdos:**
- Mínimo 5s entre conteúdos sequenciais (MIN_SEQUENCE_DELAY_MS)
- Acumula `totalDelay` para preservar ordem de envio

**Schedule check** (worker.ts:2538-2569):
- Usa `Intl.DateTimeFormat` com `schedule_timezone` (default America/Sao_Paulo)
- Suporta horário invertido (cruzando meia-noite)

### 4.4 Disparo manual

`POST /api/automations/triggers/[id]/fire` (route.ts:11-211) — usado no inbox quando agente clica num quick trigger:

```
Recebe { conversation_id }
↓
busca trigger + conversation
↓
para cada content em config.contents:
  - calcula delay (mínimo 5s entre conteúdos)
  - resolve attachment se media_id
  - INSERT INTO jobs (type='send_message', payload={trigger_id, conversation_id, to, text, attachments}, run_at=now()+delay)
↓
retorna jobs criados
```

---

## 5. Fluxo E2E — exemplo: cliente envia "preço"

```
1. Evolution webhook → POST /api/webhooks/evolution
2. Webhook persiste em jobs (type=process_webhook)
3. Worker pega job (SKIP LOCKED)
4. handleProcessWebhook:
   a. parseEvolutionWebhook
   b. upsert contact, conversation, message
   c. COMMIT
   d. processAutomaticTriggers:
      - SELECT automation_triggers WHERE workspace_id=$1 AND is_active=true
      - para cada trigger keyword:
        - se "preço" contém keyword.lower() → match
        - check anti-spam jobs (1h)
        - para cada content em trigger.config.contents:
          - se media_id → SELECT automation_media
          - INSERT jobs (send_message, run_at = now() + Σ delays)
   e. Priority 1-4 (guided funnel, flow intercept, AI agent)
5. Worker pega send_message jobs (em ordem, run_at crescente)
6. Handler send_message → chama Evolution API → marca succeeded
7. Mensagem aparece como "from agent" na conversa (com metadata.source='automation')
```

---

## 6. Quick triggers

**Não são gatilhos** — é a barra de quick-actions do inbox. Cada item:

- **trigger_type=audio** (168) → reference_id aponta `automation_media.id` type=audio. Click envia o áudio direto (PTT).
- **trigger_type=image** (10) → idem, mas image.
- **trigger_type=document** (0) → idem.
- **trigger_type=automation** (11) → reference_id aponta `automation_triggers.id`. Click chama `/api/automations/triggers/[id]/fire` que enfileira contents.

Auto-discovery (`/api/automations/quick-triggers/route.ts:43-160`): GET sempre verifica se há mídias/triggers novos sem entrada e cria automaticamente. **Cuidado:** isso significa que cada upload de áudio aparece automaticamente como quick trigger, sem o usuário pedir.

`label` é deduplicado — se uma `automation_triggers.name = "Lazerplayer"` existe e há também uma `automation_media name=Lazerplayer`, a mídia é skipada na auto-add para não duplicar botões.

---

## 7. Bugs / débitos catalogados

### 7.1 BUG: tabela `text_triggers` totalmente abandonada (0 rows)
A API `/api/automations/text-triggers/*` salva em `automation_triggers` com flag `config.is_text_trigger=true`. A tabela `text_triggers` (id, workspace_id, name, message, is_active, sort_order) existe mas nunca é gravada. **Recomendação: DROP TABLE text_triggers.**

### 7.2 BUG: tabelas de logging vazias
- `automation_executions` (0 rows)
- `automation_execution_logs` (0 rows)
- `automation_step_logs` (0 rows)

O worker NUNCA escreve nessas tabelas. A página `/api/automations/[id]/logs` retorna sempre vazio. Logs reais só nos stdout do worker. **Decisão pendente: ou implementar logging, ou DROP as 3 tabelas.**

### 7.3 BUG: `automation_flow_sessions` sem cleanup
482 rows acumulados, dos quais 273 `expired` e 97 `agent_replied`. Não há cron para purgar. Impacto pequeno (KB), mas degrada UNIQUE constraint check ao longo do tempo.

### 7.4 INCONSISTÊNCIA: `intercept_keywords` vs `automation_triggers.config.keyword`
`automations.intercept_keywords` é CSV de keywords no flow. `automation_triggers.config.keyword` é singular. Dois caminhos paralelos para "trigger por keyword" que não conversam.

### 7.5 INCONSISTÊNCIA: `step_id` duplica `id`
`automation_steps` tem PK `id` E coluna `step_id` (também uuid). Provavelmente legado de migração. Ninguém usa `step_id` no código JOIN. Pode dropar.

### 7.6 BUG: anti-spam só em keyword, não em new_contact original
worker.ts:1241 — `processAutomaticTriggers` agora tem anti-spam para `new_contact` (24h), foi adicionado. ✅ Corrigido recentemente. Comentário no código diz "BUGFIX".

### 7.7 BUG: 4 automations status=paused com 112 sessions ativas órfãs
77 + 35 sessions com `status='active'` em flows `paused`. Quando flow voltar a ativar, vão re-disparar imediatamente. **Recomendação: ao mudar status para `paused`, expirar todas sessões.**

### 7.8 INCONSISTÊNCIA: `quick_trigger_config` auto-discovery
Cada áudio gerado (ex: TTS via ElevenLabs com TTL de delete) cria automaticamente um quick trigger. Se TTL deletar o `automation_media`, o `quick_trigger_config` fica órfão (FK só pra `workspaces`, não pra `automation_media`).

```sql
-- verificar
SELECT COUNT(*) FROM quick_trigger_config q
LEFT JOIN automation_media m ON m.id = q.reference_id
WHERE q.trigger_type IN ('audio','image','document') AND m.id IS NULL;
```

---

## 8. Custos estimados

### Storage
- `automation_media`: 65 audio (7.7MB) + 10 image (174kB) + N docs ≈ **8 MB total** (negligível).
- `automation_flow_sessions`: 482 rows × ~200B ≈ 96 kB.
- `automation_execution_logs`/`step_logs`: 0 (não usado).

### CPU
- Worker faz 1 query por inbound (`SELECT automation_triggers WHERE workspace_id=...`) — cacheável.
- `handleFlowInterception` faz 1 query por flow ativo + 1 query session + N queries steps. Hoje com 0 flows ativos, custo zero.

### Tokens IA
- ElevenLabs TTS para `generate-audio` — apenas chamada manual via UI, não automática. Sem volume.

**Custo total estimado: <$1/mês** considerando o que está em uso.

---

## 9. Resumo executivo

1. **Sistema sub-utilizado:** apenas shark-panel tem 4 flows e 11 triggers, todos paused/limitados. Uniflix (workspace principal) **não usa nada** dessa área.
2. **3 mecanismos paralelos** confusos: automations (intercept), automation_triggers (standalone), text_triggers (deprecado). UI de Gatilhos tab unifica os dois primeiros via flag `is_text_trigger`.
3. **Logging quebrado:** 0 rows em todas tabelas de log. Só dá pra debugar via stdout do worker.
4. **Quick triggers infla número** (189) por auto-discovery — não reflete uso real.
5. **Pronto pra DROP:** `text_triggers`, `automation_executions`, `automation_execution_logs`, `automation_step_logs`, coluna `step_id` redundante.
