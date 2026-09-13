# Sessão 43 — Shark Panel
**Data:** 13/09/2026
**Foco:** Modo voz do Agente IA — "atende por voz" (TTS da resposta como PTT)

---

## Contexto

O agente IA já entendia áudio recebido (transcrição Groq/whisper → contexto), mas respondia só por texto. Não havia TTS no worker: gerar áudio era possível apenas manualmente (dialog do inbox / automações). Pergunta do usuário: "eu falo 'atende por voz' ele atenderia?" — não. Implementado para sim.

## O que foi feito

### 1. Coluna nova — migration aplicada direto (idempotente)
```sql
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS voice_mode boolean NOT NULL DEFAULT false;
```
- Aplicada em produção: 34.341 conversas com `false` (sem rewrite de tabela, PG 11+ metadata-only)

### 2. Lib TTS do worker — `apps/worker/src/lib/tts.ts`
- `cleanTextForTts()`: remove markdown/emoji, trunca em ~900 chars (corte em pontuação)
- `resolveElevenLabsKey()`: mesma cadeia da rota web (workspace_settings → ai_provider_settings → env `ELEVENLABS_API_KEY` → app_meta global)
- `resolveVoice()`: `workspace_settings.elevenlabs.default_voice_id` → primeira voz de `elevenlabs_voices` (workspace → global) → voz default ElevenLabs
- `synthesizeAgentAudio()`: ElevenLabs TTS → **fallback Fish Audio grátis** (OpenRouter) → upload MinIO (`media/audio/agent-tts-*.mp3`) → URL pública
- Falha total → retorna null (chamador cai para texto)

### 3. Handler do agente — `apps/worker/src/handlers/ai.ts`
- Fetch inclui `voice_mode` da conversa
- **3c. Comandos de voz** (match sem acento, no texto da mensagem):
  - Ativa: "atende por voz", "atender por voz", "modo voz", "responde por voz", "atende por áudio", "responde com áudio"
  - Desativa: "atende por texto", "modo texto", "responde por texto", "responde com texto"
  - Persiste em `conversations.voice_mode`
- **12-voz.** Antes do envio principal: se `voice_mode` ON → sintetiza `finalResponseText` → enfileira `send_message` com attachment `{ url, type: 'audio', isPtt: true }`. TTS falhou → texto (nunca deixa o cliente sem resposta). Escalação e modo assisted continuam por texto.

### 4. Envio PTT — infra já existente (intocada)
- `media.ts`: attachment áudio → converte OGG/Opus (ffmpeg) p/ Cloud API (ícone verde) / `isPtt` p/ Evolution

## Deploy
- `docker build -f Dockerfile.worker -t easypanel/wp/zapflix-worker:latest` + `service update wp_zapflix-worker` — convergiu
- `docker build -t zapflix-tech:latest` + `service update wp_zapflix-web` — convergiu
- Worker processando normalmente pós-deploy

## Observação de risco (pré-existente)
- OpenRouter: cota diária do `gpt-oss-120b` esgotando (429 TPD no SalesBrain) — não afeta TTS (ElevenLabs é conta própria; Fish é modelo free distinto, rate limit é por modelo)

## Como usar
Cliente manda **"atende por voz"** → agente responde as mensagens seguintes como voice note (PTT). **"atende por texto"** volta ao texto. Voz/modelo padrão: configurar `default_voice_id` em Configurações → IA ou cadastrar voz em Master → IA Agents.
