# Motor TTS Local — Chatterbox (Self-Hosted)

> Deploy em 14/09/2026 19:15. Clonagem de voz por referência 100% grátis no servidor (Chatterbox Multilingual V3, Resemble AI, licença MIT).

## Serviço Swarm: `wp_zapflix-tts`

| Item | Valor |
|---|---|
| Imagem | `zapflix-tts:latest` (Dockerfile em `/root/Zapflix-Tech/tts-chatterbox/`) — 6.97GB compactada |
| Stack | Python 3.11 + torch CPU (chatterbox puxou CUDA deps mas roda CPU) + FastAPI + ffmpeg |
| Modelo | ChatterboxMultilingualTTS (0.5B, 23+ idiomas, pt incluído) — pré-baixado no build |
| Limites | `--limit-memory 5g --reserve-memory 4g --limit-cpu 2` (4GB deu OOM 137 no load; 5GB segura, uso idle ~4.7GB) |
| Rede | overlay `easypanel-wp`, **sem porta pública** (só interno) |
| API interna | `GET /health` (`{"status":"ok","model":"loaded"}`), `POST /tts` `{text, language_id, audio_prompt_b64?, exaggeration?, cfg_weight?}` → mp3 64k |
| Startup | Modelo carrega no startup (~2min) — FastAPI só abre a porta depois (connection refused até lá é normal) |
| Performance | CPU 2 threads: frase curta ~90-120s de geração |

## Integração Web

- Env no `wp_zapflix-web`: `CHATTERBOX_URL=http://wp_zapflix-tts:8000` (se ausente, motor fica oculto no Studio)
- `GET/POST /api/studio/local-tts` (`app/api/studio/local-tts/route.ts`): GET = status (ping /health, 5s); POST = proxy com timeout 280s. Referência de voz por `reference_audio_id` (automation_media) → web baixa e envia base64 ao motor. Mesmo shape de resposta do generate-audio (`provider: 'chatterbox'`, save no S3 + automation_media).
- Studio: 3º card "Local (Chatterbox)" no motor de voz, com idioma (pt default) + seletor de voz de referência da Biblioteca. Geração pode levar 1-3min (UI avisa).

## Lições do deploy (14/09/2026)

1. **Disco**: imagem TTS + cache de build encheram o disco (100%) durante builds paralelos — web build falhou com "no space". Sempre: `docker builder prune -af` antes de build grande; NUNCA dois builds pesados simultâneos. Disco ficou em 86-88% — monitorar.
2. **Build demora**: TTS full build ~15min (pip torch + chatterbox + predownload HF ~2GB). Export/unpack de 18.5GB camadas demora minutos com disk I/O alto.
3. **OOM 137 no load**: chatterbox multilingual precisa de ~4.7GB RAM residente. Limit 5g OK. Se mover pra outra máquina, mínimo 6g.
4. **Kill de builds**: `pkill -f "docker build"` mata TODOS os builds (usei e matei 2 de uma vez). Cuidado.
5. **Swarm image resolution**: continuar usando tag versionada em todo `service update` (padrão já documentado).
