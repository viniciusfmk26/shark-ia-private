# Deep Dive — Prospecção (Radar, Operação e Prospecção rápida)

> Última atualização: 17/09/2026 — entregue a tela **Prospecção rápida** (commit `51f0b9fd`, web em produção `51f0b9f`).

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
- Em texto livre só **`{{nome}}`** é aceito (ver seção seguinte); qualquer outra variável ou chave solta = `variables_not_supported`.
- Canal `cloud_api` exige **template aprovado**.
- Os trilhos **nunca vêm do cliente**: a rota usa sempre `PROSPECT_SAFE_DEFAULTS`, `allow_recontact:false` e `batch_auto_advance:false`.

## "Como chamar" por empresa — `{{nome}}` no 1º contato (17/09/2026)

Pedido do dono: personalizar o primeiro contato sem parecer robótico — "Oi, Franciele Valeron!" em vez de "Oi! Aqui é a Julia". Ele escolheu entre duas opções a de **pré-preenchido + revisão humana** (não campo em branco, não IA escrevendo o texto).

- **Coluna "Como chamar" na lista** (`components/prospect-quick/results-table.tsx`): aparece **só quando a mensagem usa `{{nome}}`**, uma linha por empresa **marcada**. Botão **"+ nome"** na caixa de mensagem insere o token no cursor; a caixa mostra a **prévia da frase final** do primeiro contato já preenchido.
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
lib/campaigns/lead-vars.ts                      → engine do {{nome}} (puro)
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
- **Chave solta escapa da validação de variável:** `{{` sozinho não casa com o regex de token (`{{nome}}`), então passaria por `unknownLeadVars` e chegaria **literal no WhatsApp do cliente**. Por isso existe `hasBrokenLeadVarSyntax`, checado na tela **e** na rota.
- **`{{nome}}` em campanha sem Operação:** o dispatch aborta com 400 `lead_vars_unavailable` (não há de onde tirar o nome). Antes desta entrega o token ia literal para o cliente.

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
- `lib/server/inbox.ts`: LATERAL devolve `scheduled_send_at` = `MIN(run_at)` do job `send_message` **queued com >5 min de folga** (sem o corte, um lote disparando agora piscaria o selo em todas as conversas). Usa `idx_jobs_queue`, **0,2 ms** medidos.
- Lista: prévia vira "🕐 Agendada para amanhã às 09:00"; thread vazia explica o agendamento em vez de "envie uma mensagem".
- ⚠️ `lastMessageTime` virou `string | null` **de propósito** — o `tsc` apontou os 4 consumidores que assumiam horário presente (SLA de 15 min, filtro "Sem resposta", dedup por telefone, `StateSlot`) e cada um ganhou tratamento explícito; `new Date(null)` = 1970 virava "01/01".
- ⚠️ `lastMessageFromMe` não colapsa mais `null → false`: a tarja "aguardando" testa `=== false`, e "ninguém falou" ≠ "o cliente está esperando".
- ⚠️ Paginação: se a página termina numa conversa sem horário (elas ordenam por último), `hasMore = false` — cursor nulo viraria `cursor=null` e derrubaria o cast no Postgres.
- **Dado real corrigido:** a única conversa nesse estado (a da Dra. Gabrielle) foi ajustada à mão (`UPDATE` de 1 linha, com guarda `NOT EXISTS (messages)`); o agendamento de 18/09 09:00 segue intacto.
- **Validação:** o SELECT inteiro do `getConversations` foi remontado com os mesmos fragmentos e rodado no Postgres de produção **antes** do deploy (exit 0); para a conversa dela, `scheduled_send_at = 2026-09-18 09:00:00-03`.

**Deploy:** commit `5fde5f1a` → push (worker redeployou, 8/8 chaves repostas) → build de clone limpo → `/api/version` = `5fde5f1a` (build_time 2026-09-17T22:27:15Z). Rotas conferidas de dentro do container (a app escuta na **porta 80**, `PORT=80`): `/api/version` 200, `/admin/prospect-quick` 307→login, `/admin/inbox` 307→login, `/api/inbox/conversations` 401, `/api/admin/prospect-quick/launch` 401, `/api/admin/prospect-radar/google` 401. Log do web/worker sem erro novo.

⚠️ **Sintoma irmão não corrigido:** `apps/worker/src/handlers/background.ts:1655` (fluxo de cobrança/pedido) cria conversa sem esses dois campos e herda `now()`/`false` — mesmo defeito em potencial, precisa de análise própria.

## Pendências / próximos

- Outras variáveis na tela rápida (`{{empresa}}`, `{{cidade}}`, `{{nicho}}`, `{{dor}}`) — o plano E3 previa todas; o dono aprovou entregar só `{{nome}}` primeiro (é o que muda o tom da 1ª frase). O motor em `lib/campaigns/lead-vars.ts` já está pronto para receber mais.
- Aviso (não bloqueio) de opt-out/origem no **wizard** (parte do E3 que ficou fora desta fatia; a tela rápida já tem o checkbox de ciência de opt-in no modal).
- Retorno agendado ("me chama depois") — WIP em `apps/worker/src/lib/return-time-parse.ts` + `migrations/20260921_agent_followup_scheduling.sql` (ainda **não** aplicada/commitada).
- `dispatch_run_at` ignorando fim de semana (continua; agora pelo menos a tela avisa o horário real).
- **Aviso pós-disparo ✅ resolvido em 17/09 (commit `414d07a3`)** — o modal mostra `first_send_at` lido do job.
- **Filtros de lead quente ✅ resolvido em 17/09 (commit `414d07a3`)** — Presença de site (default sem site) + score visível na lista.
- **Conversa agendada mostrando "aguardando" ✅ resolvido em 17/09 (commit `5fde5f1a`)** — conversa nasce sem atividade e o inbox mostra "Agendada para …".
- **Linha antiga corrigida à mão ✅** — a conversa da Dra. Gabrielle teve `last_message_at`/`last_message_from_me` zerados; `salutation_name` **ainda** está `'Gabrielle Carvalho Pélvica'` na operação em produção (código corrigido, dado não).

Especificação completa do módulo: `docs/PROSPECCAO.md` e `docs/PLANO-FUNIL-SDR-B2B.md` no repositório.
