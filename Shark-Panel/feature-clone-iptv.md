# Clone profundo de servidor IPTV (Shark Panel → Shark 2) — 22/09/2026 23:12

## Contexto

Dono perguntou: "nos apps de iptv eu consigo clonar os servidor do shark panel para o shark 2 com todas configurações?"

**Antes (estado real):** o botão "duplicar" chamava `POST /api/iptv/servers` e criava apenas o registro básico do servidor (`name (cópia)`, `base_url`, `panel_url`, `panel_username`, `panel_password`, `notes`). **NÃO copiava** bots (`iptv_server_bots`), configs de apps (`iptv_app_configs`), nem campos como `api_type`, `is_active`, trial/followup. Ou seja: clonava o "cartão", não a configuração.

## O que é config de servidor vs. config de workspace

Mapeamento do schema (real, via `information_schema` em produção):

| Tabela | Escopo | Copiar no clone? |
|---|---|---|
| `iptv_servers` | servidor | ✅ todos os campos de config |
| `iptv_server_bots` | servidor | ✅ todos os bots com todos os campos |
| `iptv_app_configs` | bot | ✅ todas as configs de apps de cada bot |
| `iptv_servers` campos trial | servidor | ✅ `trial_followup_enabled/delay_hours/message/funnel_id`, `trial_duration_hours` |
| `iptv_checkout_config` | **workspace** (sem `server_id`) | ❌ não pertence ao servidor |
| message-templates | **workspace** (`workspace_settings.settings->'iptv'`) | ❌ não pertence ao servidor |
| `iptv_favorite_bots` | workspace×bot | ❌ runtime (referencia bots antigos) |
| `iptv_trials`, `iptv_generated_tests`, `iptv_logs` | runtime | ❌ não é config |

## Implementação

**`app/api/iptv/servers/[id]/duplicate/route.ts`** (nova, `POST`, nodejs):

1. Busca servidor de origem por `id` + `workspace_id` (404 se não existir).
2. Insere servidor novo com TODAS as colunas de config (api_type, dns_url, trial/followup etc.). **`is_active` vem `false`** — o clone nasce inativo pra revisão antes de ativar. Nome: `"<nome> (cópia)"`; se `slug` colidir, tenta `<nome> (cópia) 2`, `3`… até 20 (loop no 23505).
3. Copia cada bot de `iptv_server_bots` (todos os campos: app_tags, profile_picture_url, app_type, credential_format, is_favorite, favorite_order, duration_hours, max_screens, description, bot_path, type, app_codes, chatbot_url…), guardando mapa `old_bot_id → new_bot_id`.
4. Copia cada `iptv_app_configs` do bot antigo para o bot novo (filtro `bot_id` antigo + `workspace_id`).
5. **Tudo em uma transação** (`tx` do `@/lib/db`) — qualquer falha = ROLLBACK total.
6. Retorna `{ server, bots_copied, configs_copied }` para feedback na UI.

**UI** (`app/(dashboard)/iptv-apps/page.tsx`, `duplicateServer`): agora chama a rota nova e o toast mostra a contagem ("X bots, Y apps. Revise antes de ativar — clone vem inativo.").

## Notas

- Sem impacto no fluxo existente: a rota é aditiva; o botão "duplicar" antigo foi substituído pela chamada nova.
- `iptv_checkout_config` e message-templates NÃO são copiados por serem por-workspace (depois do clone o "Shark 2" herda as mesmas configs de workspace automaticamente).
- Se o dono quiser que o clone JÁ nasça ativo, é mudança de 1 linha (trocar `false` por `s.is_active`).
- Pendência conhecida para validar em produção: clonar um servidor real e conferir bots/apps na UI (agendado 22/09 pós-deploy).