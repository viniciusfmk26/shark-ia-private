# Sessão 45 — Shark Panel
**Data:** 13/09/2026
**Foco:** POC TTS open source — OmniVoice (k2-fsa) em CPU da própria VPS de produção

---

## Contexto

Avaliação de alternativa open source ao ElevenLabs/Fish Audio para TTS + clonagem de voz. Estado do TTS na ocasião: **Fish Audio (OpenRouter) primário, ElevenLabs fallback** (commit `7df2bf06`).

**Candidato:** [OmniVoice](https://github.com/k2-fsa/OmniVoice) (k2-fsa — time do Daniel Povey) — 13.1k stars, **Apache-2.0**, TTS zero-shot difusão para 600+ idiomas, clonagem com 3-10s de áudio, RTF 0.025 em H100.

## Atrativos pro Shark Panel

- Apache-2.0 → self-host sem custo por caractere
- `create_voice_clone_prompt()` salva `.pt` → substituiria o conceito `voice_id` da tabela `elevenlabs_voices` (encode 1x, reusa)
- `normalize_text=True` (num2words) → tangencia o `normalizeTtsPronunciation()` pt-BR feito à mão no `tts.ts` (Sessão 44)
- Tags inline (`[laughter]`) e voice design por atributos (gênero/idade/pitch, treinado só em zh/en)

## Benchmark na VPS de produção (SEM GPU)

Setup: venv isolado em `/tmp/opencode/omnivoice-poc`, torch 2.8.0 CPU, fp32, 4 threads, textos curtos, ref Fleurs pt-BR (6.7s) com `ref_text` explícito (evita carregar Whisper junto). Produção ilesa (8.4GB livres recuperados ao final).

| Amostra | Modo | Áudio | Geração | RTF (4 cores CPU) |
|---|---|---|---|---|
| 1_auto.wav | Auto voice pt-BR | 4.7s | 83s | **17.8** |
| 2_clone.wav | Clone voz ref pt-BR | 6.0s | 223s | **37.4** |
| 3_numeros.wav | Clone + "R$ 123,45"/"18:30"/% | 10.9s | 291s | **26.7** |

Modelo: ~3.1GB (2.4GB main + 0.8GB audio tokenizer) + Whisper é dependência opcional para auto-transcrição de ref.

## Conclusões

1. **CPU não serve para modo voz do agente (tempo real)** — RTF 17-37 na VPS = 1-5 min por áudio de 6s. Self-host exige GPU dedicada (RTX 3060/4060 estimado RTF <0.5; H100 faz 0.025).
2. **Batch/automations em CPU é tecnicamente viável mas perigoso nesta VPS** — ~7GB RAM + 1 core pesado com swap do host em 75%.
3. **Veredito de qualidade pt-BR pendente** — wavs em `/tmp/opencode/omnivoice-poc/samples/` (removidos depois da avaliação; regeneráveis com o poc.py, env mantido no journal da sessão).
4. Encaixe futuro: mais um provider na cadeia de prioridade de TTS (agent.voice_id → workspace → default), com path de prompt `.pt` no volume.

## Decisão

Se a qualidade agradar → validar latência em GPU alugada (vast.ai/RunPod ~$0.20-0.40/h) antes de qualquer mudança de infra. Se não agradar → Fish Audio segue primário; OmniVoice registrado como opção futura.

## Commits

- Nenhum no projeto (POC isolado em /tmp). Últimos commits de voz: `7df2bf06` Fish primário · `cbd20737` voz por agent · `0e5464c0` pronúncia pt-BR
