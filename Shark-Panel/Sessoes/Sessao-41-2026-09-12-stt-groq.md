# Sessão 41 — Shark Panel
**Data:** 12/09/2026
**Foco:** Migração do STT (transcrição de áudio) da OpenAI para Groq (cota gratuita diária)

---

## Contexto

Mapeamento completo do sistema de transcrição de áudio revelou que a rota web do inbox já usava faster-whisper local (`wp_zapflix-whisper`), mas o **worker** (fluxos audio_router + AI Agent) ainda chamava a **API OpenAI paga** diretamente via `transcribeAudioForAI()` em `apps/worker/src/shared.ts`.

Motivação do usuário: transcrição local era lenta demais para chatbot (RTF 1.2–4.8x numa VPS de 4 vCPU saturada) e OpenAI custa ~$0.36/h de áudio. OpenRouter **não suporta STT** (só texto/chat). Solução escolhida: **Groq** (`whisper-large-v3-turbo`) — o usuário tem cota gratuita diária.

---

## Mapeamento do STT (estado antes)

| Fluxo | Arquivo | Provedor antes |
|---|---|---|
| A. Inbox (botão transcrever) | `app/api/ai/transcribe/route.ts` | local_whisper (wp_zapflix-whisper:8000) |
| B. Worker audio_router (voz inbound automática) | `apps/worker/src/shared.ts:1605` | OpenAI whisper-1 (pago) |
| C. Worker AI Agent (contexto de áudio/vídeo) | `apps/worker/src/shared.ts:1524/1731` | OpenAI whisper-1 (pago) |
| D. Checkout | `checkout/server/_core/voiceTranscription.ts` | Proxy Forge (separado, intocado) |

---

## O que foi feito

### 1. Worker — Groq como provider primário (`apps/worker/src/shared.ts`)
- Nova env: `GROQ_API_KEY` (export ao lado de EVOLUTION_*)
- `transcribeAudioForAI()` reescrita: tenta **Groq** `whisper-large-v3-turbo` primeiro (language=pt, response_format=json, timeout 30s); em qualquer falha (429 cota diária, rede, vazio) → **fallback OpenAI** `whisper-1` com a chave do workspace
- Logs agora incluem `provider: groq|openai`
- Se `apiKey` (OpenAI) vazio mas Groq configurada → funciona igual (gate antigo foi removido)

### 2. Worker audio_router — gate flexibilizado (`apps/worker/src/handlers/webhook.ts`)
- Antes: sem `openai_api_key` no workspace → transcrição abortava
- Agora: gate passando com `GROQ_API_KEY` sozinha; `apiKey: openaiKey || ''`

### 3. Rota web — novo provider `groq_whisper` (`app/api/ai/transcribe/route.ts`)
- `transcription_provider` aceita agora: `local_whisper` | `groq_whisper` | `openai_whisper`
- `groq_whisper` usa env `GROQ_API_KEY` do serviço web, timeout 60s
- Resolução de chave OpenAI agora só roda quando provider === 'openai_whisper'

### 4. Deploy
- `docker build -f Dockerfile.worker -t easypanel/wp/zapflix-worker:latest` + `docker build -t zapflix-tech:latest`
- `docker service update --env-add GROQ_API_KEY=... --image ...` em **wp_zapflix-worker** e **wp_zapflix-web**
- Ambos convergiram 1/1; worker processando webhooks normalmente pós-deploy

---

## Validação

- Teste de chave Groq: `GET /openai/v1/models` OK; modelos relevantes: `whisper-large-v3-turbo`, `whisper-large-v3`
- Teste com áudio REAL de produção (Ogg Opus Cloud API, 4s, do MinIO):
  - `provider: groq`, **497ms**, texto correto em pt-BR
  - Caminho sem chave OpenAI também validado (apiKey='' funcionou só com Groq)
- Typecheck limpo: `tsc -p tsconfig.worker.json` e `tsc --noEmit` (web)

---

## Números

| Provedor | Latência (áudio 4s) | Custo |
|---|---|---|
| **Groq whisper-large-v3-turbo** | **0.3–0.5s** | $0 (cota diária grátis) |
| OpenAI whisper-1 (antes) | ~2–5s | ~$0.36/h áudio |
| Local faster-whisper medium | ~5–19s (VPS saturada) | $0 |

---

## Notas / pendências

- **Chave Groq foi colada em chat** — recomendação: regenerar no console (console.groq.com/keys) e atualizar env nos 2 serviços
- Cota diária gratuita da Groq: se estourar, fallback OpenAI entra automático (log `fallback OpenAI`)
- Fluxo D (checkout, `BUILT_IN_FORGE_API_URL`) não foi alterado — módulo separado
- `deep-ia.md` seção 9.6 ("só openai implementado") ficou desatualizada — groq_whisper agora existe na rota
- Serviço whisper local (`wp_zapflix-whisper`) segue no ar como padrão do inbox (fluxo A)

---

## Follow-up (mesma sessão, 22:45)

Usuário reportou demora persistente. Diagnóstico: worker já na Groq (rápido), mas o **workspace principal seguia com `transcription_provider='local_whisper'`** no banco → botão "Transcrever" do inbox usava o whisper local (RTF médio 3.49, áudio de 30s → ~105s).

**Fix:** `UPDATE ai_provider_settings SET transcription_provider='groq_whisper' WHERE workspace_id='00000000-...-0002'`. Sem restart necessário (rota lê config a cada request). Whisper local segue no ar como opção, mas fora do caminho padrão.

Verificado também: `audio_intent_skip_human_engaged` nos logs é comportamento correto (áudio pulado quando atendente humano está na conversa).

---

## Sessão 41b (22:55) — Resumos de conversa migrados para Groq

**Causa raiz reportada pelo usuário:** resumo no inbox quebrado. Logs confirmaram: OpenAI sem créditos (`insufficient_quota: You have no credits remaining`) — os 3 fluxos de resumo dependiam dela.

**Nova chave Groq (chat):** `gsk_tPEk...` (diferente da de STT) configurada como `GROQ_CHAT_API_KEY` nos serviços web e worker. Modelo: `openai/gpt-oss-120b` (JSON estruturado perfeito em pt-BR, ~0.9s).

**Fluxos migrados:**
1. `/api/inbox/conversations/[id]/summary` (Sparkles): cadeia de attempts — provider 'groq' (se configurado) → OpenAI/OpenRouter do workspace → fallback Groq → heurístico. Env: `GROQ_CHAT_API_KEY`, `GROQ_CHAT_MODEL`
2. `/api/inbox/conversations/[id]/summarize` (FileText): Groq primeiro, OpenAI como fallback
3. Worker SalesBrain (`background.ts`): Groq como motor primário global; OpenAI/OpenRouter só se GROQ_CHAT_API_KEY ausente

**Deploy:** worker + web rebuildados e convergidos 1/1. Teste E2E no container web: 200 OK, JSON correto.

**Nota:** IA Agent de respostas (auto-reply) ainda usa OpenAI/OpenRouter — se `insufficient_quota` persistir nele, é o próximo a migrar. Sigma 403 Cloudflare é problema separado (painel externo bloqueando).

---

## Sessão 41c (23:40) — Rate limit Groq no SalesBrain corrigido

**Problema pós-deploy:** SalesBrain (worker) processava até 20 conversas em rajada e estourava o TPM do free tier Groq (8000 tokens/min) com 429s.

**Fixes em background.ts:**
1. `max_tokens` 3000 → 1500
2. `transcript.slice(0, 8000)` → `slice(0, 4000)`
3. Throttle: pausa 25s após CADA conversa processada (~2600 tokens/call → ~6000 TPM)
4. 429 → pausa 60s e deixa próximo ciclo reprocessar (NOT EXISTS já cobre)

**Lição de deploy:** `docker service update --image TAG` NÃO rolou a task 2x seguidas (task antiga continuava com imagem anterior, `docker ps -q` pegava o container errado no exec). Sempre conferir `docker inspect $CONTAINER --format {{.Image}}` vs `docker image inspect TAG --format {{.Id}}` e usar `--force` quando necessário.

**Estado final:** worker c1262b com todos os fixes; inbox (Sparkles + FileText) na Groq gpt-oss-120b; SalesBrain na Groq com throttle. OpenAI (sem créditos) só entra como fallback de último recurso.

---

## Sessão 41d (23:55) — Botão de resumo duplicado removido

Inbox tinha 2 botões de resumo no toolbar (herança histórica):
- 📄 FileText (perto da lupa) → `POST /summarize`, resumo texto corrido simples (legado)
- ✨ Sparkles (perto da 💡 lâmpada) → `POST /summary`, dialog rico com interesse/objeções/next_step/status (versão nova)

**Removido:** botão 📄 + estados `summarizing/summaryText/showSummary` + card violeta órfão em `chat-view.tsx`. Endpoint `/summarize` mantido no backend (pode ter consumers externos), só o botão saiu.

Deploy: zapflix-tech:latest rebuildado, `--force` rolling update, convergido 1/1.

O ✨ Sparkles é agora o único ponto de resumo no inbox (já na Groq gpt-oss-120b).

---

## Sessão 41e (00:10) — Dialog de resumo abria vazio (bug React)

**Sintoma:** dialog ✨ abria mas só mostrava o título "Resumo IA da Conversa" — sem loading, sem resultado.

**Causa raiz:** `generate()` estava dentro de `onOpenChange` do Radix Dialog. Abertura programática (botão Sparkles → setState) NÃO dispara `onOpenChange` — o callback só dispara em interações internas (ESC/overlay). `generate()` nunca era chamado.

**Fix:** `useEffect(() => { if (open && !result && !loading) generate(); }, [open])` em `ai-summary-dialog.tsx`. Provavelmente o dialog nunca funcionou corretamente por botão.

**Descartado no diagnóstico (importante):** Groq OK (gpt-oss-120b SEM response_format json_object — reasoning models não suportam JSON mode, dá 400), parse do JSON OK, API viva, endpoint retorna 401 sem auth (rota viva). Nota: a `callAI` do /summary não usa response_format, então não é afetada pelo 400 do JSON mode.

**Deploy:** zapflix-tech rebuildado, --force, convergido. useEffect confirmado nos chunks.

---

## Sessão 41f (13/09, 00:40) — Embeddings RAG migrados para NVIDIA NIM (free)

**Contexto:** usuário ofereceu key NVIDIA (nvapi-W9...) e modelos free. Testes no hosted API (integrate.api.nvidia.com):
- ✅ `nvidia/nemotron-3-embed-1b`: 2048 dims, batch OK, input_type query/passage, free
- ❌ Rerankers (nemotron-rerank-vl-1b-v2 etc.): NÃO disponíveis no hosted API (rota /v1/ranking 404, zero modelos rank em /v1/models) — são NIMs downloadable/self-host only; VPS não tem CPU pra isso
- ✅ pgvector FUNCIONA na imagem pgvector/pgvector:pg17 (doc de agosto sobre ".so ausente" está desatualizado)

**Mudanças:**
1. `lib/rag/embeddings.ts`: OpenAI text-embedding-3-small (1536) → NVIDIA nemotron-3-embed-1b (2048). Env: `NVIDIA_API_KEY`, `NVIDIA_EMBED_MODEL`, `NVIDIA_BASE_URL`. Nova `embedQuery()` (input_type=query) vs `embedTexts` (input_type=passage) — retrieval assimétrico
2. `rag-search/route.ts`: query agora via `embedQuery()`
3. DB: `knowledge_chunks.embedding_vec` vector(1536) → vector(2048). Índice ivfflat DROPPADO — limite pgvector: index só até 2000 dims. Tabela vazia + linear scan ok; se volume crescer, migrar pra HNSW com halfvec(2048)

**Deploy:** zapflix-tech rebuildado, env NVIDIA_API_KEY no wp_zapflix-web, E2E no container: 200 OK 2048 dims.

**Estado do RAG:** stack viva e 100% free (embedding NVIDIA + pgvector local). knowledge_chunks vazia (indexing é on-demand via POST /api/knowledge/documents/[id]/index). RAG ainda NÃO plugado no chatbot (contexto usa recência, não semântica) — fase 2 se desejado.
