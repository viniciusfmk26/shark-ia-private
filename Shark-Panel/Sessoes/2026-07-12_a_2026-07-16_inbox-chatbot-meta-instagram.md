# Sessão 2026-07-12 a 2026-07-16 — Inbox UX, Chatbot Robustez, Meta Ads v25, Instagram

## Resumo executivo
Maratona de 5 dias focada em **robustez e UX do inbox**, **correções críticas de fluxo do chatbot**, **migração Meta API v25**, **dashboard Instagram orgânico** e **correções de infraestrutura**. **76 commits** (`7e9b7d2b..34e58197`), múltiplos deploys web + worker validados, 4 bugs críticos de produção corrigidos (auto-restore, fallback "Não entendi", webhook gate, Android→TV). Features: quality rating Meta, filtro "Bot ao vivo", "Devolver ao bot", bloqueio janela 24h na UI, apresentação automática ao assumir.

---

## 1. Inbox — Nova lista de conversas (redesign completo)

### 1.1 Features novas
- **Selo client_360** na lista: badge colorido por status (ativo/expirado/trial/nunca teve)
- **Estado da conversa**: pill "🔥 Quente" para `has_high_intent` recente (7d)
- **Categoria de demanda**: Híbrido C (menu declarado → IA → fallback identidade instância)
- **Filtros operacionais**: Suporte/Vendas/Teste Grátis/Atendimento humano/Bot ao vivo
- **Performance**: query 1.040ms → **69ms** (remoção de hotspots sem consumidor)

**Commits:** `7e9b7d2b`, `9da7c1ab`, `e18cfa6b`, `4a080499`, `8d0ecb5a`, `89344299`, `bd842715`, `7b96de1d`, `6085c9da`

### 1.2 Quality rating Meta Cloud API
- **Badge colorido** (GREEN/YELLOW/RED) em 3 telas: lista, chat-view, modal Sistema
- Componente compartilhado `QualityRatingBadge.tsx`
- API `/api/cloud-api/phone-numbers` expõe `quality_rating` + `messaging_limit_tier`

**Commits:** `278759d5`, `678c4757`

### 1.3 Filtro "Bot ao vivo" + "Atendimento humano"
- **Bot ao vivo**: badge visual na lista + toggle de filtro (filtra `chatbot_session.status='active'`)
- **Atendimento humano**: critério corrigido em `lib/inbox/awaiting-human.ts` (pending+open, não só open)
- **Bug corrigido**: whitelist do cliente comia campo `isAwaitingHuman` — 8 clientes esperando 26-74h estavam ocultos

**Commits:** `774c38b8`, `c49473c2`, `f3d98e72`

### 1.4 "Devolver ao bot"
- Reverte `claimed_at` e retoma sessão de chatbot (se flow ainda ativo) ou deixa fluxo normal seguir
- Aparece só quando há claim ativo + sessão de chatbot não expirada
- Receita de teste HTTP com dado sintético documentada

**Commit:** `8012eea3`

### 1.5 Bloqueio de janela 24h Meta na UI
- **Banner** vermelho quando fora da janela (relógio é o inbound do CLIENTE)
- **Bloqueio HTTP 409** real no `/api/inbox/send`
- **Tradução do erro 131047** ao vivo na UI
- `/inbox/send` não checava a janela antes — atendente só via ícone cinza e mensagem não saía

**Commit:** `31482c1f`

### 1.6 Apresentação automática ao "Assumir conversa"
- Mensagem automática ao clicar "Assumir conversa" — usa **persona da instância** (não nome real do atendente)
- 4 camadas de guarda: janela 24h, quality rating, não duplicar, pular se já há mensagem recente do agente
- `display_name` por instância (Julia Abreu→Julia, Denise, etc.) — **pendente de confirmação final do Vinicius**

**Commits:** `f3d98e72`, `c511b0be`

### 1.7 Ícone de bot por mensagem
- Cada mensagem na thread mostra ícone 🤖 se `sent_by_user_id IS NULL` (bot)
- Fix: `isBot` chegava na API mas era descartado no parser do cliente

**Commits:** `c511b0be`, `395ab4c9`

### 1.8 Streamdeck redesenhado
- **3 categorias** (Suporte/Vendas/Teste) classificam `demand_category` com `source='menu'`
- **3 ações**: Resolvido (fecha conversa), Transferir (flow), Investigar (só marca)
- `streamdeck-triggers.tsx` mantida como **fileira colorida separada** (não confundir)

**Commits:** `bd842715`, `7b96de1d`

### 1.9 Tags e funil monotônico
- Novo→Lead→**Pagante** (monotônico, sem retrocesso)
- **"Em Atendimento"** automática no `claimed_at`
- Cron `sync-funnel-tags` não marca pagantes ativos como Lead (bug corrigido)
- Cleanup one-time para remover 628 tags "Lead" incorretas de pagantes

**Commits:** `0c793928`, `623b99ce`, `8463ae99`, `77573a23`

---

## 2. Chatbot — 4 bugs críticos corrigidos

### 2.1 Fallback "Não entendi" (3 tentativas)
**Problema:** 2ª falha não reenviava botões, 3ª falha prometia atendimento humano e não entregava — cliente ficava preso no loop.

**Fix:**
- 1ª tentativa: mensagem "Não entendi, tente novamente"
- 2ª tentativa: **reexibe os botões/lista** + nudge
- 3ª tentativa: **TRANSFERE de verdade** para atendimento humano (marca `support_requested_at`)

**Receita de teste:** pool falso + ROLLBACK.

**Commit:** `245727c7`

**Impacto:** 24% das mensagens "Não entendi" eram pedido de compra genuíno — agora roteado pro atendente.

### 2.2 Matching de keyword por substring solta
**Problema:** "como assim" casava "sim", "Roku" continha "ok" → falsos positivos. Negação ("não consegui") ignorada → falsos positivos.

**Fix:**
- Matching por **início de palavra** (não substring)
- **Guarda de negação**: presença de "não/nem/nunca" antes da keyword inverte o match
- Função `matchesKeywordSmart()` com 2 armadilhas documentadas

**Commit:** `1b94cb5a`

### 2.3 Bug Android Celular→TV
**Problema:** Opção "celular" no flow gravava `device_type='android_tv'` (campo errado) — 81 clientes afetados.

**Fix:** Edição direta do JSON do flow no banco (2 campos corrigidos: `set_var` + `send_message`), **sem deploy** (é dado, não código).

**Commit:** Não houve commit (correção manual via SQL)

### 2.4 Aviso de inatividade antes do timeout
**Problema:** Timeout 15min fechava 65% de leads que tinham perguntado **preço** (alta intenção).

**Fix:**
- Timeout **15→45min**
- Aviso "Ainda por aí?" antes de fechar
- Cron `chatbot-timeout` **pula lead QUENTE** (`has_high_intent` por conteúdo)
- Flow ganhou keyword **"preço"** roteando pro `sales-redirect`

**Commit:** `772becfe`

**Atenção:** Matching de "preço" é **substring** (não smart) — pode gerar falsos positivos.

### 2.5 Keyword match de "Não sei" (mini-menu)
Ramo "Não sei" do menu de apps virou **menu de 7 apps** (SSIPTV/SmartOne/IBO/Bob/Dream/TV Box/Nenhum). Capture espera foto do MAC. TV Box gera teste.

**Memória:** `chatbot_naosei_minimenu.md`

### 2.6 Verify subscription gate
Ramo Suporte não afirma plano de cara. Botão **"Verificar minha assinatura"** roda `check_active_plan` e mostra dado real (`plan_type_label` + `plan_expires_fmt`). Novo condicional `active` no flow.

**Memória:** `chatbot_verify_subscription_gate.md`

### 2.7 Plan status granular
`check_active_plan` resolve `plan_status` (active/expired/**never_had_plan**/error). Ramo novo `sup-newlead-msg` no Suporte para quem nunca teve plano.

**Memória:** `chatbot_plan_status.md`

### 2.8 Evolution API — fallback interativo
Buttons/list não renderizam interativo na Evolution. Worker degrada pra **menu numerado** + captura por número (fallback).

**Commit:** `f9620c37`

### 2.9 WebP na Cloud API
Cloud API rejeita `.webp` como image (erro 131053). Worker converte **webp→png** antes do upload.

**Commit:** `933f3c37`

---

## 3. Meta Ads — Migração API v25

### 3.1 Migração de versão
- Marketing API **v20 → v25** (única API do Shark que usa Marketing)
- Só **4 das 23 strings de versão** eram Marketing (resto é Graph API genérica)
- `MetaApiError` com retry automático

**Commit:** `556adc2f`

### 3.2 Token de system user
- Suporte a `token_source` (system user vs OAuth)
- Fix de refresh da UI de vinculação
- `SYSTEM_USER_ACCESS_TOKEN` em plaintext (ainda não migrado pra `encrypted_fields`)

**Commit:** `58bb341f`

### 3.3 OAuth scope `+business_management`
- App "Shark Panel" (ID 27181137711555090)
- Escopo `+business_management` deployado
- Erro de reconexão = bloqueio no painel Meta (token válido) — **ação manual do Vinicius no dev.facebook pendente**

**Commit:** `72c35a19`

**Memória:** `infra_meta_ads_oauth.md`

---

## 4. Instagram — Dashboard orgânico

### 4.1 Dashboard Analytics da Conta (orgânico)
- `/instagram/analytics` **novo** (lê banco externo `igshark` via pool separado `lib/db-igshark.ts`)
- Cards: Seguidores, Alcance, Engajamento, Posts (último período)
- `/instagram/analytics` **antigo** renomeado para `/instagram/analytics-dm` (analytics de DM, 0 linhas — nunca usado)

**Commits:** `eb167096`, `79d155bf`

### 4.2 Dashboard de automação Coment.→DM
- `/instagram/automacao` gerencia automação IG comentário→DM (n8n) via banco **externo igshark**
- Pool separado `lib/db-igshark.ts`
- **Validado E2E** 2026-07-14
- Env injetada via `--env-add` (não UI do EasyPanel)
- Seed tem 2 "Exemplo" duplicados (bug menor)

**Commits:** `3fd47dcf`, `eff5b144`, `dd93d4b0`

**Memória:** `project_igshark_dashboard.md`

### 4.3 Webhook n8n verificação Meta
- Workflow IG Coment→DM (n8n projeto jomik8) ativado
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`
- `META_VERIFY_TOKEN=sharkpanel_ig_verify_2026`
- Curl retorna 200+challenge

**Memória:** `igshark_n8n_webhook.md`

### 4.4 Auditoria Instagram (não implementado)
- Silo `ig_*` existe e nunca rodou
- Bloqueador: phone-como-identidade (não channel)
- Webhook público sem HMAC + fallback cross-tenant
- BullMQ morto (CLAUDE.md errado)

**Memória:** `project_instagram_audit.md`

---

## 5. CTWA — Unificação com Vendas

### 5.1 Gate CTWA no webhook + welcome unificado
- Leads de anúncio CTWA entram via gate `ad_id` (não `instance_ids`)
- Welcome áudio+banner unificado no flow **"Boas Vindas"** (não mais manual)
- **Validado E2E** (24 asserts)
- Código **PRONTO mas NÃO deployado** (aguardando decisão)

**Commits:** `2d2ca0f8`, `c6459354`

**Memória:** `ctwa_vendas_unificacao_implementada.md`

### 5.2 Problema: welcome manual
- Leads de anúncio caem na **Julia Abreu** (não Suporte Oficial)
- Welcome áudio+banner é **MANUAL** (agentes)
- Funil de Vendas **NÃO os alcança**
- Trigger auto quebrado

**Memória:** `ctwa_welcome_manual.md`

---

## 6. Vendas — Funil de qualificação

### 6.1 Scoring e bifurcação
- Ramo Vendas do flow ativo **TEM qualify completo**
- Scoring/bifurcação/CRM propostos
- Infra A/B `ab_split` **NO AR dormante** (não conectada)

**Commits:** `b6e01949`, `34dd2d66`

**Memória:** `vendas_funil_qualificacao.md`

### 6.2 Drip race + Winback
- Fix corrida cron×worker no `funnel-processor` (66 msgs dup/30d) — claim atômico
- **Winback v1 NO AR** (OFF default, toggle `/atendimento`)
- Funil real = 3 etapas

**Commits:** `6fed991a`, `79f55bef`

**Memória:** `drip_race_e_winback.md`

---

## 7. Auto-restore — 4 bugs críticos corrigidos

### 7.1 Bug #1: Gate de auto-restore derrubava transação do webhook
**Problema:** 3 bugs encadeados no gate `auto_restore` abortavam a transação e **perdiam mensagem inbound**:
1. Coluna `deleted_at` inexistente (era `deleted`)
2. Status inválido (`status='deleted'` não existe em `subscriptions`)
3. Campo errado (`user_id` vs `customer_id`)

**Fix:** SAVEPOINT obrigatório pra novo bloco no webhook — erro no gate não mata a transação principal.

**Commit:** `9c331777`

**Memória:** `webhook_restore_gate_deleted_at.md`

### 7.2 Bug #2: Feature de restore nunca funcionou (8 bugs)
**Problema:** Worker tinha **cópia manual** de `restore-client.ts` com 8 bugs + `CRON_TOKEN` ausente.

**Fix:** Reescrita pra chamar implementação canônica `/api/internal/mastersigma/restore`. `ENCRYPTION_KEY` só no web. `CRON_TOKEN` injetado no worker.

**Commit:** `ba803993`

**Memória:** `project_restore_worker_duplication.md`

### 7.3 UX do restore
- Removida msg redundante "aguarde"
- Bot **não atropela atendente humano ativo** (guarda `claimed_at`)

**Commit:** `3733cd39`

### 7.4 Gate MED no auto-restore
- **Não restaura** quem foi excluído de propósito por reclamar fora da janela de contestação
- Evita loop de restauração automática de quem não quer o serviço

**Commit:** `1221a112`

---

## 8. MasterSigma — Painel de limpeza

### 8.1 Filtros avançados + exclusão em lote
- Filtro por **revenda** (dropdown + 21 revendas visíveis)
- Filtro **MED granular** (dropdown + campo livre de dias)
- Filtro **Dias ativo** (idade da conta)
- **Exclusão em lote** de trials
- **Paginação real** na tabela

**Commits:** `26a9164a`, `0e229eec`, `c59cba3a`, `6aa43820`, `cb2ed922`, `14a5b336`, `7d85c7f1`

### 8.2 Tag "Cliente Excluído"
- Tag automática no CRM via vínculo `username→contact_id`
- Coluna "Tag" mostra "Cliente Excluído" na tabela

**Commits:** `73721d6a`, `7fe91491`

### 8.3 Botão "Recriar usuário"
- Restauração via **Integration API** (preserva credenciais originais)
- Modal de excluídos melhorado

**Commits:** `74915f2f`, `0d877f25`

### 8.4 Total de clientes ativos no modal Sistema
- Badge no topbar mostra total de clientes ativos no Sigma

**Commit:** `b98aff7b`

### 8.5 Bugs corrigidos
- **Stale closure** em `loadData` ignorava filtros
- **JOIN sem `workspace_id`** na CTE base

**Commits:** `d8e998a2`, `ee267143`

---

## 9. Correções de infraestrutura

### 9.1 tsconfig monorepo scope
**Problema:** `exclude` NÃO segura import — `scripts/` importava `apps/worker` e quebrava o build do web.

**Fix:** `include` restrito ao escopo do Next (d862560). Receita pra reproduzir o Docker sem buildar.

**Commits:** `5b19a0ff`, `d862560a`

**Memória:** `project_tsconfig_monorepo_scope.md`

### 9.2 Deploy web via script
- `scripts/deploy-web.sh` é o **ÚNICO** caminho de deploy
- Auto-build do Easypanel **DESATIVADO** para `wp_zapflix-web`
- Script builda do **WORKING TREE** (conferir `git status` antes, ou buildar de clone limpo)

**Memória:** `infra_zapflix_web_deploy.md`

### 9.3 Cron deploy
- `wp_zapflix-cron` (supercronic) **NÃO auto-builda** no push
- Rebuild manual via `Dockerfile.cron` + `docker service update`

**Memória:** `infra_cron_deploy.md`

### 9.4 Worker deploy
- `wp_zapflix-worker` deploya via **git push→Easypanel** (~60s, path-scoped)
- Confirmar via `grep` no `dist/` do container

**Memória:** `infra_worker_deploy.md`

### 9.5 Screenshot autenticado
- Receita: `AUTH_SECRET` + cookie `__Secure-`
- Receita antiga do repo cai no `/login` em **SILÊNCIO**
- `mount --bind` pra `node_modules`

**Memória:** `infra_screenshot_autenticado.md`

### 9.6 Worktree + node_modules (PERIGO)
- `mount --bind` + worktree remove **APAGA** o `node_modules` real
- Usar `cp -al`
- Layout é npm, **NÃO pnpm**

**Memória:** `infra_worktree_node_modules_perigo.md`

---

## 10. Fase 1a — Null safety (telefone)

### 10.1 Blocos 1-4 (telefone IS NOT NULL)
- **Bloco 1:** Guarda `phone IS NOT NULL` na origem dos fluxos de telefone
- **Bloco 2:** `ensureBrazilPrefix` devolve `''` sem dígitos (não `null`)
- **Bloco 3:** Nunca gravar telefone vazio
- **Bloco 4:** Guarda nas folhas de UI não cobertas pela origem

**Commits:** `274cd924`, `879fb4ed`, `34a26dff`, `34e58197`

---

## 11. Crons — Automação proativa pausada

### 11.1 Gate claimed_at nos crons
- Follow-ups proativos **NÃO disparam** se `claimed_at` ativo (atendente humano assumiu)
- `claimed_at` é **permanente** (sem expiração)
- Comentário do código que dizia "bot volta sozinho" estava **errado**

**Commit:** `50a3fbf6`

**Memória:** `project_takeover_gate.md`

---

## 12. Performance — Chatbot editor

### 12.1 Memoização de ramos + nodes + edges
- `detectBranches` ~O(nodes×edges)/render sem memo/virtualização — editor travava em flows grandes
- Memoiza ramos + `React.memo` nos nodes + drag via `rAF`
- Memoiza também as arestas (`EdgePath React.memo`)
- Memoiza o painel `NodeEditor` (não re-renderiza no drag)

**Commits:** `498de182`, `9f910ac4`, `5d0c3f9e`

**Memória:** `flow_editor_perf.md`

---

## 13. Tags — Auditoria de precisão

### 13.1 Auditoria 2026-07-13
- Só **"Lead"** (auto) tem bug real: staleness 7,9%, 628 pares contraditórios via cron sync-pagante
- Resto do dropdown é manual/0-uso
- **PAGAMENTO** é filtro, não tag
- Nada corrigido (além do sync-pagante já feito)

**Memória:** `project_tag_precision_audit.md`

---

## 14. Correções de entendimento importantes

### 14.1 "Lead quente parado" era artefato
**Problema:** 246 conversas "lead quente parado" pareciam receita perdida.

**Realidade:** Artefato do texto do anúncio CTWA marcando `has_high_intent` sozinho — **não é receita perdida**.

**Memória:** `session.status='active' ≠ bot ao vivo` (`chatbot_session_active_nao_e_ao_vivo.md`)

### 14.2 claimed_at: primeiro uso real
- **Primeiro uso real** da história foi **15/07**
- É **permanente** (sem expiração)
- Comentário do código que dizia "bot volta sozinho" estava **errado**

**Memória:** `project_takeover_gate.md`

### 14.3 Janela 24h — relógio é do cliente
- Relógio é o inbound do **CLIENTE** (não do envio)
- `/inbox/send` **NÃO checava** (atendente só vê ícone cinza)
- Fallback vaza pela Denise

**Memória:** `meta_janela_24h_131047.md`

### 14.4 Bot vs Human attribution
- Bot user `…00b0` tem **0 mensagens** (é só p/ `sold_by_user_id`)
- Sinal real = `sent_by_user_id IS NULL`
- IA lia bot como [Atendente] e classificava Suporte errado

**Memória:** `project_bot_vs_human_attribution.md`

---

## 15. Padrão de bug recorrente identificado

### 15.1 Whitelist de campos no frontend
**4ª vez** que uma whitelist de campos no frontend engole campo novo silenciosamente:
1. `claimedAt`
2. `isAwaitingHuman`
3. Badge "🤖 Fluxo" que nunca tinha funcionado (destravou de graça)
4. (mais um caso não documentado)

**Ação sugerida:** Investigar esse padrão de arquitetura numa sessão dedicada.

---

## 16. Pendências (decisões do Vinicius)

1. **display_name por instância WhatsApp** (Julia Abreu→Julia, Denise, Juliana Lima→Juliana, Suporte Oficial→?, Projeto Salmos→?, Gabriele Garcia→Gabriele) — tabela de distribuição de atendentes por instância já levantada, aguardando confirmação dos nomes finais

2. **Meta Ads OAuth**: ação manual no dev.facebook pendente (bloqueio no painel Meta)

3. **CTWA welcome unificado**: código pronto mas não deployado (aguardando decisão)

4. **Investigar padrão de whitelist** de campos no frontend (4 casos já documentados)

---

## Commits do período
**Total:** 76 commits (`7e9b7d2b..34e58197`)

**Range de datas:** 12/07/2026 a 16/07/2026

**Principais commits:**
- `9c331777` — fix(restore): gate de auto-restore não pode derrubar a transação do webhook
- `ba803993` — fix(restore): elimina a cópia do restore no worker; 8 bugs que nunca deixaram a feature rodar
- `245727c7` — fix(chatbot): fallback "Não entendi" com 3 tentativas (transfere de verdade na 3ª)
- `1b94cb5a` — fix(chatbot): matching de keyword por início de palavra + guarda de negação
- `772becfe` — fix(chatbot): não fechar leads QUENTES por inatividade + timeout 15→45min
- `278759d5` — feat(cloud-api): quality rating e messaging limit tier da Meta
- `8012eea3` — feat(inbox): botão "Devolver ao bot"
- `31482c1f` — feat(inbox): bloqueio de janela 24h Meta na UI
- `f3d98e72` — feat(inbox): apresentação automática ao assumir conversa
- `3fd47dcf` — feat(instagram): dashboard de automação Coment.→DM (banco externo igshark)
- `556adc2f` — feat(meta): migra Marketing API v20 -> v25 + MetaApiError com retry
- `d862560a` — fix(build): tsconfig do web com include restrito ao escopo real do Next.js

---

## Deploy validado
- **Web:** múltiplos deploys via `scripts/deploy-web.sh`
- **Worker:** auto-deploy Easypanel path-scoped validado
- **Cron:** rebuild manual (não auto-builda)

---

## Observações finais

### Lições aprendidas
1. **SAVEPOINT obrigatório** para novo bloco no webhook — erro no gate não pode matar a transação principal
2. **claimed_at é permanente** (sem expiração) — comentário do código estava errado
3. **Whitelist de campos no frontend** é padrão de bug recorrente — investigar arquitetura
4. **Matching de keyword** por substring solta causa falsos positivos — sempre usar início de palavra + guarda de negação

### Próximos passos sugeridos
1. Ligar **CTWA welcome unificado** (código pronto)
2. Confirmar **display_name** por instância WhatsApp
3. Investigar **padrão de whitelist** de campos (sessão dedicada)
4. Completar **ação manual Meta Ads OAuth** no dev.facebook
