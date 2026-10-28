# Fluaflix: visual da landing Webchat e dados opcionais — 28/10/2026

A landing `contactMode='webchat'` usa o layout de banner, cards, planos, teste, compatibilidade e dúvidas criado para o protótipo Fluaflix. O conteúdo e as cores continuam editáveis no painel; a landing WhatsApp mantém o renderer anterior. O banner padrão reutiliza o mesmo arquivo da prévia da tarde (`capa-entretenimento.webp`). O contato principal abre `/l/<slug>/chat` e o botão secundário usa o número WhatsApp configurado.

Empresa cadastrada, razão social e CNPJ são opcionais para salvar a página. O editor agora informa isso claramente quando a lista de empresas estiver vazia. A API já aceitava esses campos vazios. Se outro campo falhar na validação, a tela mostra o nome e o erro do campo em vez de apenas “Confira os campos da landing”.

O workspace Fluaflix foi conferido em 28/10/2026: zero empresas, zero planos ativos do catálogo e zero instâncias WhatsApp conectadas. Para novos rascunhos Fluaflix sem catálogo, o editor oferece os três preços informados pelo dono (R$ 19,90, R$ 49,90 e R$ 119,90) e o WhatsApp +55 53 8129-8755 como valores iniciais editáveis. Isso não publica nem altera landing existente. O número não foi testado como destino WhatsApp ativo.

Verificações: TypeScript web, testes de schema/API e renderização dos dois modelos. A conversa real e a entrega de anexos não foram testadas com cliente; notificações com o navegador fechado seguem fora deste release.
