# Studio de Voz — Feature

> Criada em 14/09/2026. Página dedicada em `/studio` para geração de áudio (TTS), gravação por microfone, clonagem de voz e biblioteca de áudios.
> Atualização 14/09/2026: adicionado preview de voz (amostra audível de cada voz) e seletor de idioma (`language_code`).

## Localização no menu

Sidebar → **Inteligência Artificial → Studio de Voz** (`/studio`).
Gate: `roles: owner/admin`, `permissionKey: automations`, `feature: funnels` (mesma feature guard das APIs de áudio).

## Preview de voz + Idioma (14/09/2026)

- **Preview de voz**: `GET /api/elevenlabs/voices` agora retorna `preview_url` (amostra oficial da voz). Botão "Ouvir amostra" no TTS panel toca/pausa a amostra da voz selecionada.
- **Idioma**: seletor no TTS panel (auto + ~30 idiomas ISO). Enviado como `language_code` no `POST /api/automations/generate-audio`, que valida contra allowlist e só repassa para modelos que suportam (`eleven_turbo_v2_5`, `eleven_flash_v2_5`, `eleven_v3`, `eleven_turbo_v3`). Multilingual v2 detecta sozinho (UI avisa).
- **Deploy swarm**: descoberto que `docker service update --image zapflix-tech:latest` pode re-resolver a tag para imagem antiga/local obsoleta (container subiu com imagem já deletada `5af2445...`). Fix: sempre deployar com tag única versionada (`docker tag zapflix-tech:latest zapflix-tech:v$(date +%s)` + `docker service update --image zapflix-tech:v<ts>`).

## Abas

| Aba | Rota do componente | O que faz |
|---|---|---|
| **Gerar Voz** | `components/studio/tts-panel.tsx` | TTS ElevenLabs (com fallback Fish Audio grátis). Editor de texto 500 chars, nome customizado, vozes agrupadas (Favoritas / Minhas Vozes / Biblioteca ElevenLabs), modelos (multilingual_v2, turbo_v2_5, flash_v2_5, v3), sliders de emoção no v3, player + download MP3. Todo áudio gerado é salvo automaticamente em `automation_media`. |
| **Gravar** | `components/studio/record-panel.tsx` | MediaRecorder (webm/opus), timer, preview, salvar na biblioteca (upload `/api/automations/upload` + POST `/api/automations/audios`) ou enviar direto para clonagem. |
| **Minhas Vozes** | `components/studio/clone-panel.tsx` | Instant Voice Cloning: amostras via gravação inline/upload/aba Gravar (até 10 × 10MB). Lista vozes da conta (category cloned/professional/custom...) com exclusão. |
| **Biblioteca** | `components/studio/library-panel.tsx` | Lista `automation_media` type=audio com busca, play, renomear (PATCH), download, excluir. |

## APIs novas

| Endpoint | Método | Descrição |
|---|---|---|
| `/api/elevenlabs/clone-voice` | POST | Clonagem IVC escopo workspace. Multipart `{name, description?, preferred_model?, files[]}` → ElevenLabs `POST /v1/voices/add` → registra em `elevenlabs_voices` (workspace_id do workspace atual). Feature guard `funnels`. Audit: `elevenlabs_voice.cloned`. |
| `/api/elevenlabs/voices/[voice_id]` | DELETE | Remove voz da conta ElevenLabs (`DELETE /v1/voices/{id}`) + limpa `elevenlabs_voices` (workspace + globais). 404 da ElevenLabs = segue limpeza local. Audit: `elevenlabs_voice.deleted`. |

## APIs existentes reaproveitadas

- `GET /api/elevenlabs/voices` — lista vozes (proxy ElevenLabs, key: env → workspace_settings → ai_provider_settings → system config)
- `POST /api/automations/generate-audio` — TTS (ElevenLabs + fallback Fish Audio via OpenRouter), salva em `automation_media`
- `POST /api/automations/upload` — upload S3 da gravação
- `POST/GET/DELETE /api/automations/audios` + `[id]` — biblioteca

## Detalhes técnicos importantes

- **Voz favorita**: localStorage `el_voice_{workspaceId}` (mesma chave do dialog do inbox).
- **preferred_model**: coluna pode não existir em bancos antigos → INSERT da clonagem tem fallback sem a coluna (padrão defensivo do generate-audio).
- **Fallback Fish**: se ElevenLabs falhar (sem chave/quota), o generate-audio usa `fish-audio/s2.1-pro-free:free` via OpenRouter — Studio mostra badge "Fish Audio (grátis)".
- **Deleção de voz global**: excluir uma voz remove linhas `workspace_id IS NULL` também (voz some da conta). UI avisa o usuário.
- **Gravação webm**: salvo como audio/webm — WhatsApp pode precisar de conversão p/ OGG no envio (worker já converte para Cloud API em `media.ts`).

## Arquivos criados/alterados

```
app/(dashboard)/studio/page.tsx                        # página com 4 abas
components/studio/tts-panel.tsx                        # TTS
components/studio/record-panel.tsx                     # gravação mic
components/studio/clone-panel.tsx                      # clonagem + lista vozes
components/studio/library-panel.tsx                    # biblioteca
app/api/elevenlabs/clone-voice/route.ts                # clonagem workspace
app/api/elevenlabs/voices/[id]/route.ts                # delete voz
components/layout/sidebar-nav.tsx                      # item no menu (IA)
```

## Motor explícito ElevenLabs vs Fish (14/09/2026 01:30)

Problema: usuário não distinguia as "vozes do Fish" das da ElevenLabs (o Fish não tem lista de vozes — era fallback silencioso).

Solução:
- **Seletor de motor** no topo do TTS panel: ElevenLabs (todas as vozes/emoção) | Fish Audio (grátis, voz padrão pt-BR).
- `POST /api/automations/generate-audio` aceita `provider: 'fish'` → gera direto no Fish (sem tocar na ElevenLabs). Fallback automático mantido quando motor=elevenlabs falha, com `message` explícita.
- Seletor de voz com grupos rotulados e contagem: "👤 Minhas Vozes (clonadas na conta) — N" (ícone usuário violeta) e "🎙️ Biblioteca ElevenLabs — N" (ícone mic ciano).
- Preview mostra badge do motor + aviso quando Fish: "voz padrão pt-BR; vozes/modelo/idioma só se aplicam ao ElevenLabs".
- Motor Fish oculta voz/modelo/idioma/v3 sliders e mostra nota explicativa.

## A/B Comparar + Clonar voz + Importar (14/09/2026 16:30)

Nova aba **Comparar** no Studio (`components/studio/compare-panel.tsx`):
- **Gerar A/B**: mesmo texto gerado em paralelo nos dois motores — lado A ElevenLabs (voz+modelo escolhidos) e lado B Fish (voz padrão). Players lado a lado.
- **Importar para Biblioteca**: botão por lado. Nada é salvo automaticamente no comparador — só o escolhido vai pra `automation_media`.
- API: `POST /api/automations/generate-audio` aceita `save: false` → não grava no S3 nem no banco, retorna só base64 (modo preview p/ comparador).

Novo endpoint **`POST /api/elevenlabs/clone-from-preview`** (`app/api/elevenlabs/clone-from-preview/route.ts`):
- Body `{voice_id, name?}` → baixa a amostra oficial (`preview_url`) da voz de origem → usa como amostra do Instant Voice Cloning → cria cópia da voz na conta e registra em `elevenlabs_voices` (workspace). Audit: `elevenlabs_voice.cloned_from_preview`.
- UI: botão "Clonar esta voz" no TTS panel ao lado de "Ouvir amostra" (aparece só para vozes da Biblioteca, não para vozes já clonadas).

Contexto: Fish via OpenRouter não tem galeria de vozes nem clonagem. Fish oficial (fish.audio) tem — integração futura exige API key própria e créditos (registrada como pendência).

## Galeria de vozes Fish Audio GRÁTIS (14/09/2026 17:30)

Descoberta testada: o endpoint de áudio do OpenRouter (`/api/v1/audio/speech` com `fish-audio/s2.1-pro-free:free`) **aceita `voice: <fish_model_id>`** — testado com a voz "Super Smash Bros Announcer" (audio diferente do baseline, hash distinto). O catálogo fish.audio é público (sem chave): `GET https://api.fish.audio/model?page_size=24&page_number=1&sort=-likes&tag=Portuguese&title=busca`. Filtro por idioma usa tag (`Portuguese`, `English`, `Spanish`...) — o param `language=` NÃO funciona.

Implementação:
- **`GET /api/fish/voices`** (`app/api/fish/voices/route.ts`): proxy autenticado do catálogo público. Params: `tag`, `title`, `page`, `page_size`, `sort` (allowlist -likes/-created_at/likes). Sem chave fish.audio — o catálogo é público.
- **`POST /api/automations/generate-audio`**: aceita `fish_voice_id` (regex hex) → repassa como `voice` para o OpenRouter. Válido para geração e fallback.
- **TTS panel modo Fish**: galeria com chips de idioma (Português default), busca por nome, lista paginada (24/página, "carregar mais"), botão ▶ por voz (gera amostra curta de teste via OpenRouter free, `save:false`) e botão de selecionar (✓).
- Preview badge mostra o título da voz Fish escolhida.
- **Clonar ElevenLabs → Fish**: ainda NÃO possível de graça — OpenRouter não expõe clonagem; exige API key fish.audio paga (pendente).

## Testado: clonagem Fish via OpenRouter NÃO funciona (14/09/2026 18:00)

Pergunta: se o OpenRouter free aceita `voice` (ID de modelo), aceita áudio de referência p/ clonar de graça? Testado empiricamente:

- `references: [{audio: data-uri/base64}]` → HTTP 200 mas **não clona**: pitch da saída não casa com a referência (ref 147Hz→out 200Hz; ref 222Hz→out 139Hz; controle padrão 101-131Hz em 3 execuções). Parâmetro ignorado ou tratado como ruído.
- `voice: "data:audio/mpeg;base64,..."` → HTTP 400 rejeitado.
- Conclusão: OpenRouter free = só vozes públicas do catálogo (`voice: <model_id>`). Clonagem exige fish.audio oficial (API key + créditos) ou ElevenLabs IVC (já suportado no Studio).
- Método do teste: ffmpeg → PCM 16k mono → autocorrelação frame-wise (f0 50-400Hz) via script Node. Não repetir o experimento sem motivo.

## Fish no dialog "Gerar Áudio com IA" do Inbox + favorito na conversa (22/09/2026 22:54)

Depois de o dono reportar que o Inbox "não puxava fishaudio e nem estrela de favoritos", o diagnóstico confirmou **produção desatualizada** (imagem de 43h, sem o dialog novo) — não era bug do código. A galeria Fish só existia no Estúdio (`components/studio/tts-panel.tsx`); o `components/media/generate-audio-dialog.tsx` (usado no Inbox, Templates e Guided Funnels) só tinha estados/funções de Fish adicionados, sem o JSX renderizado.

Implementado (commit N/A — deploy do working tree, build manual):
- **Seletor "Motor de voz"** no dialog: cards ElevenLabs (violeta) vs Fish Audio (âmbar), com reset do preview ao trocar.
- **Galeria Fish Audio** no dialog (mesmo padrão do Estúdio): chips de idioma (PT default), busca por nome, lista paginada (24/pág, "carregar mais"), ▶ amostra curta (`save:false`, não grava), ✓ selecionar voz (badge com o título da voz escolhida), nota "sem voz selecionada = padrão pt-BR".
- `handleGeneratePreview` agora envia `provider:'fish'` + `fish_voice_id` quando o motor é Fish; NÃO exige mais `voiceId` do ElevenLabs nesse modo; controles Voz/Modelo/v3 ficam restritos ao motor ElevenLabs.
- **Favorito do workspace vale na conversa**: antes, conversa sem voz de agente forçava escolher voz manualmente (ignorava o favorito). Agora o favorito é usado também na conversa; só força escolher quando NÃO há favorito (nunca usar a 1ª voz por acaso). Com voz de agente configurada, a voz dela continua vencendo (intencional).
- Fechamento do dialog reseta motor/seleção/busca (reabre em ElevenLabs).

Deploy: `docker build -t zapflix-tech:latest /root/Zapflix-Tech` + `docker service update --image zapflix-tech:latest --force wp_zapflix-web`. Validado: galeria Fish presente no bundle de produção (3 chunks), `/api/fish/voices` respondendo (401 sem sessão), app saudável (SSE/Redis/crons/webhooks OK).

⚠️ Build manual sem `--build-arg GIT_SHA` → `/api/version` mostra `git_sha: "unknown"` (build_time correto). Comportamento conhecido — o `scripts/deploy-web.sh` grava o SHA do HEAD (que não inclui mudanças não commitadas, CC-10).

Validação: `npx tsc --noEmit` limpo; `vitest` 467/469 (2 falhas pré-existentes em checkout/inbox, confirmadas no HEAD limpo; não são desta mudança).
