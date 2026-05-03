---
# Zapflix SaaS — Estratégia de Refactor Multi-tenant
Data: 2026-05-03

## Objetivo
Transformar o Zapflix de uma ferramenta IPTV com branding diferente
em um SaaS multi-tenant genérico e profissional.

## Sistema de Módulos

### CORE (sempre visível — plano free)
- Dashboard
- Inbox
- Contatos (sem colunas IPTV)
- Instâncias WhatsApp
- Follow-ups
- Templates (sem features IA)
- Configurações
- Meu Plano
- Ajuda

### MÓDULO IPTV
- Trials no header
- Recorrência
- Vitrine IPTV
- Plano IPTV no painel lateral
- Vincular Usuário IPTV
- Ativar Tela Extra
- Colunas Trial/Vencimento nos contatos
- Username IPTV no registrar pagamento
- Ativar no Sigma
- Número de Telas no PIX

### MÓDULO CHECKOUT/VENDAS
- Catálogo
- Pedidos
- Cupons
- Faturamento
- Checkout — Enviar Cobrança
- Botão $ no inbox

### MÓDULO PAGAMENTOS
- Registrar Pagamento
- Cobrar PIX Manual
- R$ 0,00 no header

### MÓDULO IA
- Estúdio IA
- Botão OFF/ON IA no inbox
- Sugestão IA no painel lateral
- Resumo de conversa
- Gerar áudio com IA
- Knowledge Base nos templates
- Gerar com IA nos templates

### MÓDULO AUTOMAÇÕES
- Agendadas no header
- Raio ⚡ no inbox toolbar
- Modal automações pendentes
- Cancelar automações

### MÓDULO EQUIPE
- Performance/Gamification
- Mensagens Failover
- Backup P1/P2
- Transferir Conversa

### MASTER ONLY
- Audit Log
- Logs de auditoria

## Backlog Priorizado

### 🔴 SEMANA 1 — Bugs + Módulos

#### Bugs críticos:
- [ ] Fix blacklist erro ao carregar
- [ ] Fix gatilhos de texto erro ao carregar
- [ ] Fix nota interna duplicada ao enviar
- [ ] Fix ícone nota duplicado na toolbar
- [ ] Fix botão "Ver Planos & Upgrade" não navega
- [ ] Fix Estúdio IA redireciona para dashboard

#### Sistema de módulos:
- [ ] Criar hook useModules() 
- [ ] Header condicional (Trials, Agendadas, R$)
- [ ] Sidebar condicional por módulo
- [ ] Inbox toolbar condicional
- [ ] Menu ⋮ inbox condicional (IPTV, PIX)
- [ ] Painel lateral condicional (Plano IPTV, Sigma)
- [ ] Contatos: colunas/filtros/ações IPTV condicionais
- [ ] Templates: features IA condicionais
- [ ] Pedidos: só com Checkout ou IPTV

#### Signup melhorias:
- [ ] Tags padrão criadas automaticamente no signup
  (Urgente, Em andamento, Resolvido, Aguardando, Cancelado)

### 🟡 SEMANA 2 — UX Core

- [ ] Tag rápida na toolbar do inbox (popover)
- [ ] Editar/excluir nota interna
- [ ] Aviso de sincronização ao conectar instância nova
- [ ] Placeholder instância: "Ex: Celular principal, iPhone vendas..."
- [ ] Remover "Nenhum trigger configurado" sem módulo
- [ ] Nomenclatura: "Sincronizar Evolution" → "Sincronizar WhatsApp"
- [ ] Nomenclatura: "Conectar Evolution" → ocultar ou renomear
- [ ] Nomenclatura: "Backup P1/P2" → "Instância reserva 1/2"

### 🟢 SEMANA 3 — Features Novas

- [ ] Onboarding wizard (3 passos ao primeiro login)
- [ ] Kanban de tickets
- [ ] Vitrine genérica (não IPTV)
- [ ] Empty states informativos em todas as páginas

## Regras de Arquitetura

### Hook useModules()
```typescript
// Lê modules do workspace_settings
// Retorna objeto com flags booleanas
const { hasIPTV, hasCheckout, hasAI, hasTeam, hasCampaigns } = useModules()
```

### Cascata de visibilidade
<!-- seção incompleta — continuar -->
