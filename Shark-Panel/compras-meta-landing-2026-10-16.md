# Compras Meta por landing — revisão de 16/10/2026

O proprietário decidiu excluir Shark5 do novo envio de compras: a campanha remanescente é WhatsApp. Os destinos em análise são Shark30 (`sharflix`, Pixel `1097829939319128`) e Shark Filmes 3 (`sharflix-bs`, Pixel `1812820866405151`). Cada Pixel aparece no inventário da Meta da respectiva conta.

Diagnóstico de produção: os dois sites têm visitas e contatos com referência, mas `lead_touchpoints.landing_url` está vazio nos touchpoints externos dos últimos 30 dias. O sender exige URL para compras originadas no site. Os settings de envio de compras continuam ausentes; nenhum evento de compra foi enviado nesta revisão. Pagamentos históricos não serão reproduzidos.

Correção local preparada em `/api/t/collect`: formar URL HTTPS do domínio cadastrado e do caminho da visita, mantendo a primeira URL no UPSERT; host fornecido pelo visitante é recusado. 33 testes direcionados e TypeScript web/worker aprovados. Ainda não publicada nem ativada.

Próximo passo: publicar a correção e validar uma nova coleta real em cada site; enviar evento sintético de teste para cada Pixel; conferir um pagamento futuro ligado a contato/landing; habilitar somente destinos testados, com cutoff atual. Separar na UI vendas do CRM e compras atribuídas pela Meta; recebimento CAPI não garante atribuição de anúncio.

## Ativação — 16/10/2026 14:08 Brasília

- Publicada imagem web `zapflix-tech:purchase-landing-6c82ccb5`; worker e suas oito chaves preservados. Testes CAPI sintéticos aceitos pelos Pixels da Shark30 e Shark Filmes 3.
- Coleta pública em cada landing gravou URL completa e Pixel correto; dois touchpoints temporários removidos. Nenhuma mensagem ou compra de teste criada.
- Destinos dessas duas contas ativados em live na mesma transação do corte de compras futuras. Shark5 continua sem destino. Cron `campaign-batches` confirmou HTTP 200; 33 testes e TypeScript web/worker aprovados.
- Na conferência inicial, nenhum pagamento novo havia ocorrido depois do corte. A primeira entrega real e a atribuição da Meta ainda precisam ser observadas; pagamentos anteriores não são reenviados.

## Envio pontual autorizado — 16/10/2026 14:35 Brasília

O proprietário pediu cruzar somente as vendas de hoje e enviar atrasadas onde fosse possível. Das oito vendas confirmadas: cinco tinham sinal de Shark5 (excluída por decisão do dono), uma vinha da landing `sharflix-bs` e duas não tinham referência de anúncio ou landing. Essas duas chegaram em 14/10 e 15/10, e compraram em 16/10; não foram atribuídas artificialmente.

A única compra elegível da BS (R$ 49,90, pagamento registrado às 11:37:23) tinha contato, clique, conexão, conta e Pixel comprovados. Um evento sintético de pagamento manual foi aceito em Test Events. Depois, um único registro foi enfileirado com horário original, chave estável e guardas de duplicação; o sender recebeu `events_received>0` da Meta e marcou `sent` na primeira tentativa, Pixel `1812820866405151`. Sem código de teste no evento real. A consulta imediata de Ads Insights ainda não mostrou compra atribuída. Nenhuma outra venda foi enviada. SQL operacional em `/root/backups/meta-purchase-backfill-20261016/one-bs-payment.sql` e evidência sanitizada em `docs/evidence/meta-purchase-backfill-20261016.json`.
