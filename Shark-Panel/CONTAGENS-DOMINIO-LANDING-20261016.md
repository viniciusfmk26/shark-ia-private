# Contagens e domínio da landing na Central de Anúncios — 16/10/2026

As prévias mostram explicitamente campanhas, conjuntos e anúncios **novos** antes da confirmação. Criação manual: 1/1/1. Criação simples: 1/1/1. Criação por várias campanhas: uma nova campanha por modelo selecionado e um anúncio por conjunto planejado. Testes acompanhados: uma campanha e um anúncio por célula de teste. Criativos: zero campanhas/conjuntos novos e um anúncio por imagem selecionada, no conjunto existente.

Uma landing publicada pode estar vinculada a `workspace_domains` por `workspace_domain_landing_paths`. A Central agora prefere `https://dominio/caminho` no seletor de destino e no link de teste do Pixel quando a ativação da landing está completa e os checks de DNS/HTTPS estão positivos. O domínio cadastrado sem ativação ou sem HTTPS confirmado não é usado como destino; nesse caso, o painel mostra `/l/[slug]` até a ativação estar pronta. Sites de `app_profiles` continuam usando seu `custom_domain` verificado.

Não houve criação de campanha, anúncio nem Pixel real nesta alteração. Validação: testes de destino/instalação, interface e TypeScript do web.
