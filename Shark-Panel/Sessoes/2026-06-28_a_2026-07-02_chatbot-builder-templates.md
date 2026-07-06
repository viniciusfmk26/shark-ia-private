# 2026-06-28 a 2026-07-02 — Chatbot Builder & Templates WhatsApp

**Período:** 28 de junho a 2 de julho de 2026  
**Tema principal:** Editor de chatbot visual + templates WhatsApp + módulos SMS/Email temporários

---

## Resumo Executivo

Desenvolvimento do **chatbot builder** (drag & drop, simulador visual, nodes interativos) + sistema de **templates WhatsApp** integrado com Meta + **SMS temporário** (Grizzly) + **Email temporário** (Mailcow). Objetivo: permitir automações visuais sem código + verificação de contas.

---

## Principais Features

### 1. Chatbot Editor Visual
- **Drag & drop:** Arrastar nós da sidebar para o canvas
- **Nodes por categoria:** Abas organizadas (Mensagem, Interação, Controle, Integração)
- **Simulador inline:** Preview WhatsApp ao lado do editor + modal de edição de nó
- **Mensagens interativas:** Suporte a botões (Menu) e listas nativas do WhatsApp
- **Filtro por instância:** Ver/editar flows específicos de cada instância
- **Badge status:** Indicador visual de flows ativos/inativos/rascunho

**Tipos de nodes implementados:**
- `question` (menu numerado vs botões nativos)
- `message` (texto simples)
- `media` (imagens/vídeos/documentos do MinIO)
- `condition` (if/else baseado em variáveis)
- `set_var` / `remove_tag` (manipulação de estado)
- `ai_response` (integração com agente IA)
- `capture` (capturar resposta em variável)
- `incident_notice` (notificação de incidente)

### 2. Templates WhatsApp
- **Listagem:** Todos os templates aprovados na Meta
- **Preview:** Visualização do template com variáveis substituídas
- **Verificação de status:** Consulta API Meta para confirmar aprovação
- **Cloud API:** Aviso quando instância não tem Cloud API configurada
- **Exclusão:** Deletar templates direto da UI
- **Seção "Meus Templates":** Sempre visível (fix renderização condicional)

### 3. SMS Temporário (Grizzly SMS)
- **Integração Grizzly SMS API:** Recebimento de SMS temporários para verificação
- **Seletor de país:** Dropdown customizado com busca + bandeiras + favoritos por usuário
- **Preços dinâmicos:** Busca via `getPrices` (ação correta, V3 não existe)
- **Webhook público:** Recebimento automático de SMS via callback
- **Limite de render:** Apenas serviços com estoque (performance)
- **País padrão:** 187 (consistente em toda aplicação)

### 4. Email Temporário (Mailcow)
- **Multi-domínio:** sharkpanel.com.br (padrão) + domínios custom
- **Prefixo personalizado:** Usuário escolhe prefixo do email
- **Histórico:** Emails recebidos nos últimos 10 minutos
- **Inbox automático:** Integração com Mailcow via API
- **Extração de código:** Detecção automática de códigos de verificação
- **Sessões persistentes:** Múltiplos emails/SMS simultâneos por usuário

### 5. Kit de Verificação Unificado
- **SMS + Email inline:** Mesma tela para ambos os métodos
- **Seletor global de país:** País persiste entre abas
- **Expansível:** Cards SMS/Email com expand/collapse
- **Favoritos:** Marcar países como favoritos (persistido em `user_favorite_countries`)
- **Saldo Grizzly:** Exibição de créditos + avisos de saldo baixo

### 6. Meta CAPI (Conversions API)
- **Atribuição CTWA:** Rastreio de vendas originadas de Click to WhatsApp Ads
- **Captura `ctwa_clid`:** Extração do parâmetro de atribuição da Cloud API
- **OAuth Grant:** Busca de páginas via Business Manager + permissões corretas

---

## Decisões de Arquitetura

1. **Chatbot simulador:** Preview WhatsApp realista (bolhas, timestamps, avatares)
2. **Node types extensíveis:** Sistema de plugins para novos tipos de nó
3. **Mailcow integration:** MAILCOW_API_URL e MAILCOW_API_KEY em env vars
4. **Grizzly SMS:** País padrão 187, action `getPrices` (não V3), webhook público
5. **Meta CAPI:** Evento `Purchase` enviado para cada venda atribuída a CTWA

---

## Bugs Críticos Resolvidos

- **Templates:** Seção "Meus Templates" não renderizava (condicional errada)
- **SMS:** Action `getPrices` correta (V3 não existe), país padrão consistente
- **Email:** Domínio padrão sharkpanel.com.br (não estava definido)
- **Chatbot:** `instanceId` plumbado direto no `startEventFlow` para eventos payment/tag
- **Chatbot:** Proteção anti-loop (sessão ativa + cooldown + não responder próprias mensagens)

---

## Migrations & Schema

```sql
-- Favoritos de países (SMS)
CREATE TABLE user_favorite_countries (
  user_id UUID REFERENCES nextauth_users(id),
  country_code VARCHAR(10),
  PRIMARY KEY (user_id, country_code)
);

-- Email temporário (sessões)
CREATE TABLE temp_email_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES nextauth_users(id),
  email_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '10 minutes'
);
```

---

## Infraestrutura

- **MAILCOW_API_KEY:** Variável de ambiente necessária (não estava no Easypanel)
- **Grizzly SMS webhook:** Rota pública `/api/sms/webhook` para receber callbacks
- **Meta CAPI:** Token de acesso com permissão `ads_management` + `business_management`

---

## Próximos Passos (na época)

- Implementar timeout de sessão do chatbot (abandono)
- Adicionar agente de IA para transcrição de áudio
- Nodes avançados: `qualify_lead`, `transfer_to_agent`
