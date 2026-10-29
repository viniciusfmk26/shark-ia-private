# Chat do cliente com visual Fluaflix — 29/10/2026

A rota pública `/l/[slug]/chat` agora usa o visual escuro do protótipo `docs/prototypes/fluaflix-chat.html`: cabeçalho centralizado, logo, papel de parede, mensagens com datas, barra de digitação com emoji, anexo, câmera e áudio, e informações da conversa. A altura acompanha `visualViewport` para manter a digitação visível com o teclado móvel aberto. O logo configurado em Webchat é usado quando a landing não tem logo próprio; a cor principal configurada colore as ações.

As conversas, mensagens e mídias continuam usando as APIs reais do Webchat e o Inbox. O painel de informações mostra apenas os participantes reais desta conversa; não exibe a contagem simulada do protótipo. O selo azul significa canal identificado neste site, não verificação pelo WhatsApp. Mídias continuam sujeitas ao limite atual de 20 MB por arquivo. A opção WhatsApp permanece no menu e na entrada da conversa.

Validação: `npx tsc --noEmit -p .` e `git diff --check`.
