# Áudio gravado pelo cliente no Webchat — 29/10/2026

Falha verificada em produção: mensagens recebidas tinham `media_type=audio/webm;codecs=opus`, mas os objetos correspondentes no MinIO continham apenas 15 bytes e não eram áudio válido. A função antiga aceitava Data URL só no formato `data:<mime>;base64,...`; com `;codecs=opus`, caía no ramo de Base64 sem prefixo e decodificava o cabeçalho como se fosse mídia. O Inbox registrava a mensagem, porém o player não conseguia reproduzir o arquivo.

`lib/webchat/parse-media-data.ts` passa a reconhecer parâmetros MIME antes de `;base64`, extrai somente os dados após a vírgula e rejeita Base64 inválido. `/api/webchat/message` usa essa função antes do upload. O formato `audio/webm;codecs=opus` e imagem comum passaram em teste unitário; TypeScript web e diff também passaram. Arquivos antigos de 15 bytes não podem ser reconstruídos: solicitar nova gravação.

Nenhum áudio real foi enviado durante o teste desta correção. Após publicação, o navegador móvel simulado percorreu apagar, pausar, retomar, prévia e enviar com API interceptada. Um segundo teste usou o MediaRecorder real do Chromium com microfone de teste: prévia reproduziu e o arquivo WebM enviado tinha cabeçalho válido e cerca de 12 KB. Ainda falta a conferência em aparelho real e no Inbox com uma gravação nova do cliente.

## Fluxo de gravação do cliente

A interface segue a sequência descrita na Central de Ajuda do WhatsApp: gravar, pausar, ouvir prévia, retomar ou apagar, e enviar só ao tocar no botão de envio. A barra mostra tempo e indicação animada durante a gravação. A gravação usa `MediaRecorder.pause()`/`resume()` e transforma os blocos em um único arquivo ao concluir; o áudio continua local até o envio explícito. Gravações vazias mostram erro. Um bloqueio impede finalizar duas vezes por toques repetidos.

Referência: https://faq.whatsapp.com/1044960269529733/?cms_platform=web&locale=pt_BR
