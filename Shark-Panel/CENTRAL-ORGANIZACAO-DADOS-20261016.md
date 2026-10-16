# Central: organização e dados — 16/10/2026

## Diagnóstico
As consultas recentes estavam no período Hoje logo após a virada do dia em São Paulo. A Meta retornava listas vazias para as três contas acompanhadas. A consulta histórica de 16/09 a 15/10 retornou cerca de R$ 9,64 mil (R$ 9.640,67 na primeira leitura; R$ 9.641,12 na prévia seguinte, sujeitos a atualização de atribuição da Meta). Não se deve substituir Hoje pelo histórico silenciosamente.

Havia também um defeito real: a série diária solicitava apenas gasto, impressões e cliques, impedindo gráficos diários de leads/conversas. Agora utiliza os mesmos campos completos da consulta de totais.

## Entrega
- Navegação de 11 seções agrupada em Análise, Operação, Criação e Configuração; seletor com grupos no celular.
- Cabeçalhos, filtros contextuais, tabelas e cartões consistentes; filtros limpos com um botão.
- Conjuntos/Anúncios/Criativos de todas as contas, separados por conta, preservando connectionId das ações e limites de concorrência/cache.
- Resumo de status nos recursos; seleção de contas de campanhas recolhível; CRM inicia com colunas essenciais e mantém configuração de colunas.
- Cadastro de contas com busca e filtros de acompanhamento/atenção; Biblioteca destaca galeria e recolhe upload; criação apresenta progressão de etapas.
- Datas da consulta visíveis; período sem atividade tem mensagem e atalhos; falhas continuam indisponíveis, sem contaminar totais com zero.
- Sem migration, alteração de orçamento, ativação ou criação de anúncios. Sem novas consultas ao passar mouse ou trocar gráfico.

## Verificação
- TypeScript web e worker aprovados.
- 38 testes de interface e 10 testes de insights/rota/agregação aprovados.
- Prévia completa no Chromium: 11 seções navegáveis, sem erros JS; viewport móvel de 390px sem overflow global. Dashboard usa resposta Graph sanitizada real; demais recursos são fixtures de prévia.
- Não houve teste de sessão autenticada do usuário em produção. ESLint não executável sem configuração no repositório.
- Build/deploy devem usar clone limpo e confirmar /api/version; nenhuma escrita na Meta faz parte desta entrega.
