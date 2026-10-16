# Compras Meta por landing — revisão de 16/10/2026

O proprietário decidiu excluir Shark5 do novo envio de compras: a campanha remanescente é WhatsApp. Os destinos em análise são Shark30 (`sharflix`, Pixel `1097829939319128`) e Shark Filmes 3 (`sharflix-bs`, Pixel `1812820866405151`). Cada Pixel aparece no inventário da Meta da respectiva conta.

Diagnóstico de produção: os dois sites têm visitas e contatos com referência, mas `lead_touchpoints.landing_url` está vazio nos touchpoints externos dos últimos 30 dias. O sender exige URL para compras originadas no site. Os settings de envio de compras continuam ausentes; nenhum evento de compra foi enviado nesta revisão. Pagamentos históricos não serão reproduzidos.

Correção local preparada em `/api/t/collect`: formar URL HTTPS do domínio cadastrado e do caminho da visita, mantendo a primeira URL no UPSERT; host fornecido pelo visitante é recusado. 33 testes direcionados e TypeScript web/worker aprovados. Ainda não publicada nem ativada.

Próximo passo: publicar a correção e validar uma nova coleta real em cada site; enviar evento sintético de teste para cada Pixel; conferir um pagamento futuro ligado a contato/landing; habilitar somente destinos testados, com cutoff atual. Separar na UI vendas do CRM e compras atribuídas pela Meta; recebimento CAPI não garante atribuição de anúncio.
