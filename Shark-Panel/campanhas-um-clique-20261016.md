# Campanhas de 1 clique — correção da seleção de modelos (16/10/2026)

O laboratório mostrava erro genérico quando a campanha utilizável estava pausada. Também recusava anúncios de imagem sem título/texto principal explícito, mesmo quando já tinham gasto e entrega na Meta. A seleção agora consulta anúncios e gastos por campanha, mostra o motivo de inelegibilidade, aceita campanhas ativas ou pausadas e usa o histórico completo na prévia. Anúncios reprovados/com problemas continuam fora. O nome existente do anúncio é usado como título quando o criativo não traz um; o operador vê a copy e o destino antes de publicar.

Somente contas acompanhadas com token de usuário do sistema aparecem na criação. A conta da campanha de origem determina a conta de destino. O orçamento diário, formato ABO/CBO, público, destino e categoria especial continuam preservados. Prévia não cria nem ativa anúncios; lançamento exige revisão explícita e pode ficar pausado.

Validação de leitura na Meta: Mari 04 (WhatsApp pausada, 10 conjuntos), Shark30 (Leads, 6), Shark 5 (WhatsApp, 2), Shark Filmes 3 (Leads, 3). A prévia completa de copy da Mari 04 gerou controle + 2 variantes via Groq GPT OSS 120B. Nenhum POST de criação Meta foi feito. Testes unitários, UI e TypeScript precisam acompanhar o deploy.
