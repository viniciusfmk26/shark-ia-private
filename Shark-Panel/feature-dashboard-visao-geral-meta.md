# Visão geral da Central — dashboard de desempenho

A Visão geral mostra primeiro o investimento consolidado por moeda, cartões de investimento, leads Meta, conversas e cliques; depois, evolução diária com seleção de métrica, gráfico de participação do investimento e tabela de comparação entre contas. CPL, CPC e CTR são calculados a partir dos totais completos, nunca pela média das taxas de cada conta. Detalhes individuais, métricas adicionais e comparação anterior ficam em painéis expansíveis. Filtros de status, busca e presets de anúncios ficam fora desta aba, pois não filtram a consulta de desempenho no nível da conta.

`OverviewDashboard` usa somente a resposta já carregada por `LivePerformance`. Trocar métrica ou moeda não consulta a Meta. `lib/ads-center/overview.ts` agrega valores reportados, identifica cobertura incompleta e preserva ausência como indisponível. Resposta vazia bem-sucedida representa ausência de atividade; falha de consulta não vira zero. Moedas não são misturadas; alcance não é somado. Séries diárias usam as datas no fuso de cada conta e identificam cobertura parcial. Métricas da Meta continuam separadas dos resultados CRM.

Validação: TypeScript web, 37 testes da interface da Central e três testes de agregação; preview local com dados fictícios em desktop e celular, sem transbordamento horizontal da página. Os gráficos foram verificados no navegador. Os dados de preview não entram no produto.

Sem migration, alteração de API ou escrita na Meta. Publicar web pelo clone limpo. Rollback: imagem `zapflix-tech:smart-0a0bea4f`.
