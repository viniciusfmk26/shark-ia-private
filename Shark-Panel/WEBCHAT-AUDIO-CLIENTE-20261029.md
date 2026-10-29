# Áudio gravado pelo cliente no Webchat — 29/10/2026

Falha verificada em produção: mensagens recebidas tinham `media_type=audio/webm;codecs=opus`, mas os objetos correspondentes no MinIO continham apenas 15 bytes e não eram áudio válido. A função antiga aceitava Data URL só no formato `data:<mime>;base64,...`; com `;codecs=opus`, caía no ramo de Base64 sem prefixo e decodificava o cabeçalho como se fosse mídia. O Inbox registrava a mensagem, porém o player não conseguia reproduzir o arquivo.

`lib/webchat/parse-media-data.ts` passa a reconhecer parâmetros MIME antes de `;base64`, extrai somente os dados após a vírgula e rejeita Base64 inválido. `/api/webchat/message` usa essa função antes do upload. O formato `audio/webm;codecs=opus` e imagem comum passaram em teste unitário; TypeScript web e diff também passaram. Arquivos antigos de 15 bytes não podem ser reconstruídos: solicitar nova gravação.

Nenhum áudio real foi enviado durante o teste desta correção. Validação em aparelho real e Inbox após publicação ainda é necessária.
