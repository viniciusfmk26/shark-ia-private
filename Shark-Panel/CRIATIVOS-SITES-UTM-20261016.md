# Criativos, sites e UTMs no criador — 16/10/2026

Na aba **Criativos**, a galeria exibe miniaturas e permite selecionar de uma a cinco imagens. O anúncio rápido envia cada imagem para a conta Meta selecionada e cria um anúncio por imagem no mesmo conjunto. A operação continua deduplicada por `request_id`; `meta_quick_ads.remote_ids` registra o primeiro criativo/anúncio nas chaves legadas e os seguintes em `creative_N`/`ad_N`. Se a Meta responder de forma incerta, a tela não repete a solicitação automaticamente.

O seletor de destino inclui landing pages IPTV publicadas e sites de `app_profiles` do workspace. Domínio personalizado só vira URL de destino quando `custom_domain_verified=true`; nos demais casos usa `/app/[slug]` no painel. Sites externos não são cadastrados automaticamente. A tela aceita URL HTTPS manual.

Antes de enviar, a tela mostra a URL final para cada criativo. A função compartilhada `quickAdDestinationUrl` preserva parâmetros existentes e define `utm_source=meta`, `utm_medium=paid_social`, `utm_campaign=shark_<campaign_id>`, `utm_term=adset_<adset_id>`, `utm_content=<nome_do_anúncio>` e `utm_id=<campaign_id>`. O nome e a data enviados ao servidor são os mesmos mostrados na prévia. URLs finais acima de 2048 caracteres são recusadas antes da reserva de criação.

Texto principal, título e descrição podem ficar vazios; há também botão de copy neutra. O payload Meta omite esses campos vazios. A Meta pode recusar um anúncio sem copy; a aprovação não é garantida. Nenhum anúncio real foi criado nesta implementação.

Testes: `test/api/ads-center-quick-ad.test.ts`, `test/ads-center-destination-sites.test.ts`, testes de Pixel e criador; TypeScript web e worker.
