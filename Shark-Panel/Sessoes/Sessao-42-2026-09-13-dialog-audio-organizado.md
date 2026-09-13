# Sessão 42 — Shark Panel
**Data:** 13/09/2026
**Foco:** Organização do dialog "Gerar Áudio com IA" (chatinbox) — vozes agrupadas, favorito explícito, badge de provedor

---

## Contexto

O botão 🎤 "Gerar e enviar áudio com IA" no chatinbox (`components/inbox/composer.tsx:682`) abre `components/media/generate-audio-dialog.tsx`. O dropdown de vozes listava **todas** as vozes da conta ElevenLabs numa lista única (clonadas + biblioteca premade misturadas) e o favorito era salvo automaticamente a cada seleção (impossível desfavoritar). Quando a ElevenLabs falhava, o backend caía em Fish Audio (grátis) silenciosamente — o usuário não sabia qual provedor gerou o áudio.

## Estado mapeado (antes)

| Recurso | Arquivo | Observação |
|---|---|---|
| Dialog gerar áudio | `components/media/generate-audio-dialog.tsx` | voz, modelo, preview, descartável |
| Lista de vozes | `app/api/elevenlabs/voices/route.ts:47` | retorna todas as vozes da conta com `category` (não usada no front) |
| Modelos | hardcoded (4 ElevenLabs) | `eleven_multilingual_v2`, `turbo_v2_5`, `flash_v2_5`, `v3` |
| Fallback Fish Audio | `app/api/automations/generate-audio/route.ts:125-185` | silencioso, `generated_by: fish_audio_fallback` |
| Favorito | localStorage `el_voice_{workspaceId}` | auto-save na seleção, sem toggle |
| Clonagem de voz | ❌ não existe UI | apenas script `scripts/replace-test-clone.ts` |
| Galeria | Switch "Salvar na biblioteca" no dialog | áudios em Automações → Áudios (`automation_media`) |

## O que foi feito

### 1. Dropdown de vozes agrupado (`generate-audio-dialog.tsx`)
- Grupos via `SelectGroup`/`SelectLabel`: **★ Favoritas** / **Minhas Vozes (Clonadas)** / **Biblioteca ElevenLabs**
- Classificação pelo `category` da API ElevenLabs: `cloned`, `professional`, `professional_voice_clone`, `generated`, `custom` → Minhas Vozes; `premade`/desconhecida → Biblioteca
- Voz favorita aparece no grupo de cima e é excluída dos demais (sem duplicar)

### 2. Favorito explícito (toggle ★)
- `handleSelectVoice` não salva mais favorito automaticamente
- Novo botão "★ Favoritar / Remover favorita" abaixo do select (localStorage por workspace, mesmo formato `el_voice_{workspaceId}`)
- Toast de confirmação ao favoritar/desfavoritar

### 3. Badge de provedor no preview
- Backend: respostas de `generate-audio` agora retornam `provider: 'elevenlabs' | 'fish_audio'`
- Front: badge outline no header do preview — violeta "ElevenLabs" / âmbar "Fish Audio (grátis)"
- Título do dialog virou "Gerar Áudio com IA" (sem "(ElevenLabs)", pois há fallback)

## Deploy
- `docker build -t zapflix-tech:latest /root/Zapflix-Tech` + `docker service update --image zapflix-tech:latest wp_zapflix-web` — convergiu OK

## Pendências futuras
- **UI de clonagem de voz** (upload de amostras → `POST /v1/voices/add` ElevenLabs) — hoje só há clone via script/manual no site deles
