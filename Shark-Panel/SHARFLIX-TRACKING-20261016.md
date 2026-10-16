# Integração Sharflix → CRM — 16/10/2026

## Estado observado

- Landing pública: https://landing-page-sharflix.vercel.app/.
- Usuário informou commit externo `be0a1bf` em `app/layout.tsx`. HTML público e Chromium confirmaram uma única inclusão de `/t/track.js`, `data-site="sharflix"`, `afterInteractive`.
- Links preservam mensagens e dois destinos WhatsApp. Não alterar números por inferência.
- Não existe binding `sharflix` no banco consultado. Nenhum binding foi criado nesta etapa.
- Pixel público `1097829939319128` corresponde à conexão Shark30 (`act_2187852758751947`) no workspace Shark2. Usuário mencionou Shark5 (`act_1023201147399624`), cuja conexão está sem pixel. Pixel compartilhado não prova qual conta anuncia: decisão solicitada ao dono antes de qualquer escrita de atribuição.
- Modelo atual: um `site_key` → um workspace/conexão. Várias contas anunciando a mesma página exigem resolução adicional; não associar todos os visitantes automaticamente à conta do Pixel.

## Defeitos reproduzidos e correção local

`app/t/track.js/route.ts`:

- Marcador era testado no href percent-encoded; três passadas resultavam em três referências. Agora normaliza marcadores no texto decodificado e mantém exatamente um.
- Cookie guarda código puro, mas validação anterior exigia prefixo `ref:` e repetia a coleta no reload. Validação de código separada da extração de marcador.
- MutationObserver reaplica código em memória após React restaurar/recriar links, sem chamadas adicionais à API. Alteração de href é idempotente para evitar loop.
- Apenas hosts reais de WhatsApp com HTTP(S) e texto recebem referência. Código retornado precisa ter oito caracteres válidos.

## Validação

- Suíte direcionada: 89 testes passando, incluindo 10 novos testes do script, API de coleta, parser e atribuição do worker. Teste do script reexecutado após ajuste de limpeza do DOM: 10/10 sem erros.
- TypeScript web e worker: exit 0.
- Chromium na página pública, rede interceptada: script instalado uma vez; versão publicada gerava 3 marcadores nos sete links, reproduzido também no reload. `code:null` e falha mantêm destinos/textos.
- Candidato local aprovado no Chromium sobre a página real com coleta simulada: sete links com exatamente um marcador antes/depois do reload e uma única coleta; cenários null/offline preservaram os sete links. Não enviar mensagens, eventos de conversão, visitas para analytics, nem criar touchpoints de teste em produção.

## Pendências

- Confirmar com o dono qual conta anuncia a página (Shark5, Shark30 ou múltiplas).
- Correção local ainda **não publicada**. Nenhum build, deploy ou alteração no banco desta etapa.
- Após definição, cadastrar binding com workspace/conexão conferidos, publicar correção e validar resposta real da coleta.
- Atribuição de mensagem real permanece não homologada. Cadastro de visitas não equivale a contatos nem comprova integração completa dos relatórios.
- Relatório CRM legado depende de `ad_campaigns` e continua sendo uma pendência separada; esta correção não reconstitui origens históricas nem modifica a sincronização Meta.

## Confirmação do usuário e publicação em andamento

Usuário esclareceu: **Shark5 recebe diretamente do Facebook/WhatsApp; Shark30 recebe pela landing page**. Vínculo autorizado: `sharflix` → Shark30 no workspace Shark2, sem alteração da Shark5.

- Correção commit `85b09937`, enviada ao remoto com guarda do worker; oito chaves preservadas.
- Build em clone limpo iniciado para `zapflix-tech:tracking-85b09937`.
- Cadastro preparado com INSERT condicionado à conta/pixel/workspace exatos e validação transacional; não sobrescreve vínculo divergente.
- Validação final usará uma única visita identificada como teste, sem mensagens ou eventos da Meta/analytics. O registro temporário será removido por visitante exato, workspace e ausência de contato, depois de verificar o snapshot da Shark30.

## Publicado e validado — 16/10/2026 05:44 UTC

- Web publicado em `85b09937`, imagem `zapflix-tech:tracking-85b09937`; build em clone limpo concluído e serviço convergido. `/api/version` confirmou SHA.
- Binding `sharflix` criado no workspace Shark2 para Shark30 (`act_2187852758751947`), conexão `d7688941-72d7-4753-a738-4bba33f9ddad`, domínio `landing-page-sharflix.vercel.app`, Pixel `1097829939319128`. Nenhuma associação da Shark5 alterada.
- Chromium com API de coleta real: sete links com uma referência idêntica e válida; reload manteve o código e total de uma coleta. Pixel/analytics bloqueados e nenhuma mensagem enviada.
- Banco confirmou snapshot da conta/conexão/Pixel e UTMs da visita de teste. Uma linha temporária removida por visitante exato, workspace/site e ausência de contato/contacted_at. Nenhum contato, conversa ou pagamento criado/alterado.
- Login200, API Ads Center sem sessão401, web/worker1/1 e oito nomes de chaves do worker preservados.
- Evidência e SQL operacional em `/root/backups/sharflix-tracking-20261016/`. Script público tem cache de até cinco minutos; abas abertas antes do deploy devem ser recarregadas.
- Não foi enviada mensagem para homologar chegada de referência no worker; próximo contato real permitirá essa verificação. O relatório CRM legado ainda requer correção separada: ativar esta coleta não preenche `ad_campaigns` nem reconstrói histórico de origem.

As seções anteriores registram o diagnóstico e o estado anterior à confirmação/publicação; esta seção é o estado atual.
