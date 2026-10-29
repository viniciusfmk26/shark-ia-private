# Links e anexos no chat público — 29/10/2026

Na rota `/l/[slug]/chat`, URLs `http(s)` e `www` em mensagens são exibidas como links clicáveis, abrindo em nova aba. O texto restante permanece texto. Protocolos não HTTP são recusados para links e anexos.

O Inbox salva tipos de mídia normalizados (`image`, `video`, `audio`, `document`), enquanto uploads do visitante podem ter MIME completo (`image/jpeg` etc.). O cliente agora reconhece ambos. Imagens têm prévia clicável, vídeos e áudios têm controles, documentos exibem o nome registrado na mensagem e podem ser abertos. O seletor de arquivos aceita também PDF, Office, texto e ZIP; o limite atual continua 20 MB. No desktop, a largura da conversa é limitada a 720 px para evitar ampliar o papel de parede.

Validação: `npx vitest run test/client-chat-content.test.ts`, `npx tsc --noEmit -p .`, `git diff --check`.

## Gravação de voz no celular

Durante a gravação, a barra mostra ponto vermelho animado, cronômetro e botão “Concluir”; o botão principal vira “Parar gravação”. Ao concluir, o áudio gravado é enviado pela API existente. O cronômetro reinicia a cada gravação.
