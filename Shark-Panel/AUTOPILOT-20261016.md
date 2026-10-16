# Laboratório de campanhas e otimização — 16/10/2026

## Escopo entregue
Central → Campanha inteligente abre o Laboratório. O botão “Cópia de campanhas e chaves da IA” preserva o fluxo anterior e a configuração Groq/OpenRouter.

Cada operação cria uma campanha de imagem na conta escolhida, usando uma origem compatível. O operador escolhe Conversas no WhatsApp (Engajamento) ou Leads no site. Seleção automática usa campanhas ativas e os últimos 30 dias completos; é possível escolher explicitamente uma origem elegível pausada. Não se comparam Leads com conversas para escolher a origem.

O usuário configura orçamento inicial, teto diário configurado, meta de custo, duração (4–30 dias) e modo. A prévia é persistida, expira em 24 horas e mostra BM, conta, página, destino, oferta e variações. O clique final cria campanha, conjuntos e anúncios pausados; a ativação é opcional e explícita. Criar somente a prévia não escreve na Meta.

### Dimensões
- Texto: controle original mais duas variações de texto principal/título/descrição geradas pelo provedor IA configurado. Mantém imagem, página, CTA, destino e mensagem de boas-vindas.
- Imagem: controle mais até três imagens recentes da pasta escolhida no workspace. Não gera imagens novas automaticamente.
- Público: controle, versão ampla quando diferente e até dois interesses encontrados na busca oficial da Meta. Mantém idade, região, exclusões e posicionamentos. Recusa expansão em categorias especiais ou públicos personalizados. A Meta pode expandir interesses conforme configuração da origem.
- Até quatro células, limitadas pela verba: mínimo de R$ 10 e duas vezes a meta de custo por conjunto/dia. Mantém ABO/CBO da origem. Não há teste aleatório nem garantia de entrega igual; a interface chama o processo de exploratório, sem alegar significância estatística.

## Otimização
O padrão é **sugestões**. O operador pode autorizar o modo automático na prévia ou depois, por campanha, com confirmação. Pode desligar os ajustes sem pausar a campanha, ou pausar e encerrar a operação.

O servidor acompanha aproximadamente a cada seis horas, mesmo sem navegador. Lê os últimos três dias completos, evitando incluir o dia da última alteração na janela quando possível. A IA fornece explicação e sugestões de próximos testes no máximo uma vez por dia. A aplicação de orçamento é determinística e não obedece comandos de texto do modelo.

- Só otimiza a hierarquia criada pela operação. Conta, objetivo, filhos, moeda, orçamento e data de término são verificados. Mudanças externas na estrutura bloqueiam o ciclo.
- Pelo menos 72 horas desde início e última mudança. Uma alteração por ciclo, seguida de novo intervalo de observação.
- Pausar conjunto: resultados explicitamente zero e gasto de pelo menos três vezes a meta de custo.
- Reduzir ABO: pelo menos cinco resultados e custo acima de 150% da meta; até 10%, mantendo R$ 10/dia mínimo.
- Aumentar: ao menos dez resultados agregados e custo abaixo de 80% da meta; até 10%, sem superar teto agregado da campanha, incluindo verbas configuradas de conjuntos pausados no ABO. No CBO, altera o orçamento da campanha; no ABO, um conjunto com amostra mínima.
- Frequência alta gera sugestão de próximo teste, não pausa isoladamente.
- Resultado ausente não equivale a zero. Dados incompletos não autorizam mutações. A automação não reativa entidades pausadas.
- O teto é do orçamento diário configurado **desta operação**, não limite rígido de gasto cobrado pela Meta nem teto da conta inteira.
- Encerramento também é configurado em `end_time` de cada conjunto na Meta, para não depender do agendador local.
- Novas campanhas/novos ciclos sempre precisam de revisão e publicação explícita; o módulo sugere próximos testes, não cria novos gastos sem aprovação.

## IA e limites
Usa chave Groq principal/reserva cifrada por workspace; sem configuração Groq, OpenRouter próprio/compartilhado autorizado pelo workspace. Chaves nunca entram no plano ou resposta. Falha ao gerar copy impede preparar aquele teste; falha no comentário periódico mantém regras de decisão e avisa que a IA está indisponível.

Não promete lucro, aprovação ou ausência de bloqueio. O usuário deve revisar oferta, direitos de imagem/conteúdo e destino. Suporte desta entrega: anúncio de imagem com origem compatível Leads/WhatsApp; não equivale a suporte universal de formatos, objetivos, públicos personalizados, carrossel ou vídeo. A criação real ainda depende de permissões, orçamento mínimo e validações da Meta.

## Persistência, segurança e execução
- Migration `20261016_meta_ads_autopilot.sql`: `meta_ads_autopilot` e `meta_ads_autopilot_events`, FK de workspace/conexão, índices de vencimento e histórico.
- API `app/api/ads-center/autopilot/route.ts`: owner/admin, origem, schema estrito, orçamento, limite de prévias/operações, cooldown de preparação. Sem aceitar workspace ou IDs de origem mutáveis do cliente na publicação.
- Serviços `lib/ads-center/autopilot`: plano congelado sem token, fingerprint de origem, bloqueio consultivo PostgreSQL por workspace/operação, IDs remotos persistidos após cada criação, pais ativos por último.
- POST Meta não é repetido. Falha incerta bloqueia a operação; tentativa de pausa do pai após criação/ativação incompleta. Ação de ajuste marca intenção antes de escrever e confirma leitura posterior. Operações interrompidas são marcadas para revisão.
- `scripts/ads-autopilot-loop.cjs` acompanha o processo web, inicia após 60 segundos e chama a rota interna protegida por CRON_TOKEN a cada cinco minutos. Processa uma operação vencida por vez. O lock evita duas execuções simultâneas no rollout. Sem alterar cron existente de mensagens, pagamentos ou importação Meta.
- O acompanhamento exige que o responsável continue owner/admin e a conexão siga válida/acompanhada. Sem operação publicada ativa, o loop não consulta nem escreve na Meta.
- Histórico guarda razões, período, IDs e mudanças; não envia mensagens externas ao usuário.

## Verificação e publicação
- 58 testes de decisões, planejamento, isolamento, publicação, falhas e regressão do criador anterior; 42 testes de interface (100 no total).
- TypeScript web e worker aprovados; prévia Chromium desktop 1440px/mobile 390px sem overflow global ou erros JavaScript.
- Fixtures de criação e monitoramento; **nenhuma campanha real foi criada, ativada ou alterada nos testes**. Homologação autenticada real de lançamento depende da escolha/confirmacão do proprietário na tela.
- Aplicar migration aditiva antes do web, confirmar zero operações no rollout inicial, push com guarda de oito chaves worker, build de clone limpo, conferir SHA e endpoints protegidos. Smoke autenticado do cron só com tabela sem operações elegíveis.
- Rollback: voltar imagem web anterior interrompe o loop. Campanhas já publicadas preservam seu orçamento e data final na Meta; rollback da aplicação não as pausa. Antes de rollback com operações ativas, usar Pausar e encerrar ou conferir diretamente na Meta. Não remover as tabelas/histórico.

## Referências primárias
Campos de campanha, conjunto, orçamento, targeting, status e end_time conferidos no SDK oficial da Meta:
- https://github.com/facebook/facebook-python-business-sdk/blob/main/facebook_business/adobjects/adset.py
- https://github.com/facebook/facebook-python-business-sdk/blob/main/facebook_business/adobjects/campaign.py
Os limiares de otimização são regras conservadoras do produto, não recomendações oficiais da Meta.

## Publicação confirmada

16/10/2026: imagem `zapflix-tech:autopilot-1670bac7`; `/api/version` confirmou `1670bac7`. Migration aplicada e registrada, zero operações no rollout. Web/worker 1/1; guarda confirmou oito chaves do worker. API e cron sem autenticação retornaram 401 JSON, login 200. Cron autenticado com fila vazia retornou 200 `{processed:0}`. Build aprovado, processo de acompanhamento presente no web. Nenhuma escrita na Meta foi feita no smoke.
