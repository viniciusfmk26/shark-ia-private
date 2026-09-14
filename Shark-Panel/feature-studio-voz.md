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
