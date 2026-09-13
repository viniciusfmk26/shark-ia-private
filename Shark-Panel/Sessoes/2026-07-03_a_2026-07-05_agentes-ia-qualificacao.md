# 2026-07-03 a 2026-07-05 — Agentes de IA & Funil de Qualificação

**Período:** 3 a 5 de julho de 2026  
**Tema principal:** Agentes de IA no chatbot (áudio, conferente, Sales Brain) + funil de qualificação + assistente IA embutido

---

## Resumo Executivo

Implementação de **3 agentes de IA** no worker (áudio, conferente, Sales Brain) + **funil de qualificação** (qualify_lead/transfer_to_agent) + **assistente IA embutido** (Proposta B aprovada). Objetivo: automação inteligente de atendimento + transcrição de áudio + qualificação de leads.

---

## Principais Features

### 1. Agente de Áudio (Transcrição + Classificação)
- **Detecção inline:** Reconhece placeholder `[audio]`/`[ptt]` do parser
- **Cloud API:** Detecta e transcreve áudio do Cloud API (`cloud_media_pending`)
- **Transcrição:** OpenAI Whisper via `openai_api_key` do workspace
- **Classificação de intenção:** `classifyMenuIntent` roteia para menu correto
- **Seed automático:** Preenche `audio_transcript` na criação da sessão
- **Fix workspace_id:** Busca `openai_api_key` filtrado por workspace correto

**Bug crítico resolvido:**  
Parser não reconhecia placeholders de áudio → agente nunca era acionado.

### 2. Agente Conferente de IA (Plano Vencido)
- **Node `ai_response`:** Integração com Mastra AI agent (askAgent)
- **Ramo plano vencido:** Conferente responde perguntas sobre renovação
- **Tools disponíveis:** 6 tools integradas (getContact, searchMessages, etc.)
- **Mastra + Anthropic:** `@ai-sdk/anthropic@2` + `@aws-sdk@3.1001.0` (pins críticos)
- **Fallback OpenAI:** Sem chave OpenAI, não quebra (graceful degradation)

### 3. Sales Brain (Etapa 0 + 1)
- **Etapa 0 — Higiene:** Fix `ai_provider_settings` (ignora linhas sem chave)
- **Etapa 1 — Shadow mode:** Agente roda mas não age (apenas observa e loga)
- **Cron ativo:** Rodando desde 2026-07-05 15h (antes parado por bug na chave)
- **Objetivo:** Detectar oportunidades de upsell/cross-sell via IA

**Bug crítico resolvido:**  
`ai_provider_settings` com linhas vazias quebrava cron → filtro `WHERE key IS NOT NULL`.

### 4. Funil de Qualificação
- **Node `qualify_lead`:** Qualifica lead com perguntas estruturadas (nome, empresa, orçamento)
- **Node `transfer_to_agent`:** Transfere para atendente humano após qualificação
- **Libs auxiliares fail-safe:** Tratamento de erros robusto (não quebra flow)
- **Migration:** `jobs.chatbot_interactive_types` expandido para suportar novos nodes

### 5. Assistente IA Embutido (Proposta B Aprovada)
- **Investigação completa:** 3 propostas analisadas (A: Hermes externo, B: embutido read-only, C: interno full)
- **Proposta B escolhida:** Assistente embutido com fase read-only obrigatória
- **Fase 1 implementada:** MCP gate read-only para agentes externos (Hermes)
- **Próxima fase:** Escrita controlada (aguardando aprovação)

**Documento gerado:**  
`PRESENTS_AS_HUMAN_IMPLEMENTATION.md` com análise completa das 3 propostas.

### 6. Troubleshooting Guides
- **Migration:** `troubleshooting_guides` (schema + seed 21 registros)
- **Guias temáticos:** Webhooks, instâncias, chatbot, pagamentos, etc.
- **UI:** Modal de troubleshooting no chatbot builder

---

## Decisões de Arquitetura

1. **Mastra AI:** Framework escolhido para agentes (vs LangChain/OpenAI Agents)
2. **Shadow mode primeiro:** Sales Brain observa antes de agir (reduzir risco)
3. **Workspace-scoped keys:** `openai_api_key` e `anthropic_api_key` por workspace
4. **Fail-safe libs:** Todos os agentes têm fallback gracioso (não quebram chatbot)
5. **Audio transcript seed:** Transcrição armazenada desde criação da sessão (não lazy)

---

## Bugs Críticos Resolvidos

- **Parser áudio:** Placeholders `[audio]`/`[ptt]` não eram reconhecidos → agente nunca rodava
- **Workspace_id:** `classifyMenuIntent` buscava chave global (não do workspace)
- **ai_provider_settings:** Linhas vazias quebravam cron → filtro `WHERE key IS NOT NULL`
- **Timeout:** Cron de timeout usava contact_id (ambíguo) → mudado para conversation_id
- **Throttle Cloud→Evolution:** Mensagens do chatbot caíam no throttle e mudavam instância errada

---

## Migrations & Schema

```sql
-- Troubleshooting guides
CREATE TABLE troubleshooting_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  steps JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed 21 guias
INSERT INTO troubleshooting_guides (category, title, steps) VALUES
  ('webhooks', 'Webhook não recebe eventos', '[...]'),
  ('chatbot', 'Flow não inicia', '[...]'),
  -- ... 19 outros
  
-- Jobs chatbot interactive types
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS chatbot_interactive_type TEXT;
```

---

## Infraestrutura

- **Worker:** `apps/worker/` (processo separado, Docker image `easypanel/wp/zapflix-worker:latest`)
- **Mastra dependencies:** `@mastra/core`, `@ai-sdk/anthropic@2`, `@aws-sdk@3.1001.0`
- **Deploy worker:** Via git push → Easypanel auto-build (~60s, path-scoped)

---

## Pendências em Aberto

- **Hermes (Fase 2):** Escrita controlada aguardando aprovação
- **Sales Brain (Etapa 2):** Piloto ativo após shadow mode estável
- **Audio intent:** Expandir classificação para mais menus além de suporte
