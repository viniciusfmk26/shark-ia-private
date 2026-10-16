# Carrossel de imagens e URL com UTMs — 16/10/2026

Na etapa **Anúncio e criativo** do criador manual, a biblioteca mostra miniaturas em páginas de quatro imagens. O operador escolhe uma imagem; o painel a envia à conta Meta selecionada e só a marca como escolhida se o upload retornar um hash confirmado. Também é possível enviar um JPG/PNG novo. Este fluxo cria uma campanha, um conjunto e um anúncio; a aba Criativos tem o fluxo para criar vários anúncios com várias imagens no mesmo conjunto existente.

O campo **URL de destino base (HTTPS)** contém a página sem o rastreamento gerado. A prévia abaixo exibe a URL final enviada ao anúncio, com UTMs geradas pelo mesmo `trackedDestinationUrl` do servidor. `utm_source`, `utm_medium`, `utm_campaign`, `utm_term` e `utm_content` aparecem antes da criação; `utm_id` e `meta_adset_id` recebem os IDs reais após a campanha e o conjunto serem criados. O painel mantém os demais parâmetros da URL, como `ref`.

Nenhuma campanha ou anúncio real foi criado nesta implementação. Validação: TypeScript web, teste de interface da etapa e build de produção.
