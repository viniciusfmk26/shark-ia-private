# Módulo: Gamificação / Equipe

## Responsabilidade
Sistema de pontos, ranking, metas, comissões e performance da equipe.

## Arquivos principais
```
app/api/gamification/config/route.ts      → configuração de pontos
app/api/gamification/leaderboard/route.ts → ranking
app/api/gamification/my-stats/route.ts    → stats do usuário
app/api/gamification/payroll/route.ts     → folha de pagamento
app/api/gamification/withdraw/route.ts    → saque
app/api/credits/balance/route.ts          → saldo de créditos
app/api/credits/transactions/route.ts     → histórico
app/api/team/[userId]/route.ts            → performance individual
app/api/team/[userId]/financial/route.ts  → financeiro do membro
lib/gamification.ts                       → lógica central
```

## Tabelas principais
- `internal_credits_transactions` → pontos ganhos
- `agent_commissions` → comissões em R$
- `agent_performance_daily` → snapshot diário
- `gamification_config` → configuração de pontos por ação
- `gamification_withdrawals` → saques solicitados

## Página de desempenho
`/team/[userId]` → visão do gestor sobre um membro
`/meu-desempenho` → visão do próprio vendedor (PLANEJADO)
