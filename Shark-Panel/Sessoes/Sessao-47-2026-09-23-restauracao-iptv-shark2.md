# Sessão 47 — 23/09/2026 — Restauração IPTV (Shark Panel → Shark 2) após limpeza de 20/09

## Incidente (diagnóstico concluído)

Entre **20/09 03:00** e **21/09 03:00**, o banco perdeu dados em massa:
- Dump 20/09: 703 MB (814.946 msgs, 10.710 trials, 4 servidores IPTV, 5 bots, 34 app configs).
- Dump 21/09: 109 MB (1.355 msgs, 0 trials, 0 servidores, 0 bots, 0 apps).

**Causa confirmada pelo dono:** deleção de workspaces em 20/09 ("deletei workspace para começar novo") — Fábrica, Shark, Default Workspace foram deletados.

**Causa raiz questionada:** a deleção removeu ~107k msgs daqueles workspaces, mas o **Shark Panel** (`00000000-0000-0000-0000-000000000002`) **não foi deletado** e mesmo assim perdeu 813k msgs + 10.710 trials + 4 servidores → provavelmente algo rodou no banco inteiro naquela janela. **PENDENTE** de explicação adicional do dono (possível reset/restore/script).

## O que foi identificado no backup 20/09 (`postgres_20260920_030002.dump`)

Workspace **Shark Panel** (origem): 4 servidores + 5 bots + 34 `iptv_app_configs` + 13 `iptv_app_favorites` + 10.710 `iptv_trials`.

| Servidor | Base URL | Ativo | trial_hours | followup |
|---|---|---|---|---|
| Shark Streaming | https://paineltop20.top | ✅ | 2 | ✅ 1h |
| PRIMELUX | https://painel.primelux.cloud/ | ✅ | 4 | ❌ |
| EliteBOX | elitebox.sigma.vin | ❌ | 2 | ❌ |
| CINEFLIXBR | https://cineflixbr.sigma.vin/api/chatbot/YgD9Q5NDr6/80m1Eev1lE | ✅ | 2 | ❌ |

Bots: sharks10 (Shark Streaming), P2P BINSTREAM / PRIMELUX / UNITV PRIME (PRIMELUX), CINEFLIXBR (CINEFLIXBR).

## Restauração executada (Opção A — direto no Shark 2, sem trials/mensagens)

- **Destino:** workspace `4a815ba6-e45b-4836-9f22-23c1c3d0370b` (**Shark 2**).
- **Origem:** dump `postgres_20260920_030002.dump` (temp_bk no container `wp_zapflix-db`, FKs dropadas, restaurado parcialmente).
- **Escopo:** `iptv_servers` (4), `iptv_server_bots` (5), `iptv_app_configs` (34). **NÃO** restaurados: `iptv_trials` (10.710) e mensagens — início limpo, decidido com o dono.
- **IDs novos:** todos os registros receberam novos UUIDs (`gen_random_uuid` no gerador), mapeando `server_id` antigo→novo e `bot_id` antigo→novo. Sem conflito com dados existentes.
- **NOT NULL tratados:** produção exige `base_url`, `api_type`, `bot_url`, `bot_path`, `app_codes` — backup tinha NULL; preenchido com defaults (`''`, `'sigma_chatbot'`, `'{}'`).
- **Transação única** com `ON_ERROR_STOP=1`; 2 tentativas com erro (falha de `bot_path NOT NULL`) → ROLLBACK limpo, sem dados órfãos.
- **Verificação pós-restore:** 4 servers ✅, 5 bots ✅, 34 apps ✅. Todos com `workspace_id = Shark 2`, `config_alternativa_id` remapeado.

## Estado atual do Shark 2

- 4 servidores IPTV completos (bots + app configs de cada).
- 13 `iptv_app_favorites` **NÃO** restaurados (ficaram para trás — verificar se o dono quer).
- **Sigma**: Shark 2 tem **0** sigma_servers próprios. Sigma UNIFLIX é `is_global=true` (do Shark Panel) e continua visível; clone via `POST /api/sigma/clone` fica como próximo passo se desejado (Opção A aprovada anteriormente).
- Trials zerados (0) — início limpo confirmado.

## Ações pendentes

1. **Explicar a janela 20/09 03:00→21/09 03:00:** o que rodou no banco inteiro além do delete de workspaces? Prevenir recorrência.
2. Decidir sobre os 13 `iptv_app_favorites` (restaurar? apontar para os novos bots?).
3. Confirmar se o Sigma UNIFLIX precisa ser clonado para o Shark 2 (é global, provavelmente não).
4. Backups: **validar que 22/09 + 23/09 continuam íntegros** — o 23/09 deve conter a restauração.