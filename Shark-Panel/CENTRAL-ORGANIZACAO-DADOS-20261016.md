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

## Publicação confirmada

Web publicado em 16/10/2026: imagem `zapflix-tech:central-27afcf32`, `/api/version` confirmou `27afcf32`. Login HTTP 200; insights sem sessão HTTP 401 JSON; web e worker 1/1. Guarda do deploy confirmou preservação das oito chaves do worker. Build Docker concluído com sucesso.

## 16/10/2026 — Público, compras e saúde (release em preparação)

Compras e receita da Meta agora aparecem no consolidado, série diária e tabelas de campanhas. A seção Público e entrega consulta idade, gênero, região, dispositivo, plataforma, posição e horário, inclusive por campanha com verificação de conta. Saúde mostra estado atual da Meta, BM, Pixel cadastrado e últimos dados da landing; histórico segue como importação de campanhas. Shark5 não possui Pixel de compras cadastrado; envio de compras permanece desativado. Ver [[ANALISE-PUBLICO-SAUDE-20261016]].

### Publicação confirmada — 16/10/2026 16:25 UTC

Web `9f72e373` no ar; 71 testes, TypeScript e revisão em Chromium aprovados. Login e autorização de APIs conferidos; web/worker1/1, oito chaves preservadas. Compras da Meta não apareceram na consulta real do período; envio de compras continua desligado. Evidência `docs/evidence/ads-analysis-release-20261016.json` no repositório local.
