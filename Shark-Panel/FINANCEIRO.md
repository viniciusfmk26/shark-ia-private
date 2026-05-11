# Financeiro — Documentação

> Cobrança, checkout, pagamentos PIX/AmploPay, revendedores e comissões.

## Visão geral

Dois sistemas integrados:
1. **App principal** (`/app`) — pedidos, pagamentos, cobrança, recorrência.
2. **Checkout separado** (`/checkout` — Vite + tRPC + MySQL 8) — em `checkout.appcineflick.com.br`.

## Tabelas (Postgres principal)

| Tabela | Conteúdo |
|---|---|
| `payments` | Pagamentos individuais (status `confirmed`/`pending`/`refunded`, `amount_cents`, `sold_by_user_id`, `sale_type`) |
| `checkout_orders` | Pedidos vindos do sistema de checkout (PIX) |
| `checkout_utm` | Tracking UTM (utm_source/medium/campaign) |
| `subscriptions` | Assinaturas ativas |
| `resellers` | Cadastro de revendedores |
| `reseller_sales` | Vendas por revendedor |
| `reseller_withdrawals` | Saques |

## Pages

- `/financeiro` — visão geral (receita, recebíveis, pagamentos pendentes)
- `/pedidos` — listagem de pedidos
- `/recorrencia` — gestão de assinaturas recorrentes
- `/cobranca-rapida` — emissão rápida de cobrança PIX
- `/checkout-admin` — admin do checkout (gateways, produtos)
- `/coupons` — cupons
- `/billing` — faturamento

## APIs

| Rota | Descrição |
|---|---|
| `/api/payments/*` | CRUD de pagamentos |
| `/api/checkout/*` | Bridge com sistema de checkout |
| `/api/cobranca/*` | Geração de cobrança |
| `/api/affiliates/*` | Afiliados |
| `/api/resellers/*` | Revendedores |

## Gateways

- **AmploPay** — PIX principal (env: `AMPLOPAY_PUBLIC_KEY`, `AMPLOPAY_SECRET_KEY`)
- Webhook em `/api/webhooks/amplopay`

## Crons financeiros

- `abandoned-cart` — carrinho abandonado
- `pix-followup` — follow-up de PIX gerados não pagos
- `plan-expiry` — verificação de expiração de planos
- `renewal-check` — checa renovações
- `reseller-billing` — fatura revendedores

## Convenção de servidores (legado)

`checkout_plans.server` é integer 1/2 sem FK; map por slug:
- `1` = megabox
- `2` = tps

(Manter compatibilidade; quem adicionar nova integração deve usar mapping por slug.)
