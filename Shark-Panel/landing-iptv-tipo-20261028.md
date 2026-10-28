# Tipo de landing IPTV — 28/10/2026

Em **Landing Pages IPTV → Nova landing/Personalizar landing → Tipo de landing**, o operador escolhe:

- **Landing normal — WhatsApp**: comportamento atual, publicável.
- **Landing Webchat — chat principal, WhatsApp secundário**: tipo salvo em rascunho para preparar a página. A publicação ainda fica bloqueada na interface e nas APIs POST/PATCH até o Webchat de clientes estar conectado ao Inbox real. A prévia ainda mostra o renderer WhatsApp.

O campo `contactMode` fica no JSON da configuração, com padrão `whatsapp` para páginas antigas. Não há migração de banco. A versão já publicada continua a usar `published_config` quando o operador muda o rascunho para Webchat. O seletor sozinho não cria atendimento real, notificações ou página Webchat pública.

Verificação: `test/iptv-landings.test.ts` cobre compatibilidade de configuração, salvamento do rascunho e bloqueio de publicação pelas duas rotas. Compilar web e worker antes de publicar a interface.
