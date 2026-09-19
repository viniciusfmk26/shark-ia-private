# Deep Dive — Prospecção (Radar, Operação e Prospecção rápida)

> Última atualização: 18/09/2026 — **atendente por número** (`{{atendente}}` no 1º contato e na IA, commit `5d9f02ba`, worker+web em produção) e fechamento dos 4 pontos do 1º disparo real.

## Visão geral do módulo

Três camadas, do descobrir ao enviar:

1. **Radar Digital de Empresas** — descoberta dos leads (`prospect_radar_leads`, `prospect_radar_audits`, `prospect_radar_lists`). Busca via Google Places, score, classificação de oportunidade (site / chatbot / ambos / nenhuma).
2. **Operação de Prospecção** — o disparo: lista de leads + mensagem + canal + número que envia + trilhos anti-spam (`prospect_operations`, `prospect_operation_leads`).
3. **Campanha + worker** — o envio real, em lotes de um dia, com delay aleatório e janela de horário (`campaign_contact_routes`, `lib/campaigns/dispatch.ts`).

O CRM recebe o lead convertido no pipeline dedicado **"Prospecção B2B"** (`lib/crm/prospect-pipeline.ts`).

## Prospecção rápida (17/09/2026)

Tela única que substitui o fluxo de ~10 passos: **buscar → marcar → escrever → disparar**.

- **Página:** `app/(dashboard)/admin/prospect-quick/page.tsx` + `components/prospect-quick/*`.
  Na sidebar: "Prospecção rápida" (`/admin/prospect-quick`); o wizard antigo virou **"Prospecção (modo avançado)"**.
- **Rota de orquestração:** `POST /api/admin/prospect-quick/launch` (`app/api/admin/prospect-quick/launch/route.ts`, contrato em `types/prospect-quick.ts`).
  Faz, numa tacada: import dos places → lista do Radar → criação da Operação → start. Passos 1–3 numa única transação; o start fora dela.
- **Serviços extraídos** (reuso, zero SQL duplicado — as 4 rotas antigas viraram adaptadores finos):
  `lib/prospect-operations/{start,create,lists}.ts` e `lib/prospect-radar/google-import.ts`.
- **Triagem na própria busca:** `lib/prospect-quick/screen.ts` (função pura) enxertada em `GET /api/admin/prospect-radar/google`. Cada resultado volta com `phoneE164`, `alreadyInRadar`, `alreadyContacted`, `suppressed`, `duplicateInPage`, `preselect` e `blockReason`.
  - Lead frio sem opt-in **vem marcado** (`preselect=true`).
  - `alreadyInRadar` sozinho **não** desmarca (é só informativo — pode já estar no Radar e nunca ter sido contatado).
  - Opt-out, blacklist, "já contatado" e telefone repetido na mesma página desmarcam **e não podem ser marcados à mão**.
  - **Fail-closed:** se as checagens falharem, a busca devolve **500** — nunca "pode contatar" sem verificar.
- **Idempotência (duplo clique):** `prospect_operations.client_request_id` + índice único parcial `uq_prospect_operations_client_request` (`migrations/20260921_prospect_quick_launch.sql`). O segundo clique devolve `{ok:true, already_launched:true}` — sem criar uma segunda operação.
- **Falha do start não perde o trabalho:** a rota devolve 200 `{ok:false, operation_id, list_id, advanced_url}`. As empresas ficam salvas e **nenhuma mensagem** foi enviada; o operador segue pelo modo avançado.
- **Auditoria preservada:** override sem opt-in continua gravando `manual_override_no_optin/_user_id/_at` + evento por lead, agora com `source:'quick_launch'` e `acknowledged_checkbox:true`.
- **Site clicável na lista (17/09/2026, commit `75bfee42`):** o selo "tem site" virou link para `websiteUri` (dado que já vinha na busca em `GooglePlacePreview`) abrindo em **aba nova** — na mesma aba o operador perderia a busca e as seleções. Valor tratado por `lib/utils/url.ts` → `safeExternalUrl` (só http/https; `javascript:` / `data:` / `mailto:` caem para texto morto), com teste em `test/url.test.ts`.
  - ⚠️ Produto: muito "site" de empresa local no Google é na verdade **Instagram/Facebook**. Isso muda o argumento da abordagem (rede social = "não tem site de verdade").

### Limites da v1

- Máximo de **40 empresas** por lançamento (`too_many_places`).
- Em texto livre só **`{{nome}}`** e **`{{atendente}}`** são aceitos (ver seções seguintes); qualquer outra variável ou chave solta = `variables_not_supported`.
- Canal `cloud_api` exige **template aprovado**.
- Os trilhos **nunca vêm do cliente**: a rota usa sempre `PROSPECT_SAFE_DEFAULTS`, `allow_recontact:false` e `batch_auto_advance:false`.

## "Como chamar" por empresa — `{{nome}}` no 1º contato (17/09/2026)

Pedido do dono: personalizar o primeiro contato sem parecer robótico — "Oi, Franciele Valeron!" em vez de "Oi! Aqui é a Julia". Ele escolheu entre duas opções a de **pré-preenchido + revisão humana** (não campo em branco, não IA escrevendo o texto). (A partir de 18/09 existe também `{{atendente}}` — o nome de quem atende o número; ver a seção do fim deste arquivo.)

- **Coluna "Como chamar" na lista** (`components/prospect-quick/results-table.tsx`): aparece **só quando a mensagem usa `{{nome}}`**, uma linha por empresa **marcada**. Botão **"+ nome"** na caixa de mensagem insere o token no cursor; a caixa mostra a **prévia da frase final** do primeiro contato já preenchido. O botão **"+ atendente"** tem o mesmo comportamento para `{{atendente}}`.
- **Pré-preenchimento determinístico, sem LLM** (`lib/prospect-quick/salutation.ts` → `suggestSalutationInfo`): corta o nome do negócio em segmentos (`|`, `/`, `,`, `-`, travessões), remove título e profissão ("Dra.", "Nutricionista", "Pediátrica", "em Pelotas") e devolve o primeiro segmento que parece **nome de pessoa**. Se não achar (marca/loja), devolve o primeiro segmento como veio e marca `personName:false` — a lista mostra **"confira"** em âmbar. Nunca devolve vazio; corta em 80 caracteres.
  - Validado contra os **6 resultados reais** da busca "nutricionista em Pelotas" do dono: 6/6 corretos.
  - Motivo de não usar IA aqui: é instantâneo para 40 linhas, não gasta chamada de API e não alucina. O operador revisa por cima.
- **Motor único da sintaxe:** `lib/campaigns/lead-vars.ts` (puro, sem banco/HTTP) — `findLeadVars`, `hasLeadVars`, `unknownLeadVars`, `hasBrokenLeadVarSyntax`, `applyLeadVars(text, values) → {text, missing}`. Testes em `test/campaign-lead-vars.test.ts`.
  - **`{{1}}` não é texto livre:** é placeholder de template oficial, resolvido por `lib/campaigns/template-utils.ts`. Os dois engines são separados de propósito.
- **Coluna por OPERAÇÃO, não por lead:** `prospect_operation_leads.salutation_name` (`migrations/20260922_prospect_lead_salutation.sql`, aplicada — id **727**). O mesmo lead pode ser abordado de formas diferentes em Operações diferentes, e o que vale é o texto que o operador revisou **para aquele disparo**.
- **⛔ Nunca sai mensagem com buraco** (regra inegociável): variável sem valor **não** vira string vazia nem "Olá, tudo bem?" genérico.
  - Na tela: a rota recusa o lançamento **inteiro** com `missing_salutation` (400, listando as empresas que faltam) — antes de criar Operação/lista/campanha.
  - Como garantia final: o `dispatch.ts` marca o destinatário como **`failed`** com `error_message = variavel_sem_valor:nome` em vez de enfileirar. Cobre wizard, retry e auto-advance, que não passam pela tela rápida.
  - `failed` **não** conta como "já contatado" (`lib/prospect-operations/contact-history.ts` só olha `sent`), então dá para corrigir o nome e reenviar.
- **Mapa do dispatch:** `buildSalutationMap` em `lib/campaigns/lead-context.ts`, mesma chave dupla de telefone do `leadContextMap` (dígitos sem `+` e E.164 canônico). Falha ao **ler** o mapa **aborta o lote** (nada é escrito, o lote continua disparável) — mesmo critério já definido para o áudio por lead no plano (E5).

## Trilhos de segurança (inegociáveis)

- **Prospecção fria sem opt-in liberada PELO DONO**, com trilhos: teto diário, teto por número, delay aleatório 45–120 s, janela 9–18h seg–sex, um lote = um dia.
- **Override sem opt-in ⇒ o lote seguinte é SEMPRE manual** (decisão do dono).
- **Opt-out / blacklist / quality RED / humano assumiu / dedup nunca são contornados** por nenhum caminho (nem pela tela nova).
- **Dedup anti-recontato:** `lib/prospect-operations/contact-history.ts` marca "Já contatado" pelo histórico de `campaign_recipients` de campanhas de prospecção do workspace (janela default 60 dias).
- **O agente nunca parece IA** e **nunca promete chamada de humano** (cria nota interna + fila "Aguardando humano" + sino).
- **Nunca disparar para cliente real** nem iniciar Operação sem decisão do dono.

## Arquivos principais

```
app/(dashboard)/admin/prospect-quick/page.tsx   → tela única
components/prospect-quick/                      → search-form, results-table,
                                                  message-box, channel-picker,
                                                  responder-picker, launch-dialog
app/api/admin/prospect-quick/launch/route.ts    → orquestração (import+lista+operação+start)
types/prospect-quick.ts                         → contrato da rota
lib/prospect-quick/screen.ts                    → triagem pura (preselect/blockReason)
lib/prospect-quick/salutation.ts                → sugestão determinística de "Como chamar"
lib/instances/attendant-name.ts                 → nome de quem atende (web; gêmeo no worker)
lib/campaigns/lead-vars.ts                      → engine das variáveis {{nome}}/{{atendente}} (puro)
apps/worker/src/lib/attendant-name.ts           → gêmeo + applyAttendantToPrompt ({{atendente}} na IA)
lib/campaigns/lead-context.ts                   → lead_context + buildSalutationMap
lib/prospect-operations/                        → core, create, lists, start,
                                                  safety-rails, contact-history
lib/prospect-radar/                             → core (score/oportunidade), audit,
                                                  google-import, auth
lib/campaigns/dispatch.ts                       → teto de 24h + janela dentro do dispatch
lib/crm/prospect-pipeline.ts                    → pipeline "Prospecção B2B"
apps/worker/src/lib/lead-context.ts             → injeta "EMPRESA PROSPECTADA" no prompt
```

## Migrations relacionadas

```
20260915_prospect_radar.sql
20260916_prospect_operations.sql
20260916_prospect_radar_lists.sql
20260916_prospect_manual_override.sql
20260916_google_auto_selection.sql
20260916_google_place_details.sql
20260916_google_place_backfill.sql
20260918_radar_lead_place_fields.sql
20260918_lead_opportunity_context.sql
20260919_operation_recontact.sql
20260919_prospect_lead_niche.sql
20260921_prospect_quick_launch.sql   ← client_request_id + índice único (aplicada, id 726)
20260922_prospect_lead_salutation.sql ← "Como chamar" por Operação (aplicada, id 727)
```

## Pegadinhas conhecidas

- **Dois sistemas de lista:** o módulo legado de Receita Federal usa `prospect_lists`/`prospect_list_items` (`/admin/prospeccao/listas`); o Radar usa `prospect_radar_lists`/`prospect_radar_list_members`. **Não há ponte automática** entre eles.
- **`alreadyInRadar` ≠ "não contatar":** só significa que o lead já está na base do Radar.
- **`dispatch_run_at` não conhece dia da semana** — sábado e domingo contam (pendência conhecida).
- **Auditoria "não medido" ≠ "não tem":** widget de chat ausente/NULL nunca é tratado como ausência confirmada.
- **Env do worker cai no redeploy:** `GROQ_API_KEY*` e `NVIDIA_API_KEY` adicionadas por `docker service update --env-add` são apagadas quando o Easypanel redeploya — precisam estar cadastradas na UI.
- **`eligibility` tem CHECK FECHADO em 6 valores** (`eligible`, `blocked_no_phone`, `blocked_no_optin`, `blocked_suppressed`, `blocked_duplicate`, `blocked_already_contacted`) e é lido pelo wizard, pelo `summary` e pelo start. **Não** criar valor novo para "lead sem nome" sem revisar os três — por isso a falta de "Como chamar" é recusada **antes** de criar a Operação (`missing_salutation`) + garantia no dispatch.
- **Chave solta escapa da validação de variável:** `{{` sozinho não casa com o regex de token (`{{nome}}`/`{{atendente}}`), então passaria por `unknownLeadVars` e chegaria **literal no WhatsApp do cliente**. Por isso existe `hasBrokenLeadVarSyntax`, checado na tela **e** na rota. (Ela tira **todo** token bem formado antes de procurar chave solta — antes só `{{nome}}`, então `{{atendente}}` era acusado de "chave sobrando".)
- **`{{nome}}` em campanha sem Operação:** o dispatch aborta com 400 `lead_vars_unavailable` (não há de onde tirar o nome). Antes desta entrega o token ia literal para o cliente.
- **Gate do dispatch é "tem qualquer token", não "tem `{{nome}}":** o bloco de resolução roda para qualquer variável, então um `{{cidade}}` que entrou por wizard/API (que não passa pela tela rápida) falha o destinatário em vez de vazar o token. Não afrouxar esse gate.

## 17/09/2026 (noite) — dois achados do primeiro uso real (commit `414d07a3`)

O dono usou a tela rápida em produção e reportou dois problemas. **Nenhum era disparo quebrado** — os dois eram defeito de tela.

### 1. "Fiz um disparo e não apareceu o que mandei no inbox"

**Nada se perdeu.** Disparo feito 17/09 às **18h18**; a janela da Operação é **9h–18h**, e o `dispatch_run_at()` (Postgres, `America/Sao_Paulo`) empurra o lote para a próxima abertura ⇒ a mensagem foi agendada para **18/09 às 09:00**. Diagnóstico do dado real: Operação `e35cdf7a-…` (`running`), campanha `9c7b530a-…` (`sending`, 1 destinatário, 0 enviados), job `e537cccf-…` **`queued`** com `run_at = 2026-09-18 09:00:00-03`, conversa `c27efdb5-…` criada e **vazia**.

O comportamento está **correto**; o defeito era a tela dizer "Disparo iniciado" e não avisar. Correção:

- **Antes do clique:** `lib/prospect-quick/send-window.ts` (`describeSendWindow`, puro, roda no cliente) — relógio de `America/Sao_Paulo` via `Intl` (nunca `getUTCHours() - 3`, o bug já catalogado em `media.ts`). O passo de confirmação mostra "Fora da janela de envio (9h às 18h) … a 1ª mensagem sai amanhã (18/09) às 09:00".
- **Depois do clique:** a rota devolve `first_send_at` = `MIN(run_at)` do 1º job `send_message` `queued` da campanha — **fonte autoritativa**, não uma regra de janela duplicada no cliente. Só vira aviso quando o horário está **>5 min no futuro** (dentro da janela o job sai em segundos). Falha na leitura não derruba o lançamento (campo informativo).
- Teste: `test/prospect-quick-send-window.test.ts` (8 casos: bordas 09:00/18:00, madrugada, virada de mês, o caso real 18h18 e o fuso — 21h BRT = 00h UTC do dia seguinte).

### 2. "Está buscando com site e leads frios; na engine anterior conseguíamos leads quentes"

A tela rápida havia perdido duas coisas que o Radar antigo tinha (`app/(dashboard)/admin/prospect-radar/page.tsx`):

- **Filtros:** a rota `GET /api/admin/prospect-radar/google` sempre aceitou `website=any|missing|present` e `min_score` (defaults `any`/`0`), mas a tela rápida mandava os defaults. Agora tem **Presença de site** (default **"Só quem NÃO tem site"** = `missing`) e **Score mínimo**.
- **O score era jogado fora:** `preliminaryScore`/`preliminaryLabel` vinham do servidor desde sempre e não apareciam. Cada linha agora mostra `Alta 75/100` (sem site = **+55** em `scorePreliminaryPlace`). A lista **já vinha ordenada** por score — só não dizia.
- **Efeito colateral conhecido:** o filtro é aplicado **depois** do fetch do Google (não há como pedir "40 sem site"), então "só sem site" pode devolver menos linhas que a quantidade pedida. A lista vazia agora distingue "faça uma busca acima" de "a busca não trouxe nada com esses filtros" (`searched`).

### 3. Dado real corrigido de passagem

`salutation_name` sugerido para "Dra. Gabrielle Carvalho **Fisioterapeuta Pélvica**" saiu **"Gabrielle Carvalho Pélvica"** — a heurística tratava "Pélvica" como sobrenome. `ROLE_WORDS` (`lib/prospect-quick/salutation.ts`) ganhou a família de adjetivos de especialidade (pélvica, ortopédica, dermatológica, ginecológica, obstétrica, urológica, oncológica, capilar, facial, corporal, postural, respiratória, esportiva, infantil, geriátrica, funcional, estética…) ⇒ **"Gabrielle Carvalho"**. Caso real virou teste.

### Verificação e deploy

- `tsc` web = 0; 36 testes novos/afetados verdes; suíte completa **sem regressão** (mesmas 6 suites / 2 testes pré-existentes: módulo de Client Component em campaigns/checkout/settings/webhooks/resellers-withdraw e `inbox.test.ts`).
- **Nenhuma migration** nesta rodada. Commit `414d07a3` → push (worker redeployou, 8/8 chaves repostas) → build de clone limpo → `wp_zapflix-web` convergiu → `/api/version` = **`414d07a3`** (build_time 2026-09-17T21:40:36Z).
- Rotas conferidas: `GET /admin/prospect-quick` = 307, `POST /api/admin/prospect-quick/launch` = 401, `GET /api/admin/prospect-radar/google` = 401 (sem sessão). Log do web sem erro novo.

## 17/09/2026 (noite, 2) — inbox mostrava "conversa fantasma" do disparo agendado (commit `5fde5f1a`)

Logo depois do primeiro disparo: "abriu a conversa dela no inbox mas eu não mandei nada". A mecânica está **certa** (a conversa nasce no agendamento, a mensagem só nasce no envio — e o lote caiu para 18/09 09:00), mas a conversa era criada com `last_message_at = NOW()` e `last_message_from_me = false` (default) — **fingindo atividade**: aparecia no **topo** da lista com prévia vazia e com a tarja **"⏳ aguardando"** contando desde a criação (chegou a 3h em vermelho).

**O que NÃO acontecia** (conferido, não presumido): badge de não-lidas intacto, janela 24h do WhatsApp intacta (ela olha mensagens, não a conversa) e o winback do worker não captura essas conversas (`last_message_from_me = false AND last_message_at > NOW() - 24h` → com NULL falha fechado).

**Correção (opção A, escolhida pelo dono):** a conversa nasce "sem ninguém ter falado" (`NULL`/`NULL`; o worker carimba no envio real, em `apps/worker/src/handlers/media.ts`) e o inbox passa a **explicar** o agendamento:

- `lib/inbox/scheduled-send.ts` (novo, puro): "hoje às 09:00" / "amanhã às 09:00" / "18/09 às 09:00", dia decidido em `America/Sao_Paulo` (+6 testes).
- `lib/server/inbox.ts`: LATERAL devolve `scheduled_send_at` = `MIN(run_at)` do job `send_message` **queued com >5 min de folga** (sem o corte, um lote disparando agora piscaria o selo em todas as conversas). Usa `idx_jobs_queue`, **0,2 ms** medidos. **(18/09) passou a devolver também o texto e o tipo de mídia** — ver "Prévia do envio agendado" no fim do arquivo.
- Lista: prévia vira "🕐 Agendada para amanhã às 09:00"; thread vazia explica o agendamento em vez de "envie uma mensagem". **(18/09) a lista mostra a prévia do texto** ("🕐 Agendada para amanhã às 09:00 · Oi! Aqui é a Larissa…") e a thread mostra o balão programado com o texto exato.
- ⚠️ `lastMessageTime` virou `string | null` **de propósito** — o `tsc` apontou os 4 consumidores que assumiam horário presente (SLA de 15 min, filtro "Sem resposta", dedup por telefone, `StateSlot`) e cada um ganhou tratamento explícito; `new Date(null)` = 1970 virava "01/01".
- ⚠️ `lastMessageFromMe` não colapsa mais `null → false`: a tarja "aguardando" testa `=== false`, e "ninguém falou" ≠ "o cliente está esperando".
- ⚠️ Paginação: se a página termina numa conversa sem horário (elas ordenam por último), `hasMore = false` — cursor nulo viraria `cursor=null` e derrubaria o cast no Postgres.
- **Dado real corrigido:** a única conversa nesse estado (a da Dra. Gabrielle) foi ajustada à mão (`UPDATE` de 1 linha, com guarda `NOT EXISTS (messages)`); o agendamento de 18/09 09:00 segue intacto.
- **Validação:** o SELECT inteiro do `getConversations` foi remontado com os mesmos fragmentos e rodado no Postgres de produção **antes** do deploy (exit 0); para a conversa dela, `scheduled_send_at = 2026-09-18 09:00:00-03`.

**Deploy:** commit `5fde5f1a` → push (worker redeployou, 8/8 chaves repostas) → build de clone limpo → `/api/version` = `5fde5f1a` (build_time 2026-09-17T22:27:15Z). Rotas conferidas de dentro do container (a app escuta na **porta 80**, `PORT=80`): `/api/version` 200, `/admin/prospect-quick` 307→login, `/admin/inbox` 307→login, `/api/inbox/conversations` 401, `/api/admin/prospect-quick/launch` 401, `/api/admin/prospect-radar/google` 401. Log do web/worker sem erro novo.

**Varredura dos 14 `INSERT INTO conversations` do repo (18/09) — o "sintoma irmão" era alarme falso.** Só o `dispatch.ts` criava conversa **aberta** com atividade falsa. `background.ts:1655` (cobrança) insere a mensagem logo depois e carimba `last_message_at`/`last_message_from_me = true` na linha `1708`; `auto-campaigns:613` nasce **`closed` de propósito** (comentário do próprio código: "conversa de broadcast nasce FECHADA — não polui o inbox aberto"); os demais (`trial-followup`, `amplopay-webhook`, `webchat/*`, `sync`, `import-history`) também têm mensagem na sequência. **Medido no banco:** **0** conversas em produção no estado fantasma (`status='open'` + nenhuma mensagem + `from_me=false`); as 773 nesse padrão são `closed` (broadcast/import, 19/04→16/09) e não aparecem no inbox aberto. Nada a corrigir nesses caminhos críticos.

## 18/09/2026 — fechamento dos 4 pontos do 1º disparo real

1. **`salutation_name` da linha real corrigido.** `prospect_operation_leads cdcc4fe4-…` foi de `'Gabrielle Carvalho Pélvica'` para `'Gabrielle Carvalho'` (1 linha, guardado pelo valor antigo). Era a única das 5 linhas da operação com valor suspeito. ⚠️ **Impacto na mensagem enviada = zero**: o texto da campanha **não usa `{{nome}}`** (conferido no payload do job agendado, não presumido) — a correção vale para as próximas campanhas que usarem a variável. Função validada contra os 5 nomes reais: "Daiane Nogueira - Nutricionista" → Daiane Nogueira, "Nutricionista Andressa Mello" → Andressa Mello, "Nutricionista Sabrina Ribes Zibetti" → Sabrina Ribes Zibetti, "Nutricionista Stéfani Biavaschi" → Stéfani Biavaschi. Limitação conhecida e **não** corrigida (não há caso real nos 25 leads do radar): prefixo de estabelecimento antes de honorífico, ex. "Clínica Dra. Ana Paula Souza - Dermatologia" → "Clínica Dra. Ana Paula Souza".

2. **Identidade do chip ≠ persona — resolvido em 18/09 pela diretriz "atendente por número".** Lido direto da Evolution API (read-only): chip da operação `e6e1c0f8-…` (descrição "Cubot2") = número `555391440074` com **profileName "Larissa Mendes"**; chip de disparo `31cdcb01-…` = `555381004072`, **"Gabriele Garcia" no painel mas profileName "Kerolayne Gonzaga"**. A persona do produto era **Julia** fixa (`ai_agents.name = "Julia (Amigo por Voz)"`, cloud_api "Julia Abreu"/"Julia Abreu Suporte", mensagem "Aqui é a Julia, da Ambern"). **Efeito:** o lead via "Larissa Mendes" na notificação e lia "Aqui é a Julia". Decisão do dono: não renomear perfil de chip (é identidade de pessoa real e ação externa visível) — o **texto e o agente passam a usar o nome da instância** (`whatsapp_instances.name`). Ver a seção "Atendente por número" abaixo.

3. **Varredura do "mesmo padrão" nos 14 `INSERT INTO conversations`:** alarme falso, nenhum código novo tocado. Ver o bloco acima (0 conversas no estado fantasma em produção; `auto-campaigns` nasce `closed` de propósito).

4. **Filtro "Só quem NÃO tem site" mantido como default** — foi o que motivou o relato original ("está buscando com site e leads frios"); a alternativa está a um clique e o selo `Alta 75/100` + "sem site" explica a lista.

## Pendências / próximos

- Outras variáveis na tela rápida (`{{empresa}}`, `{{cidade}}`, `{{nicho}}`, `{{dor}}`) — o plano E3 previa todas; o dono aprovou entregar `{{nome}}` e (18/09) `{{atendente}}` primeiro. O motor em `lib/campaigns/lead-vars.ts` já está pronto para receber mais.
- Aviso (não bloqueio) de opt-out/origem no **wizard** (parte do E3 que ficou fora desta fatia; a tela rápida já tem o checkbox de ciência de opt-in no modal).
- Retorno agendado ("me chama depois") — WIP em `apps/worker/src/lib/return-time-parse.ts` + `migrations/20260921_agent_followup_scheduling.sql` (ainda **não** aplicada/commitada).
- `dispatch_run_at` ignorando fim de semana (continua; agora pelo menos a tela avisa o horário real).
- **Saudação por 1º nome ou nome completo? (dono decide)** — hoje `{{atendente}}` resolve para o **primeiro nome** ("Larissa"). Se o dono quiser o nome completo, é só o `resolveAttendantName` (2 cópias) + testes.
- **Campo dedicado "nome do atendente" por instância? (dono decide)** — hoje deriva de `whatsapp_instances.name`, que é o rótulo exibido no painel. Quem quiser "Atendimento" no painel e "Larissa" na mensagem precisa desse campo.
- Renomear o agente no painel de "Julia (Amigo por Voz)" para algo sem nome fixo (decisão do dono; cosmético).
- **Aviso pós-disparo ✅ resolvido em 17/09 (commit `414d07a3`)** — o modal mostra `first_send_at` lido do job.
- **Filtros de lead quente ✅ resolvido em 17/09 (commit `414d07a3`)** — Presença de site (default sem site) + score visível na lista.
- **Conversa agendada mostrando "aguardando" ✅ resolvido em 17/09 (commit `5fde5f1a`)** — conversa nasce sem atividade e o inbox mostra "Agendada para …".
- **Varredura do "mesmo padrão" ✅ fechada em 18/09** — alarme falso, medido no banco (0 casos abertos).
- **`salutation_name` da linha real ✅ corrigido em 18/09** (1 `UPDATE` guardado).
- **Identity do chip ✅ resolvido em 18/09** — não se renomeia perfil de WhatsApp; o texto e o agente usam o nome da instância (`{{atendente}}`). O disparo de 18/09 09:00 saiu com "Aqui é a Larissa".
- **Linha antiga corrigida à mão ✅** — a conversa da Dra. Gabrielle teve `last_message_at`/`last_message_from_me` zerados.

## 18/09/2026 — Atendente por número: `{{atendente}}` no 1º contato e na IA (commit `5d9f02ba`)

Diretriz do dono: "são vários números, cada 1 com seu nome e atendente — [a mensagem] tem que se adaptar ao nome da instância que está disparando".

O problema tinha **duas metades**, e as duas apareciam no mesmo contato:

1. **1º contato:** o texto dizia "Aqui é a Julia" fixo. Disparado pelo chip "Larissa Mendes", o lead recebia notificação de "Larissa Mendes" e abria "Aqui é a Julia".
2. **Respostas da IA:** o system prompt do agente SDR (`ai_agents` `3ae8ac1f-…`) começa com "Você é a Julia, consultora da Ambern" e tem mais 2 ocorrências. Quem respondesse seria atendido por "Julia" mesmo tendo recebido mensagem de "Larissa" — incoerência no 1º minuto da conversa.

**Fonte única do nome:** `whatsapp_instances.name` — a mesma coluna que a tela rápida já usa para mostrar o chip. `profile_name` (Evolution) **não** é lido: é o nome do perfil da pessoa real, muda por fora do sistema e já divergiu do painel (ver item 2 acima). O rótulo do painel é o que o dono controla.

### Código (12 arquivos, `5d9f02ba`)

- `lib/instances/attendant-name.ts` (puro): `resolveAttendantName(raw)` → primeiro nome (`"Larissa Mendes"` → `Larissa`, `"Dra. Gabrielle Carvalho"` → `Gabrielle`, `"Julia Abreu De Melo 5137"` → `Julia`) ou `null`. `null` é para rótulo que **não é nome de gente**: termos genéricos ("Atendimento", "Suporte", "Comercial"), tipos de estabelecimento ("Clínica", "Salão", "Barbearia", "Studio", "Ótica"), rótulos sem nome ("Cubot2", "01", "teste") e sobras de separador. Corta em separador (` - `/` – `/`|`/`/`/`(`/`:`), rejeita dígito e <2 letras, capitaliza a inicial.
- `apps/worker/src/lib/attendant-name.ts` (**gêmeo**): o worker não importa de `@/lib` (o build copia só `apps/worker/`, `rootDir ./src`) — mesma solução de `agent-profile.ts`. Acrescenta `applyAttendantToPrompt(prompt, rawName)` e `ATTENDANT_FALLBACK = 'Julia'` (no prompt não existe "não responder"; no 1º contato existe, e lá `null` recusa o envio).
- `test/attendant-name.test.ts`: importa **os dois** módulos e compara **34 casos**. Paridade é teste, não confiança — se um lado mudar, quebra.
- `lib/campaigns/lead-vars.ts`: `LEAD_VARS = ['nome','atendente']`; `hasBrokenLeadVarSyntax` passou a tirar **qualquer** token bem formado antes de procurar chave solta.
- `lib/campaigns/dispatch.ts`: resolve `{{atendente}}` por destinatário com a instância sorteada; sem valor → `failed` (`variavel_sem_valor:atendente`). Gate do bloco = "o texto tem qualquer token".
- `app/api/admin/prospect-quick/launch/route.ts`: novo erro `missing_attendant_name` (só em texto livre, e depois de `validateOperationReferences`); gate do "Como chamar" agora testa `findLeadVars().includes('nome')`.
- Tela: `DEFAULT_MESSAGE` com `{{atendente}}`, botão "+ atendente", prévia com os dois tokens resolvidos, e o seletor de número mostra "Quem atende este número: Larissa" (ou aviso vermelho se o rótulo não permitir saber).
- Worker `apps/worker/src/handlers/ai.ts`: `applyAttendantToAgentPrompt` com cache de 5 min por instância (1 SELECT; **zero** query quando o prompt não tem `{{`). O prompt guarda o token — o nome nunca fica congelado no banco.
- ⚠️ `handleAIResponse` (webchat) **não** troca o token: webchat não tem instância de WhatsApp.
- **Ordem de deploy importa:** worker **primeiro**, depois o `UPDATE` do prompt. Invertido, o token ficaria literal no prompt.

### Aplicado em produção (18/09)

Deploy: push `5fde5f1a..5d9f02ba` (levou junto o commit de docs local `a6c6050e`) → worker auto-buildado com as 8 chaves repostas → web buildado de clone limpo → `/api/version` = `5d9f02ba`. Smoke (porta 80, `redirect:'manual'`): telas 307→login e APIs 401 (auth intacto).

**Dado do 1º envio real corrigido junto** (o job já estava materializado e ia sair 18/09 09:00 com "Julia"): `jobs.payload.text` → "Aqui é a **Larissa**"; `campaigns.message` e `prospect_operations.message_text` → `{{atendente}}` (molde dos próximos disparos, o dispatch resolve); `prospect_operation_leads.opening_text` → literal (registro do que foi enviado e contexto do agente); `ai_agents.system_prompt` → **3 tokens, 0 "Julia"**. Todos os `UPDATE` guardados por `LIKE '%Julia%'` (idempotentes) e com backup prévio.

Verificação dentro do container do worker, com o prompt real e a instância real: `applyAttendantToPrompt` devolveu "Você é a **Larissa**, consultora da Ambern…" (sem token restante) e `"Cubot2"` caiu no fallback "Julia". **Não foi preciso enviar mensagem para validar.**

### Auditoria dos números ativos e nomes resolvidos (18/09)

Passados os 9 rótulos ativos pelo resolvedor: **8 resolvem, 1 bloqueia**. Larissa Mendes→Larissa, Amanda Soares→Amanda, Brenda Silva→Brenda, Caren LMA→Caren, Gabriele Garcia→Gabriele, Julia Abreu→Julia, Julia Abreu De Melo 5137→Julia, Julia Abreu Suporte→Julia. **Projeto Salmos→`null`** (bloqueia o disparo — correto, é número interno, não nome de gente).

- ⚠️ **"Julia Abreu Suporte"** resolve para **Julia**, mas o `profile_name` dela na Evolution é **"Denise Ximenes"** — pendente de decisão do dono (renomear o rótulo para Denise ou manter Julia). Enquanto não decidir, quem receber desse número é atendido como "Julia".
- As outras 4 instâncias da workspace (`Atendimentos Uniflix`, `Caren Atomos`, `Denise`, `Julia Abreu 47`) estão **deletadas** (`deleted_at`) — não entram.
- **Agente renomeado (18/09, decisão do dono):** `ai_agents` `3ae8ac1f-…` de **"Julia (Amigo por Voz)"** para **"SDR Ambern"** (só `name`, 1 linha, `updated_at` atualizado; prompt intacto — conferido: 3 `{{atendente}}`, 0 "Julia"). `name` do agente é usado só para exibição/ordenação (`ORDER BY a.name` no seletor de agente do inbox e `agentName` na sugestão) — nada roteia por ele. Existe um **duplicado inativo** (`6c0d990b-…`) ainda chamado "Julia (Amigo por Voz)"; não foi tocado.

### Ligação com a pendência antiga `display_name` (jul/2026)

A sessão `2026-07-12_a_2026-07-16_inbox-chatbot-meta-instagram.md` já pedia "`display_name` por instância (Julia Abreu→Julia, Denise, …)". A coluna **existe** em `whatsapp_instances` mas está **quase toda vazia** (medido em 18/09: só `Julia Abreu 47` = "Julia Abreu De Melo"; as outras 12 vazias) e nenhum código a lê ou escreve. Esta entrega resolve a necessidade **sem** depender dela, usando `name`. Se o dono quiser manter "Atendimento"/"Suporte" no rótulo do painel e ainda assim ter "Larissa" na mensagem, o caminho é: começar a usar `display_name` como fonte preferencial no `resolveAttendantName` (2 cópias + testes) e criar o campo na tela de instância.

### Prévia do envio agendado no inbox (18/09, pedido do dono)

O dono perguntou "onde vejo a mensagem programada? e é áudio ou texto?" — a resposta revelou uma lacuna de tela: o selo mostrava o **horário**, mas o **texto** não aparecia em lugar nenhum do painel. Resposta factual antes do código: é **texto** (`jobs.payload`, sem `attachments`), vindo de `campaigns.message` sem `message_media_url/type`.

- `lib/server/inbox.ts` (LATERAL `sch`): de `MIN(j.run_at)` para **primeiro job por `ORDER BY run_at LIMIT 1`**, devolvendo `scheduled_at`, `payload->>'text'` (já **materializado** — o dispatch resolve `{{nome}}`/`{{atendente}}` no enfileiramento, então a prévia é o texto EXATO que o cliente recebe) e o tipo de mídia (`attachments[0].isPtt`/`type`) para envios só-áudio/imagem. Mesma varredura indexada (`idx_jobs_queue`).
- Lista (`conversation-row.tsx`): "🕐 Agendada para amanhã às 09:00 **· Oi! Aqui é a Larissa…**" (truncado; áudio sem texto → "🎤 Áudio").
- Thread (`chat-view.tsx`): **balão programado** — borda tracejada + fundo sky, à direita (como "de mim"), com o texto exato e a tag "🕐 Agendada para …" logo abaixo; conversa **sem** agendamento continua no EmptyState normal.
- ⚠️ O balão é prévia do JOB, não `INSERT INTO messages`: `messages` continua vazio até o envio real (não afeta badge, janela 24h, dedup). Visual tracejado de propósito para não parecer mensagem enviada.
- Deploy: commit `6432c543` → push + 8/8 chaves no worker → build de clone limpo → `/api/version` = `6432c54` (04:28Z). Suíte sem regressão; SQL validado contra a conversa real `c27efdb5` antes do deploy.

Especificação completa do módulo: `docs/PROSPECCAO.md` e `docs/PLANO-FUNIL-SDR-B2B.md` no repositório.

## 18/09/2026 — Limite 5 na busca + 1º contato automático com áudio via cron

**Objetivo do dono:** ver o funil rodando de verdade — "rebaixar o limite de buscar para 5 automática, prospect e mande a primeira mensagem automática no whatsapp da larissa via áudio, pode colocar cron e nomeclatura nas listas que você baixou me informe cada etapa do processo".

**O que foi feito**

### Busca agora começa em 5
- `QuickResultCount` ganhou `'5'` (era só 10/20/30/40); a tela (`page.tsx` useState) e a rota `/api/admin/prospect-radar/google` usam **5 como default**.
- Toda a lógica de busca + triagem foi extraída da rota para `lib/prospect-quick/search-google.ts` (`searchAndScreenResults`): fetch Google Places, dedup, score preliminar, screening (leads existentes, histórico 60 d, blacklist workspace + global, `screenPlaces`). Rota `/google` e o novo cron são **uma única fonte de verdade** — manutenção em um lugar só. Erros mapeados como antes: `GooglePlacesMisconfiguredError` → 503, `GooglePlacesApiError` → 502.

### Mídia no 1º contato
- `components/prospect-quick/types.ts` + `types/prospect-quick.ts`: `message_media_url` / `message_media_type` aceitos no launch (antes hardcoded `null`).
- O dispatch (`lib/campaigns/dispatch.ts`) já enviava texto → mídia (+1,5 s); agora a operação tem mídia e o áudio PTT sai junto.

### Cron `POST /api/cron/prospect-auto-send`
- Auth: `x-cron-secret` / `x-cron-token` / Bearer (mesmo padrão de `knowledge-base/ingest`).
- Flow: busca 5 (website=missing, min_score=60) → `preselect` → `importGooglePlaces` → `createRadarList` → `createOperation` com mídia (áudio curto) → `startProspectOperation(manualOverrideNoOptin: true, overrideSource: 'quick_launch')` → dispara.
- Resposta JSON: `ok`, `operation_id`, `list_id`, `campaign_id`, `eligible`, `blocked`, `first_send_at`, `niche`, `cities`, `searched`.
- Eventos: `google_selection_confirmed` + `manual_no_optin_override` registrados em `prospect_radar_events` (actor = 0000...0001, source quick_launch).
- Params via query: `q` (obrigatório), `cities`, `resultCount` (default 5), `min_score` (default 60), `website` (default "missing"), `audio_url` (default = áudio curto), `instance_id` (default Larissa), `ai_agent_id` (default SDR Ambern).

### Nomeclatura
Operação, lista e campanha recebem nome automático: `Auto 5 — <nicho> <cidade> — DD/MM HH:mm 🎙️` (fuso BRT).

### Crontab
`0 12 * * 1-5` (seg–sex 12:00 UTC = 09:00 BRT) → curl no endpoint com `q=fisioterapia%20pelvica&cities=Belo%20Horizonte&resultCount=5&min_score=60&website=missing`. Log em `/var/log/prospect-auto-send.log`.

### Demonstração em produção (18/09 13:57 BRT)
- Busca 5 → 1 elegível: "Fisioterapia Pélvica em belo Horizonte. Dra.Ana Flavia Nunes" (+31 99208-9615), score 68, sem site.
- Operação `2dc4e0f8`, lista `ffac2b8f`, campanha `a7ce811e` — status `completed`/`running`, `message_media_type = audio`.
- Job texto: 13:57:11, `delivered`. Job áudio PTT: 13:57:15, `delivered` (conversa `bfc336d8`).
- Lead: `eligibility = blocked_no_optin` (sem opt-in registrado — correto; override registrado em eventos).

### Commit e deploy
`ed358c4` → push (8/8 worker chaves) → clone limpo → `/api/version` = `ed358c4`. Suíte 444 passed (2 failures pré-existentes não relacionados: checkout regex; inbox 200/202). Docs commitados localmente (`4d581479`), sem push (evita churn de worker keys).

### O que não mudou
- Disparo de hoje (09:00) já executado (job e537cccf succeeded 09:00:15-03, só texto) — não tocado.
- Dra. Gabrielle: screening auto-bloqueia (suppressed/alreadyContacted) — não recontatada.
- Chave global `app_meta.openrouter_api_key` continua morta (401); a chave válida é da workspace 0002.

### Pendência/atenção
`salutation_name` do lead ficou com o nome comercial inteiro ("Fisioterapia Pélvica em belo Horizonte. Dra.Ana Flavia Nunes") — `suggestSalutation` não fatiou. Sem impacto porque a mensagem usa só `{{atendente}}`, mas se `{{nome}}` for ativado em operações automáticas, revisar a heurística.

## 18/09 (tarde) — Humanização do 1º contato: sem "SAIR" + abertura "Olá!"

Revisão do dono após o disparo das 13:57: (1) "como vai dizer SAIR nela — não existe opção de sair, sair só em templates oficiais"; (2) "esse oiiiii está muito mal, parece debochada".

**O que era verdade e o que mudou:**
- Opt-out: fora de template oficial (Cloud API) **não existe** opt-out por palavra-chave no canal. O worker tem `OPT_OUT_KEYWORDS` (webhook.ts) que blacklista por **frase** ("sair da lista", "pare de mandar", "não quero mais receber", "stop", "descadastrar") — independe do que o texto avisa. Bare "sair"/"cancelar" **não** está na lista de propósito (falso-positivo em assinante: "não vou sair do plano"). Logo: remover o "SAIR" do copy não perde nenhuma proteção.
- Tom do áudio: a TTS (Fish via OpenRouter, voz 5661bf8c…) rendeu "Oi!" como **"Oiiiii"** (sarcástico; transcrito assim no WhatsApp do lead). 

**Novo padrão (commit `81ee379b` + `cdd1edd`, web `cdd1edd`):**
- Texto (tela + cron `DEFAULT_MESSAGE`): _Olá! Aqui é a {{atendente}}, da Ambern 👋 Encontrei vocês no Google e fiquei curiosa: dá pra vocês aparecerem bem mais por lá, sabia? A gente cria sites profissionais e atendimento automático no WhatsApp pra isso. Se quiser, te mostro rapidinho como ficaria — sem compromisso. Tá bom?_
- Áudio: _Olá! Aqui é a Larissa, da Ambern… sem compromisso nenhum._ → `campaign-ptt-1789751286390.mp3` (202 KB, ~12s, 200 OK). `automation_media` `1fcc7a2c` + `DEFAULT_AUDIO_URL` do cron atualizados.
- A mensagem já enviada (13:57) **não** foi reescrita; os próximos disparos (cron seg–sex 12:00 UTC) já usam a versão humanizada.

**Áudios da sessão (MinIO `media/audio/campaign-ptt-*.mp3`):** `…7445542` (longo, descartado), `…7673071` (curto aprovado com SAIR, usado às 13:57), `…1134070` (sem SAIR, "Oi!" — substituído pelo tom), `…1286390` (atual: Olá!, sem SAIR). Variante adicional: regenerar com `/tmp/gerar-audio-ptt.mjs` dentro do worker (env `AUDIO_SCRIPT` + `OPENROUTER_KEY` da workspace 0002) e atualizar `automation_media` + `DEFAULT_AUDIO_URL`.

## 18/09 (noite) — Rodada de validação (10+ nichos), exists:false = falha definitiva + nota interna com perfil do Google

Dono pediu para validar disparos em ~10 nichos e reportou que "em alguns chats abre conversa e não dispara nada". Investigação com dados (jobs reais, não hipótese).

### O que realmente aconteceu (fatos)
- **Os 2 números citados pelo dono DISPARARAM com sucesso:**
  - `(31) 8262-0328` Studio Priscila (Salão Sabará) → job `succeeded` 14:28:20 (texto) + 14:28:22 (áudio).
  - `(31) 9231-3940` Auto Elétrica Lucimar (Contagem) → job `succeeded` 14:27:27 + 14:27:28.
  - O que o dono viu: a conversa é **criada pelo dispatch ANTES** do envio (`lib/campaigns/dispatch.ts` — INSERT com `last_message_at NULL`; defeito já documentado no próprio código desde 17/09) e há **delay entre destinatários** (9000–12000ms) + fila com retries de outros jobs → a mensagem aparece 40s–2min depois. Nesses dois casos apareceu.
- **Erro real 1 — número inexistente no WhatsApp (`exists:false`):** Google devolve telefones fixos/inexistentes. Evolution responde `HTTP 400 {"exists":false}` (ex.: `553136711937@`, `553132015783@`). Jobs ficavam em **retry infinito** (attempts 5–6, backoff longo) e o "chat fantasma" criado pelo dispatch **nunca era limpo** → inbox poluído por horas. Hoje: 10 jobs com este erro; campanhas afetadas: `5ffeb70e`, `ebf8a278`, `4db031f1`, `ed8ab05e`, `2f65595b`.
- **Erro real 2 — "Não entregue: fora da janela de 24h… Message Template aprovado":** **não é o disparo**, é o **bloqueio de compliance do painel ao responder manualmente** um lead que ainda não escreveu (`app/api/inbox/send/route.ts:146`, erro **131047** da Meta Cloud API). A Larissa está conectada via **Cloud API (Meta)** (`whatsapp_instances.provider = cloud_api`). Sem janela de 24h aberta pelo cliente, responder manualmente é bloqueado (por design, correto).

### Correções aplicadas (commits `fc5e83a1` worker + `2699bd2b` web)
1. **Worker (`fc5e83a1`):** erro Evolution com `"exists":false` → **falha definitiva**: `markDead` (sem retry) + **DELETE da conversa órfã** que ainda não tem mensagem real (`is_internal IS DISTINCT FROM true`) — não polui mais o inbox.
2. **Cron (`2699bd2b`):** após o start, para cada lead elegível cria a conversa (mesmo formato do dispatch) e insere **nota interna** (`is_internal=true`, autor `0000…0001`, visível só para equipe/dono), com o perfil do Google: empresa, categoria, endereço, telefone, site, avaliação ★ (count), score preliminar, pesquisas (nicho + cidade) e link do Google Maps. Pedido do dono: "no disparo automático já crie uma nota interna do perfil do google meu negocio para eu entender".
3. Deploy: push `cdd1edd..2699bd2b` → worker 8/8 chaves → clone limpo → `/api/version` = `2699bd2b`. Suíte 444 passed (2 failures pré-existentes: checkout regex; inbox 200/202).

### Rodada de validação (16 chamadas cron, niched e cidades de MG)
- OK com envio (op → n° elegíveis): clinica odonto BH (`3100d3ce`→1), contabilidade Contagem (`0d888b3c`→2), despachante BH (`eb35c63c`→1), nutricionista Santa Luzia (`bb50164b`→2), estetica Betim (`b54f2e41`→1), pilates BH (`4b12d7f4`→1), salão de beleza Sabará (`53c43ddf`→3), lavanderia BH (`74026a65`→1), aulas particulares BH (`5d86e7cd`→1), auto elétrica Contagem (`d20ff77e`→4), vidraçaria Contagem (`6385452e`→3).
- `no_eligible` (todos com site, filtro `website=missing` derruba): barbearia BH, oficina mecânica BH, imobiliária Nova Lima, petshop BH, chaveiro BH.
- Operação pré-existente observada: `a6f9841b` "fisioterapeuta pelotas — 18/09" (2 elegíveis, 2 jobs ok).

### Para o dono (resumo direto)
- Os 2 números mostrados **foram enviados**; o "abre e não envia" tinha duas causas: (a) o chat nasce antes e a mensagem leva até ~2 min (delay entre destinatários) — nos 2 citados chegou; (b) números que **não têm WhatsApp** (fixos/inexistentes) ficavam presos em retry infinito criando chat fantasma — **corrigido** hoje.
- A mensagem de "fora da janela de 24h / template aprovado" não vem do disparo: é o **bloqueio ao tentar responder manualmente** um lead que ainda não respondeu (Meta Cloud API, erro 131047). Quando o lead responder, a janela abre e você responde normalmente.

## 19/09 (manhã) — Modo teste: cap UNKNOWN 50→120 + `q=random` (nichos variados)

Dono: "faça prospecção automatica dispara audio para 5 empresas mande por whatsapp da larissa mendes numero final 0074… em modo teste o cap pode ficar desarmado ou melhor suba ele para 120 o nicho e randomico quero testar diferentes nichos".

### Cap de qualidade UNKNOWN 50 → 120 (`lib/whatsapp/dispatch-guard.ts`)
- **Decisão explícita do dono (19/09/2026)** para rodada de testes de nichos variados. Documentada no código com data e motivo; reavaliar ao fim dos testes.
- Impacto real avaliado: as réguas ativas (Renovação Expira HOJE/AMANHÃ) usam Julia Abreu **cloud_api GREEN** — o cap UNKNOWN **não se aplica** a elas. O cap UNKNOWN afeta instâncias Evolution (Larissa) e toda instância sem rating Meta. Hoje só a Larissa dispara campanha em massa no master, então o efeito colateral é mínimo.
- Lembrete: override (`qualityOverride`) **não** destrava `cap_exceeded` — só `quality_blocked` (YELLOW/RED). Então antes do cap subir, um lote de 5 na Larissa estava bloqueado com 48/50 usados (janela deslizante 24h).

### `q=random` no cron (`POST /api/cron/prospect-auto-send`)
- `q=random` sorteia um nicho da lista `RANDOM_NICHES` (28 nichos default: academia Betim, manicure Contagem, eletricista Betim, ar-condicionado Santa Luzia, marido de aluguel Betim, etc.) e evita repetir o último sorteado (`app_meta['prospect_random_last_niche']`).
- O dono pode sobrescrever a lista com `app_meta['prospect_random_niches']` (JSON array de strings).
- Resposta ganhou `random_niche: true` e `random_niche_source: 'default'|'config'`.

### Deploy + validação em produção (commit `2249a924`)
- Push → worker 8/8 chaves repostas (procedimento A5.3) → build via **clone limpo** (A5.4, NUNCA working tree com WIP) → `docker service update --force` (tag latest não recria sem force) → `/api/version` build_time novo, git_sha "unknown" (cosmético do clone depth-1).
- Disparo 13:51 BRT: `q=random` → sorteou **"eletricista Betim"** → 5 buscadas, **3 elegíveis** → operação `5819d3eb` ("Auto 5 — eletricista Betim — 19/09 13:51 🎙️"), lista `c52ebbf1`, campanha `fa5991fa`, áudio variante **C** (Elogio), 1 `succeeded` + 2 `queued` (13:51–13:53 BRT), mensagens na **Larissa Mendes** (`e6e1c0f8`, final 0074). Payload: `isPtt: true`, texto vazio (voice_only).
- 2 das 5 empresas buscadas foram filtradas (tinham site ou score abaixo) — 3 áudios enviados no lugar de 5.
