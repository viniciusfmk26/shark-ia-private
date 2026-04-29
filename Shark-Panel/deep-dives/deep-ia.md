# 🦈 Deep Dive — IA (Agents, AI-Studio, App-Flow, Vision, Voice)

**Escopo:** todo o subsistema de IA do Zapflix — agente autônomo no inbox, AI Studio (playground), agentes de escrita ("writing agents"), processamento de conversas (RAG histórico), suggest no inbox, vision (análise de imagem), transcrição de áudio, ElevenLabs (TTS).

**TL;DR:**
- Provider configurado: **OpenAI** em shark-panel (gpt-4o-mini é o default em todo lugar). Suporte plug-and-play para Anthropic, OpenRouter, Forge — mas **só OpenAI ativa em prod**.
- 1 agente IA (`ai_agents`): "Agente Zapflix" status=`inactive`, response_mode=`suggestion`. Worker tem todo o pipeline pronto pra agir, mas não age.
- **conversation_knowledge: 9.190 conversas processadas** (Σ 6 MB) — RAG histórico já populado.
- **conversation_analysis: 8.864 conversas analisadas** com intent/sentiment/lead_score.
- **ai_suggestions_log: 7.866 sugestões** geradas, **ZERO aceitas** (was_accepted=false em todas).
- **ai_learned_responses: 4.950 padrões aprendidos**, 32 aprovados.
- workspace_ai_usage **vazia** — tracking de tokens/custo nunca foi gravado.
- ElevenLabs habilitado em shark-panel, 1 voz cadastrada.
- AI Studio: 1 conversa de playground.

---

## 1. Schema (18 tabelas relacionadas a IA)

### 1.1 `ai_provider_settings` — configuração de chaves/modelos por workspace
```
workspace_id PK
provider              | text default 'openai' (CHECK: openai|anthropic|openrouter|forge)
openai_api_key, anthropic_api_key, openrouter_api_key, forge_api_key, google_cloud_api_key, elevenlabs_api_key
forge_api_url
default_model         | text                       -- ex: gpt-4o-mini
openrouter_model      | varchar(100) default 'openai/gpt-4o-mini'
is_configured         | boolean
vision_provider       | text default 'openai'
vision_enabled        | boolean default true
transcription_provider| text default 'openai_whisper'
transcription_enabled | boolean default true
auto_transcribe       | boolean default false
```

### 1.2 `ai_agents` — agente autônomo no WhatsApp
```
id, workspace_id, instance_id (FK whatsapp_instances), instance_ids[]
name                    | default 'Agente Zapflix'
mode                    | text default 'hybrid'
status                  | text default 'inactive'
personality             | text                          -- prompt curto de personalidade
system_prompt           | text                          -- prompt principal
model                   | text default 'gpt-4o-mini'
temperature             | real default 0.3
min_confidence          | real default 0.7
response_delay_seconds  | integer default 5
escalate_keywords       | text[] default {atendente,humano,gerente,pessoa}
escalate_on_unknown     | boolean default true
notify_human            | boolean default true
active_hours_start/end  | time (08:00-22:00)
active_days             | int[] default {1,2,3,4,5,6}     -- segunda-sábado
response_mode           | varchar(20) default 'auto'      -- auto|suggestion|copilot|autonomous
welcome_message, escalation_message
```

### 1.3 `ai_writing_agents` — agentes para AI Studio / inbox suggest
```
id, name, icon, description
system_prompt          | text NOT NULL
max_tokens             | integer default 300
suggestions            | jsonb default []
is_active, sort_order
```

Em prod (shark-panel? não — é GLOBAL, sem workspace_id):
| Nome | Icon | active |
|------|------|--------|
| Vendas Pro | 🛒 | false |
| Suporte Bot | 📞 | false |
| IPTV Templates | 📺 | false |
| **Funil Expert** | 🎯 | **true** |
| Denise Asssit | 🤖 | false |

### 1.4 `app_flow_nodes` — árvore de "device → app → instructions"
```
id, agent_id (FK ai_writing_agents) CASCADE, parent_id self-FK CASCADE
title, message, node_type (CHECK: root|device|app|action)
apps (jsonb)        -- [{name, download_url, instructions}]
sort_order
```

5 nodes em prod. Usado em `/api/ai/agent-app-flow` e injetado no system prompt em `/api/ai/assistant` para dar contexto de "qual app usar em qual device".

### 1.5 `ai_agent_conversations` — sessões do agente IA
```
id, workspace_id, agent_id (FK ai_agents), conversation_id (FK conversations)
status default 'active'
messages_sent, escalated (bool), escalated_reason
started_at, ended_at
```
**0 rows em prod.**

### 1.6 `ai_agent_logs` — log de cada resposta do agente
```
agent_id, conversation_id, message_received, response_sent
intent_detected, confidence (real)
action_taken, escalated (bool)
response_time_ms, tokens_used
```
**0 rows em prod.** Worker tem 3 lugares que INSERT (worker.ts:3533, 3559, 3635, 4221) — só dispararia se `ai_agents.status='active'`, que não está.

### 1.7 `ai_studio_conversations` — playground
```
id, workspace_id, agent_id (FK)
title default 'Nova conversa'
messages (jsonb [])
funnel_data (jsonb)         -- output extracted from {"funnel": ...} blocks
created_at, updated_at
```
**1 row em prod.**

### 1.8 `ai_autopilot_settings` — modo autopiloto (advanced)
```
workspace_id PK
is_enabled (default false)
confidence_threshold (default 0.85)
max_auto_replies_per_conversation (default 3)
allowed_topics, blocked_topics (text[])
fallback_message
notify_agent_on_auto_reply
```
**0 rows em prod** (nenhum workspace habilitou autopilot).

### 1.9 `ai_learned_responses` — padrões aprendidos do histórico
```
workspace_id, question_pattern, answer
source_conversation_ids uuid[]
confidence (default 0.5)
times_used, last_used_at
is_approved (bool, default false)
UNIQUE (workspace_id, md5(question_pattern))
GIN ts_vector(question_pattern + answer) — busca por relevância
```
**4.950 rows, 32 approved.** Padrões extraídos pelo `/api/ai/process-conversations` mas precisam revisão humana.

### 1.10 `ai_suggestions_log` — sugestões geradas no inbox
```
workspace_id, user_id, conversation_id
suggestion (text), was_accepted (bool), feedback
```
**7.866 rows. 0 accepted.** Feature implementada mas usuários não usam (ou frontend não trackeia accept).

### 1.11 `conversation_knowledge` — RAG enriquecido por conversa
```
workspace_id, conversation_id (UNIQUE)
contact_name, contact_phone
summary, topics[], sentiment, resolution, key_phrases[]
processed_at
GIN tsvector(summary + resolution) full-text PT-BR
```
**9.190 rows, 6 MB.** Coração do "RAG histórico" — gerado pelo `/api/ai/process-conversations`.

### 1.12 `conversation_analysis` — score/intent por conversa
```
workspace_id, conversation_id (UNIQUE)
intent, intent_confidence
sentiment, sentiment_score
urgency
detected_plan, detected_value_cents, detected_problem, detected_app
lead_score (0-100), conversion_probability (0-1)
model_used default 'gpt-4o-mini'
tokens_used
```
**8.864 rows.** Usado pelo Sales Brain (Area 8) e dashboard.

### 1.13 `workspace_ai_usage` — tracking de custo
```
workspace_id + month (varchar 7) UNIQUE
messages_count, tokens_input (bigint), tokens_output (bigint), total_cost_cents
```
**0 rows em prod.** Worker faz `INSERT ON CONFLICT UPDATE` (worker.ts:3510, 4205) mas só executa se agent.status=active. **Custo não está sendo medido em nenhum workspace.**

### 1.14 `elevenlabs_settings`
```
workspace_id PK
api_key, default_voice_id
default_model default 'eleven_multilingual_v2'
is_enabled
```

shark-panel: is_enabled=true, has_key=true, default_model=eleven_multilingual_v2.

### 1.15 `elevenlabs_voices`
```
id, workspace_id, name, voice_id, description, preferred_model
```
1 voz cadastrada em prod.

---

## 2. AI Agent — fluxo no worker

`apps/worker/src/worker.ts:3165` `handleAIAgentResponse`:

```
1. SELECT ai_agents WHERE workspace_id=$1 AND status='active' AND (instance_id=$2 OR NULL)
   → 0 rows (agente está inactive em prod)
   → return early
2. Check operating hours (active_hours_start/end timezone São Paulo)
3. Check active_days (1=Mon, 7=Sun)
4. Check workspace plan limits (workspace_plans.ai_messages_month vs workspace_ai_usage.messages_count)
   - Plan modes:
     - free: []
     - starter: [suggestion]
     - pro: [suggestion, copilot]
     - enterprise: [suggestion, copilot, autonomous]
5. Build context:
   - Últimas N mensagens da conversa
   - Knowledge base relevant chunks (RAG)
   - app_flow_nodes (se agent tem)
6. Call OpenAI chat/completions
7. Parse response:
   - If contains escalate keyword → set ai_mode='off', send escalation_message
   - Else → send response via Evolution API
8. INSERT ai_agent_logs
9. UPSERT workspace_ai_usage (tokens, cost)
```

`response_mode` controla ação:
- `auto`: envia automaticamente (modo autônomo)
- `suggestion`: cria sugestão para o agente humano (não envia)
- `copilot`: gera, agente humano confirma
- `autonomous`: envia direto (idêntico a auto)

**Em prod:** mode=`hybrid`, response_mode=`suggestion`. Mas como status=`inactive`, nada acontece.

`conversations.ai_mode` (separado de agent.response_mode):
- `off` — 10.137 (default)
- `copilot` — 1
- `autonomous` — não tem em prod

---

## 3. Endpoints `/api/ai/*` (16 rotas)

| Rota | Linhas | Função |
|------|--------|--------|
| `POST /api/ai/chat` | 70 | Chat genérico (sem agent) |
| `POST /api/ai/agent-chat` | 68 | Chat com `ai_writing_agents.system_prompt` |
| `POST /api/ai/assistant` | 102 | Chat assistant + injeta app_flow no prompt |
| `POST /api/ai/suggest` | 151 | Gera sugestões no inbox; busca knowledge_items |
| `POST /api/ai/transcribe` | 217 | Whisper para transcrever áudios; com fallback de chave do workspace principal |
| `POST /api/ai/vision/analyze` | 239 | OpenAI Vision; reusa URL pública MinIO sem download |
| `POST /api/ai/process-conversations` | 165 | Roda gpt-4o-mini sobre cada conversa, popula conversation_knowledge + conversation_analysis |
| `POST /api/ai/generate-followup` | 74 | Gera mensagem de follow-up de trial expirado (4 tones) |
| `GET /api/ai/agent-app-flow` | 76 | Renderiza app_flow_nodes em texto hierárquico |
| `GET /api/ai/usage` | 57 | Lê workspace_ai_usage (mês atual + 6m histórico) |
| `GET /api/ai/dashboard` | 94 | Score "autopilot readiness" + topics + sentiments |
| `GET /api/ai/agent-knowledge-map` | 125 | Mapa de conhecimento do agente |
| `POST /api/ai/agents` | n/a | CRUD ai_agents |
| `POST /api/ai/generate-agent-prompt` | n/a | Gera system_prompt para agente novo |
| `POST /api/ai/plan` | n/a | (?) |
| `GET /api/ai/knowledge` | n/a | Knowledge base meta |

### 3.1 `/api/ai/process-conversations` (RAG histórico)
- Lê 100 conversas por chamada.
- Para cada, monta histórico de messages e chama gpt-4o-mini com `response_format: json_object`.
- System prompt pede 13 campos JSON (summary, topics, sentiment, intent, lead_score, etc.).
- UPSERT em `conversation_knowledge` + `conversation_analysis`.
- 9.190 conversas processadas até hoje.

### 3.2 `/api/ai/suggest` (inbox)
- Recebe `{conversationId, lastMessage, recentMessages}`.
- Busca em `knowledge_items`: ILIKE + array overlap em keywords.
- Busca em `conversation_knowledge`: full-text PT-BR.
- Combina contexto e chama OpenAI.
- INSERT em `ai_suggestions_log` (was_accepted=null inicialmente).

### 3.3 `/api/ai/vision/analyze`
- Detecta se URL é pública (MinIO/Easypanel) → manda URL direto pra OpenAI.
- Senão: download + base64.
- Prompt fixo: extrair tipo (comprovante/dispositivo/screenshot/outro) e dados estruturados.
- Salva resultado em `messages.metadata.vision_analysis`.

### 3.4 `/api/ai/transcribe`
- Whisper API (`whisper-1`).
- Fallback de API key: workspace atual → workspace principal Uniflix → env `OPENAI_API_KEY`.
- Salva resultado em `messages.metadata.transcription`.

### 3.5 `/api/ai/generate-followup`
- 4 tones: `urgente`, `amigavel`, `informal`, `profissional`.
- Prompt fixo orienta variáveis `{{nome}}`, `{{servidor}}`, `{{checkout_url}}`, etc.
- Suporta openai e openrouter.
- Modelo: gpt-4o-mini (default openai) ou anthropic/claude-sonnet-4 (default openrouter).

---

## 4. AI Studio (`/api/ai-studio/*`)

| Rota | Linhas | Função |
|------|--------|--------|
| `GET /api/ai-studio/agents` | 20 | Lista `ai_writing_agents` ativos |
| `POST /api/ai-studio/chat` | 373 | **Chat com tool calling** (executa SQL) |
| `GET/POST /api/ai-studio/conversations` | 42 | List/create de `ai_studio_conversations` |
| `GET/PUT/DELETE /api/ai-studio/conversations/[id]` | n/a | CRUD |

`/api/ai-studio/chat` é o mais complexo: implementa **function calling** com tools como:
- `listar_apps` — SELECT iptv_app_configs JOIN iptv_server_bots
- `ver_template` — SELECT message_template
- `atualizar_template` — UPDATE message_template

Permite que o agente faça mudanças em IPTV configs via prompt.

Também extrai `funnel_data` quando resposta contém bloco JSON `{"funnel": ...}` — gravado em `ai_studio_conversations.funnel_data`.

---

## 5. ElevenLabs (TTS)

### 5.1 Endpoints
- `POST /api/automations/generate-audio` — gera áudio de texto via ElevenLabs.
- Salva como `automation_media` type=audio.
- TTL via cron `schedule-delete-audio` (limpa após N horas).

### 5.2 Uso
- Apenas via UI da aba "Áudios" em /automations.
- 65 áudios em prod, 7969 kB.
- Provider key salva em `ai_provider_settings.elevenlabs_api_key` ou `elevenlabs_settings.api_key`.

---

## 6. Adoption por workspace

```
shark-panel: 1 ai_agent (inactive), 1 provider config, 1 elevenlabs voice
Uniflix:    nada (sem ai_agents nem provider settings)
```

**Apenas shark-panel está configurado.** Uniflix (workspace principal) não tem chave de IA própria, depende do fallback (no transcribe).

---

## 7. Fluxo E2E — exemplo: cliente envia "como instalar?"

```
1. Inbound message → process_webhook job
2. Worker: priorities 1-3 (no automation/funnel match)
3. Priority 4: handleAIAgentResponse
   a. SELECT ai_agents WHERE status='active' → 0 rows → RETURN
   (em prod, agente está inactive, então AI nunca dispara)
4. Mensagem fica sem resposta automática

Operador abre conversa no inbox:
1. Frontend chama /api/ai/suggest com lastMessage e recentMessages
2. Endpoint busca knowledge_items + conversation_knowledge
3. Chama OpenAI com prompt customizado
4. Retorna 3 sugestões
5. INSERT ai_suggestions_log (was_accepted=null)
6. Operador vê chips de sugestão
7. Click numa: "was_accepted=true" — MAS endpoint não captura accept (provavelmente UI gap)
```

---

## 8. Custos

### Storage
- conversation_knowledge: 6 MB (9k convs)
- conversation_analysis: ~3 MB (estimado)
- ai_learned_responses: ~2 MB (5k rows com text)
- ai_suggestions_log: ~5 MB (8k rows)
- ai_studio_conversations: 48 kB
- workspace_ai_usage: 0
- elevenlabs_voices + automation_media (audios): 8 MB

**Total: ~25 MB.**

### CPU
- Worker AI handler: ~1 chamada por inbound, mas hoje aborta em <1ms (status=inactive).
- /api/ai/process-conversations: batch manual, não automatizado.

### Tokens / Custo
- workspace_ai_usage: vazio. **Não há tracking real.**
- Estimativa baseado em 9.190 conversas processadas (RAG):
  - gpt-4o-mini @ 0.15/1M input + 0.60/1M output
  - ~3000 tokens/conversa × 9190 ≈ 27.5M tokens input
  - **Custo aprox histórico: $4-8 USD** (one-shot processamento)
- ai_suggestions_log: 7.866 sugestões × ~500 tokens = 4M tokens × ~$0.15-0.60/1M = **~$1-3 USD**
- ai_writing_agents (chat manual): volume baixo (1 conversa em studio).

**Custo IA estimado total histórico: ~$10-20 USD. Hoje, sem agente ativo, gasto ≈ $0/mês.**

### ElevenLabs
- TTS: ~$0.30/1k chars (eleven_multilingual_v2). 65 áudios × ~150 chars ≈ $3 histórico.

---

## 9. Bugs / débitos

### 9.1 BUG: agente IA configurado mas inactive
shark-panel tem agent `Agente Zapflix` mas status=`inactive`. Sem decisão (ativar/deletar) ele só consume linha no DB.

### 9.2 BUG: `ai_suggestions_log.was_accepted` sempre null/false
7.866 rows, **zero aceitas**. UI provavelmente não chama PATCH para marcar accept. Métrica de "qualidade da IA" não existe na prática.

```sql
-- verificar:
SELECT count(*) FROM ai_suggestions_log WHERE was_accepted IS NOT NULL;  -- = 0?
```

### 9.3 BUG: workspace_ai_usage vazio
INSERTs em worker.ts:3510, 4205 só rodam se agente está ativo. **Sem rastreamento de custo real.** Nem `/api/ai/usage` retorna dado real (current = 0 messages, 0 cost sempre).

Fix: instrumentar todos os endpoints REST que chamam OpenAI/Anthropic para popular `workspace_ai_usage`.

### 9.4 BUG: `ai_writing_agents` é GLOBAL (sem workspace_id)
Tabela não tem workspace_id. **Mesmo agentes vistos por todos os workspaces.** OK se for por design ("templates compartilhados"), mas se um workspace edita o system_prompt, afeta todos.

### 9.5 BUG: `conversation_knowledge` cresce mas não tem cron de processamento
9.190 já processadas — mas se hoje 1.000 conversas novas chegam, ninguém processa. Não há cron `process-conversations`. Tem que rodar manual via endpoint.

```sql
-- verificar gap:
SELECT 
  (SELECT count(*) FROM conversations) as total,
  (SELECT count(*) FROM conversation_knowledge) as processed;
```
Se total > processed, há backlog.

### 9.6 BUG: `transcription_provider='openai_whisper'` mas só openai está implementado
`/api/ai/transcribe` só usa OpenAI. Configurar outro provider quebra silenciosamente.

### 9.7 BUG: `min_confidence` não é checado em todos lugares
Worker tem `agent.min_confidence` mas use de forma inconsistente — escalation logic pode ignorar.

### 9.8 BUG: chaves em texto puro (`openai_api_key text`)
Sem criptografia em repouso. Se atacante obtém dump do banco, pega todas chaves dos clientes. Sugerido: pgcrypto ou KMS.

### 9.9 BUG: `ai_agent_logs.tokens_used` raramente populado
Mesmo quando agent está ativo (não é o caso em prod), o INSERT pode ter tokens_used=NULL se a resposta da OpenAI não vier com `usage` (raro). Sem fallback para estimativa.

### 9.10 INCONSISTÊNCIA: vários `gpt-4o-mini` hardcoded
Em vez de sempre ler `ai_provider_settings.default_model`, várias rotas hard-codam `gpt-4o-mini` (ex: `/api/ai/agent-chat:34`, `/api/guided-funnels/generate-ai:53`). Migração para Sonnet 4 ou outro modelo é manual em N lugares.

### 9.11 BUG: `ai_provider_settings.openai_api_key LIMIT 1` sem workspace filter
`/api/ai/generate-followup:33` faz `SELECT ... LIMIT 1` sem WHERE workspace_id. Pega chave de QUALQUER workspace (provavelmente o primeiro inserido). **Multi-tenant vazado!** Mesmo problema em `/api/ai/agent-chat`, `/api/ai/assistant`, `/api/ai-studio/chat`.

```ts
// BUG:
const { rows } = await query(
  `SELECT openai_api_key FROM ai_provider_settings LIMIT 1`,
  []
);

// FIX:
const { rows } = await query(
  `SELECT openai_api_key FROM ai_provider_settings WHERE workspace_id=$1`,
  [workspaceId]
);
```

Isso é o mais sério dos bugs catalogados — viola CLAUDE.md (rule "SEMPRE incluir workspace_id em queries").

---

## 10. Resumo executivo

1. **🔴 BUG MULTI-TENANT:** queries em ai_provider_settings sem workspace_id em ≥4 endpoints. Workspace A consome chave do workspace B. Prioridade alta.
2. **Agente IA inutilizado:** "Agente Zapflix" criado, status=inactive. Decidir: ativar ou deletar.
3. **Tracking de custo quebrado:** workspace_ai_usage vazia. Sem rastreamento, sem rate limiting funcional, sem billing por workspace.
4. **RAG histórico funciona:** 9k conversas processadas, 5k learned responses, 8k análises de intent. Mas dependem de execução manual do endpoint.
5. **Sugestões sem feedback loop:** 7.866 sugestões geradas, 0 marcadas como aceitas. UI não fecha o loop.
6. **AI Studio é poderoso mas pouco usado:** 1 conversa no playground. Function calling implementado (listar_apps, ver_template, atualizar_template).
7. **Vision e Transcribe estão em prod:** processam imagens e áudios do inbox.
8. **ElevenLabs configurado:** 1 voz, 65 áudios gerados.
