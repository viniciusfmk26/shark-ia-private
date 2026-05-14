# Módulo: IPTV

## Responsabilidade
Gerencia testes (trials) e pagamentos de IPTV, integração com servidores Sigma/XC.

## Arquivos principais
```
app/api/iptv/trials/route.ts          → criação de trials
app/api/iptv/trials/[id]/activate/    → ativação manual
app/api/iptv/payments/route.ts        → registro de pagamento + comissão
app/api/iptv/servers/route.ts         → servidores cadastrados
app/api/iptv/sigma-activate/          → ativação via API Sigma
lib/iptv/format-message-by-app.ts     → formata mensagem por app (Ibo, etc)
lib/sigma/provision.ts                → provisionamento Sigma
components/iptv/payment-modal.tsx
```

## Tabelas principais
- `iptv_trials` — inclui `sold_by_user_id` (quem criou o teste)
- `iptv_servers` — servidores cadastrados
- `agent_commissions` — comissões financeiras (R$)
- `agent_performance_daily` — performance diária
- `internal_credits_transactions` — pontos de gamificação

## Regra crítica de comissão
```
// CORRETO: usar sold_by_user_id da trial
const trial = await db.query.iptv_trials.findFirst(...)
const commissionUserId = trial.sold_by_user_id

// ERRADO: nunca fazer isso
const commissionUserId = session.user.id
```

## Fluxo de pagamento
1. Admin registra pagamento em `/api/iptv/payments`
2. Sistema busca `sold_by_user_id` da trial
3. Cria registro em `agent_commissions`
4. Cria registro em `internal_credits_transactions` (pontos)
5. Atualiza `agent_performance_daily`
