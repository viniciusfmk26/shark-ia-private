# Landing Pages em domínios próprios — 16/10/2026

A tela **Domínios** mostra as Landing Pages IPTV publicadas no workspace. No cartão do domínio, escolha a página e o caminho (`/` para principal, `/oferta` para outra página). Em **Landing Pages IPTV**, ao selecionar uma página publicada, os domínios cadastrados aparecem e é possível vinculá-los ali também.

A mesma página aceita vários domínios; um domínio aceita até 20 páginas em caminhos diferentes. O caminho é único por domínio. A publicação da página é requisito. A exclusão ou despublicação tira o endereço público do ar, embora o vínculo possa continuar listado para remoção.

O vínculo por si só não publica no domínio: confirmar propriedade com TXT, apontar DNS para o servidor e clicar em **Ativar páginas / HTTPS**. O estado DNS/HTTPS aparece nas duas telas. O domínio pode continuar servindo e-mail e webhook; sites de aplicativos são selecionados em seção separada.

Implementação: migration `20261016_workspace_domain_landing_paths.sql`, `lib/domains/service.ts`, API `/api/domains/[id]/pages`, resolver `/api/internal/custom-domain-resolve`, middleware e telas. A migração é aditiva. Nenhum domínio foi vinculado ou ativado automaticamente.
