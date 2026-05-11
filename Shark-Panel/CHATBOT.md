# Chatbot — Documentação

> Implementado em 2026-05-11. Chatbot com fluxo visual no canvas SVG, engine integrado ao worker, 9 tipos de nodes.

## Visão geral

Cada workspace pode criar múltiplos **flows** (chatbot_flows). Quando uma mensagem inbound chega no WhatsApp:

1. **Priority 0** no worker (`apps/worker/src/handlers/webhook.ts`) chama `handleChatbotFlow`.
2. Se houver **sessão ativa** (`chatbot_sessions.status='active'`) para o phone → processa o próximo node.
3. Senão, verifica triggers de flows ativos do workspace; se algum match → cria sessão e processa o start node.
4. Se um flow processou a mensagem, as demais prioridades (guided funnel, automações, AI agent) são puladas.

## Tabelas

### `chatbot_flows`
| Campo | Tipo |
|---|---|
| id | uuid PK |
| workspace_id | uuid FK |
| name | text |
| description | text |
| trigger_type | text — `keyword` / `exact` / `any` |
| trigger_value | text |
| instance_id | text (NULL = qualquer instância) |
| status | text — `draft` / `active` / `paused` |
| nodes | jsonb — array de `{ id, type, position: {x,y}, data }` |
| edges | jsonb — array de `{ id, source, target, sourceHandle? }` |
| stats_sent | integer |
| stats_completed | integer |

### `chatbot_sessions`
| Campo | Tipo |
|---|---|
| id | uuid PK |
| flow_id | uuid FK ON DELETE CASCADE |
| workspace_id | uuid |
| contact_phone | text |
| contact_id | uuid |
| current_node_id | text |
| variables | jsonb |
| status | text — `active` / `completed` / `cancelled` |
| started_at, last_activity_at, completed_at | timestamptz |

Index parcial: `(workspace_id, status) WHERE status='active'`.

## Tipos de Nodes (9)

| Type | Data | Comportamento |
|---|---|---|
| `message` | `{ text }` | Envia mensagem (interpola `{variaveis}`) |
| `question` | `{ text, options: [{label,value}], var_name }` | Envia pergunta + opções, aguarda resposta, salva em variável, usa `sourceHandle` da edge para desvio |
| `condition` | `{ variable, operator, value }` | `equals`/`contains`/`starts_with`/`not_equals`/`is_empty`/`is_not_empty` → segue edge com handle `true` ou `false` |
| `delay` | `{ seconds }` | Acumula delay no próximo `send_message` (usado para humanizar) |
| `tag` | `{ tag_name }` | Cria ou usa tag existente; atribui ao contato |
| `assign` | `{ user_id }` | Atribui conversa a atendente (`conversations.assigned_to`) |
| `webhook` | `{ url, method, body }` | Chama API externa |
| `ai_response` | `{ prompt }` | Enfileira job `ai_response` (interrompe fluxo até IA responder) |
| `end` | `{}` | Encerra a sessão (`status=completed`) |

### Interpolação de variáveis

Strings de message/question/ai_response suportam `{nome_var}`. Variáveis disponíveis:
- `last_message` — última mensagem do contato
- Qualquer variável salva por um node `question` (com `var_name`)

## Endpoints

| Método | Rota |
|---|---|
| GET | `/api/chatbot/flows` |
| POST | `/api/chatbot/flows` |
| GET | `/api/chatbot/flows/[id]` (com sessions recentes) |
| PATCH | `/api/chatbot/flows/[id]` (incl. `nodes`, `edges`) |
| DELETE | `/api/chatbot/flows/[id]` |
| POST | `/api/chatbot/flows/[id]/publish` (valida + status=active) |
| POST | `/api/chatbot/engine` `{ workspace_id, phone, message, instance_id, contact_id }` — engine runtime para testes externos |

## Páginas

- **`/chatbot`** — lista de flows com cards (stats, status pill, toggle ativar, editar, deletar)
- **`/chatbot/[id]/edit`** — editor visual canvas
  - **Toolbar à esquerda:** clicar adiciona node no canvas
  - **Canvas central:** SVG com bezier curves; nodes draggable; bolinha azul à direita do node = handle de conexão (clique no source, clique no target → cria edge)
  - **Painel à direita:** edição do node selecionado (textarea, inputs, options de question, operador de condition…)
  - **Header:** Salvar / Publicar

## Engine

`lib/chatbot/engine.ts` (versão Next.js/api) e `apps/worker/src/handlers/chatbot.ts` (versão worker — mesmas regras, sem cross-import).

Loop interno do engine:
- Itera até 25 nodes por chamada (safety limit)
- Para em `question`, `delay`, `ai_response`, `end`
- Atualiza `chatbot_sessions.current_node_id` e `variables`

## Integração no worker

`apps/worker/src/handlers/webhook.ts` agora tem prioridade 0:
```ts
chatbotHandled = await handleChatbotFlow({ pool, workspaceId, contactPhone, contactId, message, conversationId, jobId });
```
Se `chatbotHandled=true`, demais handlers são pulados nessa mensagem.

## Sidebar

Item adicionado em **Automação**: `{ title: 'Chatbot', href: '/chatbot', icon: Bot }`.
