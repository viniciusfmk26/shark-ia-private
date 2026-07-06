# 2026-05-26 a 2026-06-27 — Compliance Meta 24h & Infraestrutura

**Período:** 26 de maio a 27 de junho de 2026  
**Tema principal:** Compliance Meta (janela 24h, throttling Cloud API) + infraestrutura (SSL, deploy, monitoring) + melhorias gerais

---

## Resumo Executivo

Implementação de **throttling Cloud API** para cumprir limite 24h da Meta + **sistema de notificações Telegram** (escopo workspace/instância/global) + **watchdog de deploy** + melhorias em IPTV, visão computacional, prospecção CNPJ/PDF. Período com muitos commits (~300), foco em estabilidade e compliance.

---

## Principais Features

### 1. Compliance Meta — Janela 24h
**Problema:** Meta limita mensagens iniciadas a 1 por 24h para números sem opt-in.

**Solução implementada:**
- **Throttling Cloud API:** Marca mensagem como `is_reactive_reply` se dentro da janela
- **Fallback Evolution:** Se Cloud API recusar, tenta Evolution API (não tem limite Meta)
- **Detecção de janela:** Busca última mensagem do contato nos últimos 24h

**Bug crítico resolvido:**  
Chatbot timeout enviava pela instância errada ("Iphone") devido a fallback sem verificação de `is_reactive_reply` → fix aplicado.

### 2. Sistema de Notificações Telegram
**Arquitetura:**
- **3 escopos:** Workspace, Instância, Global
- **Events:** `deploy_failed`, `instance_down`, `webhook_error`, etc.
- **Dispatch:** `lib/notifications/dispatch.ts` (router inteligente)
- **Configuração:** Tabela `notification_configs` (telegram_chat_id por workspace/instância)

**Migrations:**
```sql
CREATE TABLE notification_events (
  id UUID PRIMARY KEY,
  event_type TEXT NOT NULL,
  scope TEXT NOT NULL, -- workspace | instance | global
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notification_configs (
  workspace_id UUID REFERENCES workspaces(id),
  instance_id UUID REFERENCES whatsapp_instances(id),
  telegram_chat_id TEXT,
  enabled BOOLEAN DEFAULT true
);
```

### 3. Deploy Watchdog & Infraestrutura
**Watchdog de deploy:**
- Monitor contínuo de `/api/version` a cada 15s
- Alertas Telegram se SHA divergir >5min
- Escopo por serviço (web, worker, checkout)

**Descoberta crítica:**  
`wp_zapflix-web` **NÃO** auto-deploya via Easypanel git push → criado script `deploy-web.sh` manual.

**SSL/Traefik:**
- Cert wildcard `*.sharkpanel.com.br` via drop-in Traefik (expira 2026-09-09, sem auto-renovação)
- `emit-ssl` grava em `zapflix-custom.yaml` (mounts manuais são efêmeros no Easypanel)

### 4. Visão Computacional (Image Recognition)
**Feature:** Dual-provider para reconhecimento de imagens (OpenAI GPT-4o + Anthropic Claude).

**Implementação:**
- Provider configurável por workspace (`image_recognition_provider`)
- Fallback automático se provider primário falhar
- Retry com backoff exponencial
- URL atualizada + erro visível na UI

**Migration:**
```sql
ALTER TABLE workspaces ADD COLUMN image_recognition_provider TEXT DEFAULT 'openai';
```

### 5. Prospecção CNPJ/PDF
**Feature:** Upload de PDF com lista de CNPJs → scraping automático de dados da Receita Federal.

**Fluxo:**
1. Upload PDF via UI
2. Extração de CNPJs via regex
3. Consulta API Receita (ou cache interno)
4. Enriquecimento de contatos com razão social, endereço, telefone

**Limitações:** Rate limit da API Receita (60 req/min) → fila de processamento.

### 6. IPTV — Melhorias Diversas
- **Renovação multi-instância:** Modo fixo/aleatório/sequencial
- **Badge renovação:** Links de checkout com `?renewal=true`
- **Estornos:** Detecção automática + tag "Estornado" + bloqueio
- **Blacklist:** Normalização `phone_e164` (remover `+` no JOIN)
- **Dashboard:** Instância nos pedidos, badge renovação vs nova venda

---

## Decisões de Arquitetura

1. **Throttling:** Cloud API primeiro, Evolution como fallback (não inverso)
2. **Notificações:** Escopo hierárquico (instância > workspace > global)
3. **Deploy:** Manual via script (Easypanel webhook não confiável)
4. **SSL:** Traefik custom YAML (não UI do Easypanel, que reverte mounts)
5. **Vision:** Dual-provider com fallback (OpenAI → Anthropic)

---

## Bugs Críticos Resolvidos

- **Chatbot timeout → instância errada:** Fallback Cloud→Evolution sem `is_reactive_reply`
- **Webhook Evolution 500:** Instância "rouba conversa" sem log → fix com conversation_id
- **Deploy não automático:** wp_zapflix-web não deploava → script manual criado
- **SSL efêmero:** Mounts Easypanel revertiam → configurar na UI, não via YAML
- **MAILCOW env vars:** MAILCOW_API_URL e MAILCOW_API_KEY ausentes no container

---

## Migrations & Schema

```sql
-- Notificações Telegram
CREATE TABLE notification_events (...);
CREATE TABLE notification_configs (...);

-- Image recognition provider
ALTER TABLE workspaces ADD COLUMN image_recognition_provider TEXT DEFAULT 'openai';

-- AI decisions log
CREATE TABLE ai_decisions_log (
  id UUID PRIMARY KEY,
  workspace_id UUID REFERENCES workspaces(id),
  decision_type TEXT,
  input_data JSONB,
  output_data JSONB,
  model TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Anthropic API key
ALTER TABLE ai_provider_settings ADD COLUMN anthropic_api_key TEXT;
```

---

## Infraestrutura

### Variáveis de Ambiente Faltantes
- `MAILCOW_API_URL` (para email temporário)
- `MAILCOW_API_KEY`
- `ENCRYPTION_KEY` (32 chars, para leitor IMAP)

### Serviços Ativos
- `wp_zapflix-web` (tráfego real app.sharkpanel.com.br)
- `wp_zapflix` (serviço interno)
- `wp_zapflix-worker` (BullMQ, processo separado)
- `wp_zapflix-cron` (jobs agendados)
- `wp_zapflix-agent-gate` (MCP server Hermes)

### Deploy
- **Web:** Manual via `deploy-web.sh` (build + service update + SHA validation)
- **Worker:** Auto-deploy via Easypanel (~60s, path-scoped)

---

## Pendências em Aberto (na época)

- Renovar cert SSL antes de 2026-09-09
- Configurar auto-renovação SSL (Let's Encrypt?)
- Adicionar MAILCOW/ENCRYPTION_KEY no Easypanel
- Migração auth.users → nextauth (planejada, não executada ainda)

---

## Próximos Passos (na época)

- Chatbot builder visual (drag & drop)
- Templates WhatsApp integrados
- Agentes de IA (áudio, conferente, Sales Brain)
