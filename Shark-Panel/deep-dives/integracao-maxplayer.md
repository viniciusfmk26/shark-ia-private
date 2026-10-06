# Integração MaxPlayer

> Criada em 06/10/2026. Integração do app **MaxPlayer** (plataforma de
> distribuição de IPTV) acionada pelo botão **ATIVAR MAXPLAYER** no Stream Deck.
> O cliente recebe as credenciais do teste do **Shark Titan** e, se o operador
> ativar o botão, o mesmo acesso passa a existir também no app MaxPlayer.

---

## 1. O que foi pedido

Fluxo do dono, por extenso:

> VOU GERAR O TESTE NORMAL SHARK TITAN ELE VAI IR USUARIO E SENHA PARA O
> CLIENTE E EU VOU TER UM BOTÃO NO STREAM DEV QUE VAI SE CHAMA ATIVAR
> MAXIPLAYER ELE VAI SELECIONAR USUARIO E SENHA QUE DEI E VAI MANDAR LA NO
> MAXIPLAYER. SE O CLIENTE NÃO RENOVAR ELE É EXCLUIDO DO PAINEL DO MAXPLAYER
> EM 4 HORAS.

Quebrando em passos:

1. O atendente gera o teste normal no **Shark Titan** (fluxo já existente, não
   foi alterado). Usuário e senha vão para o cliente pelo WhatsApp.
2. O atendente clica no botão **ATIVAR MAXPLAYER** no Stream Deck.
3. O diálogo abre e ele cola o **mesmo usuário e a mesma senha** do teste.
4. O painel cria o cliente na conta MaxPlayer.
5. **4 horas depois, se o cliente não renovar, a conta é apagada do painel
   MaxPlayer.** A ativação paga cancela essa exclusão.

Ponto importante de arquitetura: a ativação **não** é automática junto com o
teste. É uma ação manual, deliberada, do operador. Nenhum cliente é criado na
MaxPlayer sem alguém clicar no botão.

---

## 2. Por que a exclusão de 4h é nossa

Este é o achado que definiu o desenho.

A conta MaxPlayer (`R_Investt_9781`) está em:

```
metered_billing: true
```

E os dois clientes que já existem na conta respondem `GET /customers/{id}` com:

```json
{ "expire_date": null }
```

A API pública v3 **não tem endpoint que escreva o vencimento**:

- `PUT /users/{id}` só altera `max_devices` e `max_profiles`.
- `CustomerDetail.expire_date` é read-only.

Ou seja: a MaxPlayer não expira cliente por conta própria. Se ninguém apagar,
o teste vive para sempre no painel do provedor e consome cota da conta
(hoje `2/500`). Como o dono pediu exclusão em 4h, **a expiração é
implementada no Shark Panel**, via `DELETE /users/{id}` num cron.

Medido na conta: `device-ceiling` = 5, `profile-ceiling` = 5.

---

## 3. Estado da conta MaxPlayer (medido 06/10/2026)

| Item | Valor |
|---|---|
| Base | `https://api.maxplayer.tv/v3/api/public` |
| Autenticação | header `Api-Token` |
| `account_type` | `reseller` (tem `own_domains`, **não** tem acesso `/service-provider`) |
| Account ID | `19835` |
| Service provider | `12466` |
| Usuários | `2` de `500` |
| Rate limit | `60 req/min` (compartilhado por provider) |
| `metered_billing` | `true` |
| Vencimento da conta | `2026-10-16` |
| Clientes existentes | `3911191`, `3974756` — ambos `expire_date: null` |

### Domínio configurado

```
domain_id : 1790914192685289333
domain    : greek-crm.site
port      : 80
https     : 0
```

🔴 **O host não serve nada.** O DNS resolve (`greek-crm.site → 87.76.215.207`,
Hostinger BR, porta 80 aberta), mas a conexão é derrubada antes de qualquer
resposta:

```
TCP connect 87.76.215.207:80  → Conectado
Recv failure: Connection reset by peer   ← :80
Recv failure: Connection reset by peer   ← :443
```

Testado também por IP direto com `Host: greek-crm.site` e na raiz `/` — mesmo
reset. Não é DNS nem problema de vhost.

**Consequência**: os 2 clientes que já existem na MaxPlayer **também não
reproduzem nada**. DNS resolvendo não é o mesmo que domínio funcionando.

Pendência: obter host + porta + se usa HTTPS do servidor de stream correto e
atualizar com `PUT /domains/1790914192685289333`. A documentação do provedor
garante que essa chamada atualiza atomicamente as playlists dos clientes
existentes junto. **Não foi executada** — é mutação real que afeta clientes
existentes.

---

## 4. Modelo de dados

Migration: `migrations/20261006_maxplayer.sql`.

### `iptv_maxplayer_config`

Uma linha por workspace.

| Coluna | Papel |
|---|---|
| `api_token_encrypted` | Api-Token cifrado (AES-256-GCM via `lib/crypto/token-box`). Nunca texto puro. |
| `enabled` | Liga/desliga a integração e o cron |
| `domain_id` | Domínio de stream. `POST /users` exige este campo. |
| `domain_host`, `domain_port`, `domain_https` | Cache só para a tela mostrar. Não são autoridade. |
| `max_devices`, `max_profiles` | Teto do cliente. Limite 5 (medido no provedor). |
| `trial_hours` | Janela antes da exclusão. Padrão `4`. |

### `iptv_maxplayer_activations`

O ciclo de vida do cliente de teste.

```
active ──renovou──> converted   (o cron pula)
   │
   └──4h venceu──> deleted      (DELETE /users/{id} no provedor)
   │
   └──criação recusada──> failed (nada foi criado lá)
```

| Coluna | Papel |
|---|---|
| `request_id` | **Chave de idempotência do clique.** `UNIQUE (workspace_id, request_id)` |
| `maxplayer_user_id` | ID do provedor. `TEXT`, fica `'pending'` entre a reserva e a confirmação |
| `iptv_username` / `iptv_password_encrypted` | Credencial do teste do Shark Titan. Senha cifrada |
| `status` | `active` \| `converted` \| `deleted` \| `failed` |
| `expires_at` | A janela de 4h. **Vive aqui, não no provedor** |
| `delete_error` | Erro do `DELETE` fica gravado em vez de ser perdido |

**Todos os IDs do provedor são `text`, nunca `bigint`/`number`.** O
`domain_id` (`1790914192685289333`) e o `user_id` são 64-bit e passam de
`2^53`; em JavaScript isso perde precisão em silêncio e o ID aponta para outro
cliente.

### Mudança no Stream Deck

`streamdeck_buttons` só aceitava `kind='payment_link'` (CHECK), com
`url NOT NULL` e `amount_cents > 0`. O botão ATIVAR MAXPLAYER não é link de
pagamento, então:

- O CHECK passou a listar `('payment_link','maxplayer_activate')`.
- `url` e `amount_cents` viraram nuláveis.
- O trigger `streamdeck_seed_legacy_link` foi guardado por `NEW.url IS NOT NULL`
  — sem isso ele inseriria uma linha com url nula e estouraria o
  `UNIQUE (workspace_id, url)` na segunda inserção.

A validação de `amount_cents > 0` continua na rota de criação de link de
pagamento (`app/api/streamdeck/buttons/route.ts:63`). O que afrouxa aqui é só
a restrição do banco.

---

## 5. Ordem das operações na ativação

A ordem em `lib/maxplayer/service.ts` é deliberada:

1. **Verifica `request_id` já ativado** → devolve a linha existente. Clique
   duplo não cria dois clientes.
2. **Verifica se o usuário já tem ativação ativa** → devolve a existente.
3. **Reserva a linha no banco ANTES do efeito externo**, com o
   `UNIQUE (workspace_id, request_id)` enfrentando cliques simultâneos.
4. **`POST /users/search` no provedor** antes de criar. `POST /users` com
   identidade repetida devolve 409; se o cliente já existir lá fora, reaproveita
   o id em vez de duplicar.
5. **`POST /users`**, e só então grava o id do provedor.

### Classificação de falha

| Situação | `status` | Motivo |
|---|---|---|
| 400 / 401 / 403 / 404 | `failed` | Recusa documentada: prova que nada foi criado lá |
| 429 / 5xx / timeout | `active`, sem id | **Pode ter criado.** Reenviar criaria duplicata |
| 201 sem `id` na resposta | erro | Ver abaixo |

### A armadilha do `201`

Medido: `POST /users` devolve `201` com
`{"success": true, "status": 201, "message": "Request Accepted"}` **mesmo
quando falta campo obrigatório** (testado sem `domain_id`). O `message` é
humano e não serve como prova. Quem decide validade é o schema: `id` ausente é
estado desconhecido, nunca sucesso.

---

## 6. O cron de exclusão

`POST /api/cron/maxplayer-expire`, registrado em `supercronic.cron`:

```
*/10 * * * * /usr/local/bin/run-crons.sh maxplayer-expire
```

Por que 10 em 10 minutos: a folga de 4h absorve uns 20 ciclos perdidos. 5 em 5
seria desperdício de chamada.

Regras:

- Só toca em `status='active' AND expires_at <= now()`. Quem renovou virou
  `converted` e fica de fora — é o contrato do job.
- Reserva `'pending'` (criação que nunca recebeu id) é ignorada: não há o que
  apagar lá fora.
- **404 no DELETE conta como sucesso.** O cliente já não existe lá, que é o
  estado desejado.
- **5xx e timeout mantêm `active`** com `delete_error` gravado. Marcar como
  apagado perderia o cliente que continua no painel.
- Throttle de 1,2s por DELETE dentro da rota, para não estourar o teto de
  `60 req/min` do provedor.
- `?dry=1` só lista o que seria apagado.
- Só entra em workspaces com `enabled = true` — senão chamaria `/info` de todo
  mundo.

### Autorização

`x-cron-secret`, `x-admin-token`, `x-cron-token` ou `Authorization: Bearer`,
combinados com `CRON_SECRET`/`CRON_TOKEN`. Sem nenhuma dessas env configuradas o
endpoint **recusa** (não é fail-open).

---

## 7. O gancho de conversão

Em `app/api/iptv/sigma-activate/route.ts`, logo depois de gravar as credenciais
Sigma no contato:

```ts
const { markConverted } = await import('@/lib/maxplayer/service');
const converted = await markConverted(workspaceId, username);
```

`markConverted` só toca em `status='active'`, o que tira a linha do alcance do
cron.

Sem este gancho o cliente pagaria e teria a conta apagada em menos de 4h.

O `username` usado aqui é o mesmo `iptv_username` da ativação MaxPlayer,
porque o botão usa as credenciais do teste como login do app.

A chamada é envolvida em `try/catch` e não derruba a ativação paga: a Sigma já
está ativa neste ponto do fluxo. O pior caso é o cron apagar a conta MaxPlayer
depois — visível no histórico.

---

## 8. Botão ATIVAR MAXPLAYER

`components/inbox/maxplayer-activate-dialog.tsx`, montado em
`components/inbox/streamdeck.tsx` ao lado dos links de pagamento.

Por que os campos são digitados e não uma lista suspensa: **a senha não volta da
API**. O provedor também não a devolve. O operador precisa ter o valor do teste
em mãos, então o diálogo pede usuário e senha.

O `requestId` nasce no navegador e vale enquanto o pedido está em voo. Se a
resposta se perder e o atendente clicar de novo, a API devolve a ativação
existente em vez de criar um segundo cliente.

A senha é zerada ao fechar o diálogo — não fica na tela nem no estado do React.

---

## 9. Permissões

| Operação | Papéis |
|---|---|
| Ler config, ver status da conta | `owner`, `admin` |
| Ativar cliente | `owner`, `admin`, `agent` |
| Ver histórico | `owner`, `admin`, `agent` |

O botão vive no Stream Deck da inbox, que qualquer atendente vê, mas a chave da
API é configuração sensível — por isso leitura de config exige admin, e só a
ativação é trabalho de operador.

Todas as rotas filtram `workspace_id` e usam `getActiveWorkspaceId()`.

---

## 10. Estado em produção (06/10/2026)

| Item | Estado |
|---|---|
| Migration | Aplicada em `wp_zapflix-db` |
| Web | `zapflix-tech:maxplayer-20261006` no ar |
| Cron | `easypanel/wp/zapflix-cron:maxplayer-20261006` — rodou às 02:20, `{"ok":true,"workspaces":0,...}` |
| Rotas | `401` sem autenticação (correto) |
| Cron sem token | `401` (correto) |
| Config gravada | `enabled = false`, `domain_id` preenchido |
| Testes | 37 passando |

### Verificações feitas

- Cron autenticado → `200` com `workspaces: 0`.
- Cron **sem** token → `401`.
- `activate` e `status` sem sessão → `401`.
- Cron com `enabled=true` e token inválido → `skipped` com o motivo, **sem
  apagar nada**. Comportamento correto: uma chave quebrada não pode cascatear
  exclusão.
- Cron aparece nos logs do container com `job.schedule="*/10 * * * *"`.
- Reserva no banco validada dentro de `BEGIN`/`ROLLBACK`.

### Não validado em produção

Nada disso foi exercitado com um cliente real, porque o host não serve:

- `POST /users` real.
- `DELETE /users/{id}` real.
- A mensagem para o cliente.

---

## 11. Bloqueio atual

**`greek-crm.site` resolve mas não serve.** O botão vai aparecer, a API vai
responder, o cron vai rodar — e nada vai funcionar de verdade até o host
responder.

Para destravar, é preciso host + porta + se usa HTTPS do servidor de stream
correto. Aí:

```
PUT /domains/1790914192685289333
```

A documentação do provedor garante atualização atômica das playlists dos 2
clientes existentes junto. **Não executar sem o host certo** — é mutação real
em clientes já em produção.

Depois: gravar o Api-Token real (cifrado) e ligar `enabled = true`.

---

## 12. Segredos

O Api-Token foi fornecido pelo dono no chat e **não** está gravado em lugar
algum:

- Não está em código, migration, `.env.example` ou Git.
- A linha de config no banco usa um placeholder (`v1:placeholder-nao-e-token-real`)
  e está com `enabled = false`.
- `TOKEN_ENCRYPTION_KEY` está presente no container web (64 chars) — é ela que
  cifra e decifra o token.

Recomenda-se rotação do token depois que a integração entrar em uso.

---

## 13. Arquivos

| Arquivo | Papel |
|---|---|
| `migrations/20261006_maxplayer.sql` | Tabelas + CHECK do Stream Deck + trigger |
| `lib/maxplayer/schemas.ts` | Zod. IDs como string |
| `lib/maxplayer/client.ts` | HTTP, `Api-Token`, 429, armadilha do 201 |
| `lib/maxplayer/service.ts` | Ordem das operações, idempotência, expiração |
| `lib/maxplayer/auth.ts` | RBAC e tradução de erro |
| `app/api/iptv/maxplayer/config/route.ts` | GET/PUT config |
| `app/api/iptv/maxplayer/status/route.ts` | Status da conta e domínios |
| `app/api/iptv/maxplayer/activate/route.ts` | Cria o cliente |
| `app/api/iptv/maxplayer/activations/route.ts` | Histórico |
| `app/api/cron/maxplayer-expire/route.ts` | Exclusão das 4h |
| `components/inbox/maxplayer-activate-dialog.tsx` | Diálogo do botão |
| `test/maxplayer-client.test.ts` | 13 testes |
| `test/maxplayer-expiry.test.ts` | 6 testes |
| `test/maxplayer-service.test.ts` | 18 testes |

---

## 14. Relato de bug encontrado durante o trabalho

Dois bugs meus, corrigidos antes de qualquer deploy:

1. **O guard de `pending` bloqueava ativações legítimas em paralelo.** A
   reserva usava `maxplayer_user_id='pending'` como valor do unique index, então
   duas ativações simultâneas colidiam. Trocado por `request_id` próprio.

2. **`workspace_id` não vinha em `publicColumns`.** O `UPDATE` do cron saía com
   `workspace_id=undefined` numa coluna `NOT NULL`. Há teste de regressão para
   isso (`test/maxplayer-expiry.test.ts`).

Também um bug no schema: `domainPort` com `.default('')` e regex `^\d{1,5}$` —
o default passa pela validação e string vazia não casa o padrão, então
**salvar a config sem informar porta seria sempre recusado**. Pego pelos
testes, corrigido com `union([literal(''), regex])`.

---

## 15. Notas de build

O build da imagem falhou por código de **outro agente**, não desta integração:

```
app/api/external/crm/v1/[...path]/route.ts:26
Module not found: Can't resolve '@/docs/openapi/crm-integration.json'
```

Esse arquivo existe em disco (JSON válido, `openapi 3.1.0`, 11 paths), mas
`.dockerignore` exclui `docs`, então ele não entra na imagem. A rota é código
não commitado e a imagem de produção atual não a tem.

Para isolar o problema, as rotas de `crm/v1` foram movidas para fora durante o
build e **restauradas em seguida**. Vale confirmar com o dono/agente se o
`crm-integration.json` deve sair do `.dockerignore` ou se a rota deve ler o
arquivo de outro lugar.