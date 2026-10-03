# Sessão 49 — 03/10/2026 — Checkout de compra direta na landing IPTV (Shark Panel)

Feature completada e publicada. A landing IPTV deixou de levar a compra só ao WhatsApp: cada plano agora tem CTA para um checkout em `/comprar/iptv`, reaproveitando o visual do checkout de produtos, e o pagamento por PIX provisiona o acesso no Sigma pelo fluxo de planos já existente.

Commits: `58d5e394` (feature) → `98ad78b4` (fix do 401 do middleware) → `797b9dd0` (docs). Produção em `zapflix-tech:iptv-checkout-20261003-v2`, SHA `98ad78b4`. Sem push remoto; worker não redeployou e manteve as oito chaves.

## A decisão que definiu a arquitetura

O primeiro impulso era reusar o checkout low-ticket (`/api/lowticket/create-pix` + `lowticket_orders`), que é o caminho público já consolidado. **Isso está errado para IPTV.**

O webhook do AmploPay (`app/api/payments/amplopay-webhook/route.ts`) desvia qualquer identifier com prefixo `lowticket-` para `handleLowticketWebhook`, que só marca o pedido como pago e dispara WhatsApp com `access_url` estático. Não existe chamada de provisionamento nesse caminho. O Sigma só é acionado no fluxo de planos, gateado por `planKeyFromIdentifier` (`lib/sigma/provision.ts`).

Ou seja: pedido em `lowticket_orders` = cliente paga e não recebe acesso. O novo endpoint grava em `checkout_orders`, que é onde o webhook já sabe provisionar.

Planos usados (workspace `4a815ba6`, servidor global `aaaaaaaa-…-0002`):

| checkout_plans.id | key | Preço |
|---|---|---|
| 63 | `mensal-s1-4a815ba6` | R$ 19,90 |
| 62 | `anual-s1-4a815ba6` | R$ 49,90 |
| 60 | `Vitalicio-s2-4a815ba6` | R$ 119,90 |

`baseKey()` mapeia as keys com sufixo de workspace para os IDs base 6/28/29 no Sigma — resolvido e conferido.

## O endpoint

`POST /api/iptv/landings/checkout` (`app/api/iptv/landings/checkout/route.ts`):

- lê `published_config` da página — rascunho não vende;
- exige `plan.checkoutPlanId` presente na config da página;
- busca o preço em `checkout_plans` **no servidor** (o cliente nunca envia valor);
- grava em `checkout_orders` com identifier `zapflix-<planKey>-wa<telefone>-<timestamp>`;
- vincula `touchpoint_id` ao `lead_touchpoints` da página, fechando a atribuição.

**O identifier não pode ganhar nada no fim.** O webhook limpa o sufixo com `/-\d{10,}$/`; acrescentar sufixo aleatório quebraria o `planKey` e o pedido nunca provisionaria. É a mesma restrição do `/api/checkout/create-pix`.

**Order bumps foram recusados de propósito** (`bump_not_supported`). O webhook só entrega tela extra quando o planKey é `tela-extra`; num plano normal ele descarta o segmento e o cliente pagaria por algo não entregue. Telas extras continuam fora do escopo.

`CheckoutForm` ganhou `paymentEndpoint`/`paymentExtra` opcionais. `/p/[slug]` não muda por omissão dos props — é o que mantém o checkout de produtos intacto.

Sem migration: só colunas existentes (`checkout_orders.touchpoint_id`, `checkout_plans.workspace_id`/`extra_screen_price`).

## O 401 que só apareceu em produção

A página `/comprar/iptv` abria normalmente, mas o POST do checkout respondia **401 Not authenticated**. O visitante da landing não tem sessão, então a compra simplesmente não acontecia — e nada acusou, porque o endpoint era novo: não havia build anterior para comparar.

Liberei o path no middleware. ** deliberadamente não `/api/iptv/`: os ~40 endpoints sob esse prefixo (`mastersigma/delete`, `mastersigma/sync`, `sigma-activate`, `chargebacks`, `servers`, `trials`…) não têm autenticação própria e dependem inteiramente do middleware. Um prefixo aberto entregava delete/sync de Sigma e chargebacks para anônimo. Fica `/api/iptv/landings/checkout`, path exato, com o motivo no comentário.

`test/middleware-public-routes.test.ts` trava esse contrato (checkout é público, o resto de `/api/iptv/` não) e foi validado por mutação: trocar para `/api/iptv/` faz o teste falhar. O guard funciona.

## Sorteio de empresa responsável

`getLandingSources()` sorteava empresa Authorized em **todo** carregamento do editor. Isso muda o default a cada render e podia trocar o CNPJ exibido sem o dono perceber. O sorteio virou acidental e ficou só no botão do dono, sempre entre empresas já usadas como responsável em páginas salvas, com a escolha persistida.

## O build pegou um arquivo faltando

O primeiro build em clone limpo quebrou: `lib/iptv-landings/checkout.ts` estava **untracked** e ficou fora do commit. `tsc` e vitest rodam no working tree e enxergam o arquivo, então 19 testes passavam e o TypeScript dava limpo — a falha só apareceu na imagem.

Corrigido, e antes de rebuildar foi feita varredura de todos os imports `@/` dos arquivos do commit contra a árvore commitada. É o check que faltava no processo de build; vale repetir sempre que o working tree estiver sujo.

## Verificação

93 testes verdes (landing, checkout, atribuição, upload, lowticket, amplopay, middleware). TypeScript web e worker ok. Na página publicada `shark2-f8cee1179b39` os três CTAs apontam para o checkout e os preços renderizados batem com o banco.

Em produção, só caminhos que não cobram: corpo vazio → 400 `invalid_input`; landing inexistente → 404 `checkout_not_found`; `landing_plan` fora da config → 404; `upload`/`mastersigma/delete`/`sigma-activate` → 401. Os `wa.me` que restam na landing são link de suporte, não CTA de compra.

**Nenhum PIX real foi gerado.** O primeiro pagamento completo tem de ser feito pelo dono.

Dois testes pré-existentes seguem fora, em arquivos não tocados por esta feature:
- `test/api/checkout.test.ts` espera `/obrigatórios/i` e recebe `planKey é obrigatório`;
- `test/trial-recovery-checkout.test.ts` exige `TRIALS_TEST_DATABASE_URL` (banco de laboratório).

## Pendência para o dono

1. Fazer uma compra real ponta a ponta e conferir se o acesso foi provisionado no Sigma (é o único teste que valida o webhook com pagamento de verdade).
2. **Rate limit no endpoint.** `POST /api/iptv/landings/checkout` é público e sem limite, como `/api/lowticket/`. Cada POST válido cria pedido e chama o gateway. Decisão do dono se quer limite por IP/telefone antes de anunciar a landing em volume.

## Não relacionado

- WIP do CRM (Fases 0–2) segue preservado fora dos commits, bloqueado pelos 101 vínculos cross-tenant. Não misturar com esta entrega.