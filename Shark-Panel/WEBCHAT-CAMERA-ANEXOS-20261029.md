# Câmera e anexos do cliente Webchat — 29/10/2026

O ícone da câmera deixou de depender do seletor de arquivos com `capture`, que pode abrir a galeria conforme o navegador. Com `getUserMedia({ video: { facingMode: { ideal: 'environment' } } })`, ele abre uma visualização dentro do chat, oferece botão Tirar foto e guarda o JPG como anexo local para o cliente enviar. Ao fechar ou capturar, as trilhas da câmera são encerradas. Quando a API não existe, usa o input nativo `accept=image/* capture=environment`; quando a permissão é negada, mostra erro em vez de abrir a galeria.

O clipe abre um menu com Galeria (foto/vídeo), Documento e Áudio, cada opção com seletor apropriado. A mídia escolhida continua aguardando o toque em Enviar. Limite de upload segue 20 MB.

Referências de comportamento de navegador: MDN `getUserMedia` e atributo HTML `capture`. Validação: TypeScript web, diff e teste de navegação móvel com câmera simulada após publicação.
