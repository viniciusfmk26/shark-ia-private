# Criação simples de campanhas — 16/10/2026

O fluxo principal da aba **Campanha inteligente** recebe apenas uma conta acompanhada e o orçamento diário. A API monta uma prévia com a BM, a conta de destino, a campanha e um conjunto de origem, público, destino, criativo e valor. Após confirmação, cria a cópia pausada. O laboratório de testes e o modo avançado estão em abas separadas.

O modo simples usa todo o histórico disponível na Meta para escolher uma campanha com objetivo Leads ou conversas WhatsApp, gasto registrado e anúncio de imagem compatível. Copia somente o melhor conjunto disponível entre os recomendados e mantém texto e imagem originais; se a Meta não fornecer título, usa o nome do anúncio. A estratégia reduz chamadas de escrita e evita que o usuário precise escolher o que testar. A prévia é recalculada no servidor antes de criar e deve manter a mesma assinatura. O `request_id` impede duplicação da mesma solicitação.

Uma campanha sem modelo compatível ainda não pode ser criada por esse fluxo. A interface mostra o erro e permite escolher outra conta; o modo avançado expõe campanhas elegíveis e motivos. Nenhuma campanha real foi criada durante esta alteração.

Validação: `npx tsc --noEmit -p .`; `npx vitest run test/smart-campaign.test.ts test/smart-campaign-publish.test.ts`; `npx vitest run -c vitest.ads-center.config.ts test/ads-autopilot-ui.test.tsx test/ads-center-ui.test.tsx`.
