# 2026-05-17 a 2026-05-25 — UI Refactor Enterprise

**Período:** 17 a 25 de maio de 2026  
**Tema principal:** Redesign completo da interface em estilo enterprise/Linear — densidade 3x maior, cards compactos, KPIs refinados

---

## Resumo Executivo

Refatoração visual completa de 5+ telas principais (dashboard, trials, pedidos, tags, automações) seguindo estilo **Stripe/Linear** — densidade alta, cards com `border-l-4`, grids compactos, empty states refinados. Objetivo: maximizar informação útil por pixel, reduzir scroll.

---

## Principais Features

### 1. Dashboard Refactor (v19)
- **Grid redesenhado:** KPI bar horizontal + cards com `border-l-4` + tabelas densas
- **Cards lado a lado:** PIX+Leads (6+6 colunas), Funis+Saúde na mesma linha
- **Gráficos:** Comparação hora a hora (chats vs vendas), hoje vs ontem com contraste visual
- **KPIs refinados:** Receita total do workspace (não por usuário), trials com lógica unificada
- **Alertas:** Badge BRT (timezone correto), alertas de queda de chats após 10h e -55%

### 2. IPTV — Recorrência & Renovação
- **Aba Recorrência:** KPIs, forecast, lista de vencimentos, envio de cobrança inline
- **Renovação multi-instância:** Modo fixo/aleatório/sequencial + fallback automático
- **Status renovado:** Baseado em payments (não `updated_at`)
- **Detecção de estornos:** Sistema automático de bloqueio + tag "Estornado"
- **Edição inline:** Preços editáveis direto no painel master plans

### 3. Tags & Pipeline
- **Sidebar scroll independente:** Busca de tags + scroll isolado
- **Avatares reais:** Pipeline exibe fotos dos contatos (não placeholders)
- **Reorg módulos:** Tags & Refollow movidos para seção "Automação"

### 4. Automações
- **Templates predefinidos:** Seleção múltipla no modal "Nova automação"
- **Layout 2 colunas:** Página de detalhe com informações compactas

### 5. Inbox & Chat
- **Bloqueio de conversa:** Atendente pode bloquear conversa com expiração automática
- **Favoritos:** Botão de favorito no header do chat
- **Auto-close:** Preserva `unread` como `pending` (não marca como lido)

### 6. Media Library
- **Editar imagem:** Modal de edição inline
- **Visualizar grande:** Lightbox + download direto

---

## Decisões de Arquitetura

1. **Densidade 3x:** Reduzir padding/margin em todos os cards — mais informação por tela
2. **Border-l-4:** Indicador visual de categoria/status (cor por tipo de card)
3. **Grid items-start:** Remover `h-full` dos cards internos para eliminar espaço vazio vertical
4. **KPI bar:** Bloco horizontal fixo no topo com métricas principais (não cards separados)
5. **Empty states refinados:** Mensagens claras + ícones + ações sugeridas

---

## Bugs Críticos Resolvidos

- **Isolamento workspace:** Corrigido em jobs e webhooks (queries filtradas por workspace_id)
- **Coluna sent_by_user_id:** CTE do painel "Meu Desempenho" corrigida
- **Thresholds alertas:** Ajustado para -55% após 10h (evitar falso positivo)
- **Blacklist phone_e164:** Normalizar formato no JOIN com contacts (remover `+`)

---

## Migrations & Schema

- Nenhuma migration crítica neste período (apenas ajustes de queries)

---

## Próximos Passos (na época)

- Expandir dashboard tabs (instâncias/atividades/pedidos)
- Implementar analytics standalone
- Refinar painel de instâncias com stats detalhadas
