# Sessão 44 — Shark Panel
**Data:** 13/09/2026
**Foco:** Modo voz em produção (testes com Julia 5137) — fixes de transcrição, dupla resposta, pronúncia TTS + estúdio de clonagem

---

## Teste real: conversa do Ambern (555381062741) com instância "Julia Abreu De Melo 5137"

Setup operacional: agent **"Julia (Amigo por Voz)"** (`3ae8ac1f`, workspace ...0002, autonomous, 24/7, modelo `z-ai/glm-5.3-flash` via OpenRouter) + `conversations.voice_mode=true` + `assigned_to=NULL` (autonomous recusa com humano assigned).

### Bugs encontrados e corrigidos

1. **Deploy "fantasma"** — `docker service update --image TAG` disse *converged* mas não rolou a task nova (worker rodava código antigo). **Lição: sempre `--force` e conferir idade da task + grep do código dentro do container.**

2. **"Ele não raciocina"** — 3 causas: agent herdava `model=gpt-4o-mini` (default da coluna), prompt meu pedia casualidade rasa, e `audio_router_enabled=false` (não ouvia áudios). Corrigido: modelo GLM, prompt "PENSE antes de falar", router ligado.

3. **Dupla resposta (texto + áudio)** — o **audio_router** (menu IPTV) transcrevia e, com confiança 0.00 de menu, enviava texto "escolha uma opção" + o agent respondia TTS. Fix: `webhook.ts` — router cala o texto do menu quando existe AI Agent ativo cobrindo a instância (`audio_intent_menu_skip_agent`).

4. **Agent não entendia a voz** — na Cloud API `parsed.media_type` vem vazio (bloco de mídia nem roda) e `downloadMediaBuffer` só cobre Evolution/S3, não a Meta. O router transcreve o buffer em memória e persiste em `messages.metadata.transcription`. Fix: `ai.ts` — agent lê a transcrição persistida (janela 3 min) como fallback (`transcript_from_router`).

5. **TTS lia "como escreve"** — "R$ 17" saía "r $ dezessete". Fix: `tts.ts` — `normalizeTtsPronunciation()` pt-BR: moeda ("dezessete reais e noventa centavos"), %, horário (18:30 → "dezoito e trinta"), números por extenso. Aplica só no texto do TTS.

### Infra de voz (estado)
- TTS: ElevenLabs (chave do workspace **401 — inválida, pendente troca**) → fallback Fish Audio grátis (funcionando, bytes ok)
- PTT: `media.ts` converte MP3 → OGG/Opus (ffmpeg), chega como bolha verde ✅

### Estúdio de clonagem (web)
- `VoiceCloneDialog` agora tem **gravação por microfone** (MediaRecorder, takes gravacao-take-NN.webm, timer, dicas de qualidade, cancelamento de stream no close) + play em cada amostra
- API `/api/master/elevenlabs-clone-voice` inalterada (aceita webm; valida 10MB/amostra, 10 arquivos)
- **Bloqueio:** clone e TTS ElevenLabs exigem chave válida (hoje 401)

## Commits
- `fa8b2bda` modo voz + clone UI · `0c773776` fixes transcrição/router · `0e5464c0` pronúncia TTS + estúdio
