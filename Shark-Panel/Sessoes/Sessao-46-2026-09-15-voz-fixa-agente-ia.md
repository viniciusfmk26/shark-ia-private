# Sessão 46 — Shark Panel
**Data:** 15/09/2026
**Foco:** Fix "agente de IA fica mudando a voz" — voz Fish padrão fixa no TTS (PTT)

---

## Relato

Usuário: *"o agente de IA fica mudando a voz e ele não mantém 1 voz só"*.
Agente respondia por voz (PTT), mas a voz mudava entre mensagens.

## Causa raiz

- `apps/worker/src/lib/tts.ts` — `synthesizeAgentAudio()` com agente **sem `voice_id`**
  (padrão "Padrão do workspace (Fish grátis)") chama o Fish Audio via OpenRouter
  **sem o campo `voice`** (`....(fishVoice ? { voice } : {})`).
- O modelo `fish-audio/s2.1-pro-free:free` **sorteia uma voz diferente a cada
  requisição** quando não recebe voice explícito → cada PTT tinha uma voz nova.
- Agravantes: fallback ElevenLabs em falha transitória do Fish trocava a voz de
  vez em quando, e `resolveVoice()` podia cair na "primeira elevenlabs_voices".
- Mesmo bug existia na geração manual de áudio (`/api/automations/generate-audio`,
  "voz padrão" sem voice).

## Fix (commit: a definir)

1. **Voz Fish padrão FIXA** (galeria pública fish.audio, pt-BR feminina):
   ```ts
   const FISH_DEFAULT_VOICE_ID = '5661bf8cb97740fcb10d2f756abf7779'; // "Isabela"
   ```
   - `apps/worker/src/lib/tts.ts`:
     - `fishAudioTts()` agora SEMPRE envia `voice` — explícita do agente/agente
       `isFishVoiceId()` ou `FISH_DEFAULT_VOICE_ID` quando nada configurado.
     - `synthesizeAgentAudio()` caso "sem voz" cai no Fish com a voz fixa; EL
       vira fallback de falha. Documentado no cabeçalho.
   - `app/api/automations/generate-audio/route.ts`: mesmo pin (mesma voz padrão
     em toda geração manual/fallback → áudios da biblioteca ficam consistentes).

2. **Comportamento resultante**: agente sem `voice_id` agora usa SEMPRE "Isabela";
   agente com `voice_id` (Fish ou ElevenLabs) continua usando a voz escolhida.

## Verificação

- `npx tsc --noEmit -p tsconfig.worker.json` ✅
- `npx tsc --noEmit -p tsconfig.json` ✅
- Voz `5661bf8cb97740fcb10d2f756abf7779` validada na galeria
  (`api.fish.audio/model/...`): state=trained, visibility=public, languages=[pt].
- ESLint não configurado no repo (sem `eslint.config.*`) — validado só via tsc.

## Deploy pendente

- `docker build -t zapflix-tech:latest /root/Zapflix-Tech`
- `docker service update --image zapflix-tech:latest wp_zapflix-web`
- Lembrar lição da Sessão 44: usar `--force` no service update e conferir a idade
  da task / grep do código no container.