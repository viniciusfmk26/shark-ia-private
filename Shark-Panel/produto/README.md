# Produto — Documentação

## Arquivos
- [[auditoria-completa-2026-04-30]] — Auditoria completa (banco, fluxos, problemas, glossário)

## Resumo executivo
- 192 tabelas, 1,5 GB · 12.716 contatos · 170k mensagens · 317 subscriptions ativas
- 75 tabelas vazias (~40% do schema)
- 3 sistemas de pagamento paralelos (payments / iptv_payments / workspace_plan_payments)
- 1.307 pagamentos (88%) sem subscription criada
- 21 de 25 crons não agendados no supercronic
- Estado de "cliente ativo" desnormalizado em 4 lugares

## Próximas auditorias planejadas
- [ ] Auditoria de configurações (API keys, instâncias, planos, limites por workspace)
- [ ] Redesenho da arquitetura (consolidar pagamentos, unificar fonte de verdade do cliente)
- [ ] Agendar crons fantasmas no supercronic
- [ ] Backfill de subscriptions (1.307 pagamentos órfãos)
