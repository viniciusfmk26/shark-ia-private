# Campanha inteligente pelo orçamento — 15/10/2026

## Fluxo

Na aba **Campanha inteligente**, o operador escolhe uma conta Meta acompanhada, marca uma ou várias campanhas com gasto registrado (ativas ou pausadas) e informa o orçamento diário total em BRL. A lista usa o período máximo disponível pela Meta. Cada campanha marcada gera uma campanha nova: objetivos incompatíveis ficam separados. O orçamento total é repartido igualmente, em centavos, com mínimo de R$ 10/dia por campanha. A prévia de cada origem usa o histórico disponível na Meta e seleciona até 10 conjuntos por custo por resultado. O modo automático legado, sem ID de origem, continua usando os últimos 30 dias completos de campanhas ativas. Resultados são leads para `OUTCOME_LEADS`/`OFFSITE_CONVERSIONS` ou conversas iniciadas para `OUTCOME_ENGAGEMENT`/`CONVERSATIONS`/`WHATSAPP`. A heurística usa amostra mínima e verba por conjunto; não treina uma IA nem prevê conversões. Quando há poucos resultados, limita a exploração. O orçamento informado é aplicado uma vez à campanha CBO ou dividido exatamente entre conjuntos ABO. A estrutura de orçamento da campanha base é mantida. Orçamento total não é aceito nesta cópia.

A publicação usa os endpoints de cópia da Meta para campanha e conjuntos. Assim, a Meta preserva segmentação avançada, posicionamentos, categoria especial e destino. O criativo novo parte do `object_story_spec` do anúncio ativo de imagem escolhido: mantém página, imagem, texto principal, URL, CTA e, se houver, mensagem de boas-vindas do WhatsApp; altera apenas título e descrição. A campanha copiada recebe nome com sufixo `AUTO`; se o nome base começa por `R$`, o valor é ajustado ao orçamento novo. Conjuntos recebem o mesmo sufixo, enquanto anúncios e criativos também recebem `C1`, `C2` etc. A prévia mostra a BM proprietária e a conta de anúncios por nome/ID, campanha base e campanha nova, nomes dos conjuntos/anúncios/criativos, categoria especial, amostra, repartição, textos e URL. A Meta decide a aprovação; anúncios existentes e textos neutros não garantem ausência de bloqueio, entrega ou desempenho.

A análise de fontes pausadas considera anúncios e conjuntos que gastaram no histórico, inclusive quando seu estado efetivo agora é pausado. O texto principal pode estar ausente em criativos antigos de WhatsApp; nesse caso, a mensagem de boas-vindas é preservada.

O botão final exige confirmação. O padrão cria tudo **pausado**. A ativação é uma escolha explícita que pode iniciar gasto após a análise da Meta; anúncios e conjuntos são ligados antes da campanha. O orçamento diário é uma média configurada, não um teto estrito de gasto em cada dia, e continua até a campanha ser pausada.

## Segurança e falha parcial

- `GET /api/ads-center/smart-campaign/sources` lista campanhas e gasto histórico da conta em modo de leitura. `POST /api/ads-center/smart-campaign/plan` é leitura. `POST /api/ads-center/smart-campaign/publish` recompõe o plano e compara chave que cobre orçamento, conta, IDs, segmentação, país da categoria especial e material criativo. Ambos exigem owner/admin, origem pública e corpo limitado.
- Cada campanha marcada recebe `request_id` próprio. A criação reserva esse ID único por workspace em `meta_smart_campaigns` antes da primeira escrita na Meta. Em lote, o cliente publica uma campanha por vez e para na primeira falha; campanhas já tentadas são desmarcadas para evitar duplicação. IDs retornados são gravados um a um; clique repetido não duplica a hierarquia. Os POSTs da Graph API não são repetidos automaticamente.
- Após copiar, a rota lê a campanha e cada conjunto da Meta e exige estado pausado, vínculo, nome e orçamento configurado. Na campanha, também confere conta de anúncios, objetivo, categoria especial e países da categoria. Falha ou timeout após a reserva marca `unknown`; conferir IDs e estado direto na Meta antes de tentar outra solicitação.
- Contas inativas, moeda diferente de BRL, ausência de token de System User com `ads_management`, fonte sem orçamento diário compatível ou anúncio ativo de imagem elegível são recusados. `lifetime_budget: "0"` da Meta equivale a ausência de orçamento total.
- Foram feitas prévias somente de leitura nas duas contas reais ativas: Leads ABO com 6 conjuntos e WhatsApp CBO com 1 conjunto para R$ 100/dia; a segunda mantém `FINANCIAL_PRODUCTS_SERVICES`. Nenhuma campanha ou anúncio real foi criado neste desenvolvimento. **Os endpoints de cópia e criação ainda precisam de homologação em conta Meta de teste antes do primeiro uso de produção.**

## Release e rollback

1. `migrations/20261015_meta_smart_campaigns.sql` já foi aplicada e registrada em produção. Não alterar worker nem cron.
2. Compilar web de clone limpo no SHA do commit; verificar TypeScript web/worker e testes `smart-*`.
3. Confirmar 401 JSON sem sessão nas duas rotas e web 1/1. Prévia autenticada não gera gasto. Homologar a primeira criação pausada em conta de teste antes de ativar.
4. Rollback: voltar apenas à imagem web anterior; preservar tabela de auditoria e IDs remotos para reconciliação.

Referências: [Meta Marketing API](https://www.postman.com/meta/facebook-marketing-api/overview), [Meta SDK — cópia de campanhas](https://github.com/facebook/facebook-python-business-sdk/blob/main/facebook_business/adobjects/campaign.py), [Meta SDK — cópia de conjuntos](https://github.com/facebook/facebook-python-business-sdk/blob/main/facebook_business/adobjects/adset.py).
