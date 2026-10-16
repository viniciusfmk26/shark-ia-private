# Evolução diária, compras, público e saúde — 16/10/2026

## Diagnóstico confirmado somente por leitura

- Meta retornou séries diárias em três contas acompanhadas: Shark30 18 linhas, Shark5 24 e Shark Filmes 3 duas, na janela `last_30d` consultada. API da Central já solicitava `time_increment=1` e conversões na série; o gráfico não era simulado.
- Nenhuma ação de compra foi retornada nos totais consultados. O resumo principal e a tabela de campanhas também omitiam compras/receita, apesar de o normalizador já suportá-las. Ausência permanece `null`/“—”, nunca fabricação de vendas.
- `meta_purchase_settings` sem configuração e destino existente desativado/em teste; Shark5 sem Pixel cadastrado. Não habilitar envio nem inferir conversão de pagamento a partir desta solicitação de análise.
- Idade, gênero, região, dispositivo e plataforma disponíveis na Shark5. `platform_position` isolado falhou com código100; `publisher_platform,platform_position` retornou 10 linhas. `age,gender`16, `country`1, `impression_device`5; campanha específica retornou seis idades após validar ownership.
- Saúde antiga exibia principalmente cadastro/sincronização. Ausência de importações não significa indisponibilidade da API. Sincronização automática continua desativada.

## Alterações

- `overview-dashboard.tsx`: compras/receita no consolidado, comparação e seletor do gráfico diário. Sem nova consulta no hover/troca de métrica. Moedas separadas e cobertura parcial preservadas.
- `resource-table.tsx`: compras/receita visíveis em desktop/celular, além do modal. `live-performance.tsx`: tabela diária ampliada, aviso específico quando a série falha e correção da invalidação do recorte após atualização.
- Nova seção **Público e entrega**, com gráficos e tabelas, conta/período/campanha e 11 recortes. Inclui gasto, impressões, alcance, frequência, cliques, CTR, CPC, CPM, conversas, leads, CPL, compras, receita e ROAS quando disponíveis. Hora consulta só gasto/impressões/cliques.
- `insights` aceita catálogo leve de campanhas e filtro por campanha; somente conexão acompanhada do workspace ativo, owner/admin. Consulta `id,account_id` da campanha e recusa propriedade divergente antes do Insights. `connection=all` com campanha é recusado. Posicionamento antigo normalizado para o par suportado; gênero/plataforma traduzidos.
- Nova API `/api/ads-center/health` somente leitura: metadados reais da Meta, estado/restrição, BM, moeda/fuso, Pixel cadastrado, validade local de token, sites/últimas visitas/contatos e últimas importações. Máximo20 conexões, concorrência2, deadline45s. Sem tokens ou erros brutos no JSON.
- Saúde distingue leitura disponível, conta desativada e falha da API. Histórico identificado como **importação de campanhas**; não inventa histórico de consultas.

## Validação

- 29 testes de API/cálculo e 42 de UI/regressão: 71 aprovados. Cobertura de ownership, tenant/papéis, falhas sem zero, filtro campanha/período, compra no gráfico e filtro de saúde sem refetch.
- TypeScript web/worker exit0. SQL da saúde executado em transação READ ONLY no banco real; retornou sites/timestamps corretos nas três contas.
- Chromium em laboratório: desktop1440 e celular390, sem overflow da página; seleção de conta/campanha/região, gráfico de compras, sem erros de página. Capturas identificadas como dados simulados. Não exercitada sessão autenticada de produção.
- Consultas reais Meta no host sem scripts em contêineres, só GETs. Nenhum anúncio, campanha, pagamento, mensagem, evento Meta ou configuração de envio alterados.
- Evidências: `/root/backups/ads-analysis-20261016/`.

Referência primária consultada: SDK oficial da Meta, campos e recortes de Insights: https://github.com/facebook/facebook-nodejs-business-sdk/blob/main/src/objects/ads-insights.js. A documentação web de breakdowns retornou429; combinações acima também confirmadas na API real.

## Publicação

Pendente build em clone limpo e rollout web. Sem migration. Preservar worker, configuração de compras e sincronização; sem push que provoque redeploy do worker. Rollback: imagem anterior `zapflix-tech:meta-purchases-04c17785` (confirmar no serviço antes do deploy).

## Publicado — 16/10/2026 16:25 UTC

- Web `9f72e373`, imagem `zapflix-tech:ads-analysis-9f72e373`; build em clone limpo concluído e serviço convergido. Versão pública confirmou SHA. Sem push remoto de código ou redeploy do worker.
- Login200, APIs de saúde/insights sem sessão401; web/worker1/1; oito chaves do worker presentes. Logs recentes sem erro novo relacionado à Central.
- 71 testes e TypeScript web/worker aprovados; Chromium de laboratório aprovou desktop/celular, filtro de campanha e gráfico de compras. A UI autenticada real depende de sessão do usuário, não fabricada.
- Nenhum evento de compra, anúncio ou mensagem enviado; configuração de compras e sincronização Meta preservadas. Evidência: `docs/evidence/ads-analysis-release-20261016.json`. Imagem anterior para rollback: `zapflix-tech:meta-purchases-04c17785`.

A seção anterior registra o estado antes da publicação; esta é a versão atual.
