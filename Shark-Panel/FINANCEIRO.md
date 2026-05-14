# Módulo: Financeiro / Pagamentos

## Responsabilidade
Pagamentos via PIX (AmloPay), comissões, revendedores, gamificação financeira.

## Arquivos principais
```
app/api/payments/webhook/route.ts         → webhook AmloPay
app/api/payments/amplopay-webhook/        → webhook alternativo
app/api/payments/register/route.ts        → registro manual
app/api/iptv/payments/route.ts            → pagamento IPTV
app/api/gamification/payroll/route.ts     → folha de pagamento
app/api/gamification/withdraw/route.ts    → saque de comissão
app/api/resellers/withdraw/route.ts       → saque revendedor
lib/payments/amplopay.ts                  → integração AmloPay
lib/payments/send-payment-confirmation.ts → envia comprovante
lib/gamification.ts                       → lógica de pontos
```

## Duas trilhas de comissão
1. **Financeira (R$):** `agent_commissions` + `agent_performance_daily`
2. **Gamificação (pontos):** `internal_credits_transactions`

## Formatação de valores
Valores no banco vêm com casas decimais extras (ex: `49.900000`).
Sempre formatar com: `(valor / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })`
Ou usar `lib/utils/format.ts`.

## Provedores de pagamento
- AmloPay: principal gateway PIX
- LowTicket: gateway alternativo (`app/api/lowticket/`)
