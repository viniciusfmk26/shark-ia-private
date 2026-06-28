# Sessão 40 — Shark Panel
**Data:** 27/06/2026
**Duração:** ~8h (sessão longa)
**Foco:** Auditoria do sistema, Meta Ads completo, Sistema IA, Comentários, Instagram DMs e Funis

---

## Contexto

Sessão iniciada com verificação de saúde do sistema pós-sessão 39. Evoluiu para implementação de um ecossistema completo de Marketing no Shark Panel: Meta Ads dashboard, IA especialista em anúncios, comentários automatizados e módulo completo de Instagram DMs com funis visuais.

---

## O que foi feito

### 1. Correções de infraestrutura

**wp_zapflix-cron parado há 34h:**
- Causa: restart-condition: on-failure não reiniciava após SIGTERM limpo (exit 0)
- Fix: rebuild da imagem + restart-condition: any --restart-delay 10s

**check-webhook-tokens gerando 404 falsos:**
- Instâncias Cloud API (Julia Abreu, Marlene Marafiga) e Chat Web (Uniflix) não existem na Evolution API
- Fix: filtro SQL `AND (provider = 'evolution' OR provider IS NULL)`
- Commit: ff2fa730

---

### 2. Meta Ads Dashboard v2 — /campanhas/meta

**API atualizada:**
- Summary com comparativos _prev (hoje vs período anterior)
- CPM, Frequência e ROAS calculados
- Mock data automático quando sem spend real (3 campanhas + 30 dias)
- Períodos: Hoje | Ontem | 7d | 14d | 30d | Mês atual

**UI redesenhada:**
- Banner amarelo em modo demo
- Score de saúde 0-100 com barra colorida no header
- 9 cards com delta ↑↓% e tooltip ℹ️ explicativo
- ComposedChart: área azul (gasto) + linha laranja (cliques)
- Barras horizontais por campanha: Gasto vs Alcance
- Tabela: ROAS colorido, Frequência colorida, toggle play/pause

**Sistema de Insights interativos:**
- Cards accordion priorizados: 🚨 Perigo → ⚠️ Atenção → 🚀 Sucesso → 💡 Info
- Cada insight: descrição leiga, O que fazer, Entenda, botão Entendi ✓

Commits: 7e53b240, 4ef8c251

---

### 3. Sistema IA Meta Ads — Migration 155

**Tabelas:** ad_campaign_presets, ad_campaign_rules, ad_campaign_ai_analyses

**9 presets seedados:**
📺 IPTV · 🎓 Infoproduto · 🛒 E-commerce · 🏥 Clínica · 🏠 Serviços · 🖥️ Landing Page · 💳 Checkout · 💬 WhatsApp Direto · 📸 Orgânico Instagram

**4 rotas API:**
- POST /api/ad-campaigns/[id]/ai-analysis — análise Claude Haiku cache 1h
- CRUD /api/ad-campaigns/[id]/rules — regras automáticas
- GET /api/ad-campaigns/presets
- POST /api/meta/consultor — streaming

**Sub-aba 🤖 IA em cada campanha:**
- Gauge SVG 0-100, recomendações, alertas, previsão 7 dias
- RulesManager: pausar/alertar/escalar por CPL/CPA/ROI/CTR
- PresetSelector: grid 3×3 dos 9 nichos

Commit: c086090

---

### 4. Consultor IA Marcus Ramos — /campanhas/consultor

**Parser visual de mensagens:**
- Tabelas → cards animados (countUp 1.5s)
- Headings de campanha → cards com borda colorida + badge pulsante
- Seções de ação → botões funcionais (Pausar, Escalar +20%, Falar sobre)
- Alertas ❌⚠️✅ → alert boxes coloridos

**Funcionalidades:**
- Bubble usuário: gradiente azul→violeta
- "Marcus Ramos está digitando..." com 3 dots animados
- 9 quick prompts com ícones
- Botões de ação: Pausar campanha, Escalar +20% (resolve por nome)

Commit: 597b5fd3

---

### 5. Sistema de Memória — Migration 156

**Tabelas:** meta_advisor_conversations, meta_advisor_knowledge, meta_advisor_insights

**3 abas no Consultor:**
- 💬 Chat: sidebar de histórico, auto-save automático
- 📚 Base de Conhecimento: formulário com tipo e tags
- 💡 Insights: Haiku analisa campanhas com leads > 10

**Marcus injeta no system prompt:**
- MEMÓRIAS DE CONVERSAS ANTERIORES (conversation_memory)
- CONHECIMENTO DA BASE (manual)
- APRENDIZADOS DAS CAMPANHAS (insights)

**Memória cruzada automática:**
- Ao trocar/encerrar conversa (≥4 msgs): Haiku resume em 150 palavras
- Salva como conversation_memory, toast 💾 Memória salva

Commits: 93af873d, 111f7d28

---

### 6. Unificação Campanhas

**Antes:** 3 itens separados no sidebar
**Depois:** 1 item Campanhas com 4 abas:
- 💬 WhatsApp → /campanhas/whatsapp
- 📊 Meta Ads → /campanhas/meta
- 🤖 Consultor IA → /campanhas/consultor
- 💬 Comentários → /campanhas/comentarios

Commit: 61f5d669

---

### 7. Sistema de Comentários Meta — Migration 157

**Tabelas:** meta_posts, meta_post_comments, meta_comment_automations, meta_comment_automation_logs

**Funcionalidades:**
- Sync posts FB + IG via Graph API
- Responder, ocultar e excluir comentários
- Automações: keyword → resposta pública automática
- Cron sync-meta-comments a cada 5 min

Commit: 8f79f2c8

---

### 8. Instagram DMs + Funis — Migration 158

**Tabelas:** ig_conversations, ig_messages, ig_funnels (steps JSONB), ig_funnel_states

**Engine lib/ig-funnel-engine.ts:**
- sendIGDM() — DM com quick_replies via Graph /me/messages
- executeFunnelStep() — envia passo + botões, atualiza estado
- processIncomingDM() — avança funil por botão ou keyword

**Webhook /api/webhooks/instagram:**
- GET: verificação Meta (INSTAGRAM_VERIFY_TOKEN fallback CRON_TOKEN)
- POST: messages, postbacks, comments
- Resolve workspace: ig_business_account_id → meta_page_id → fallback

**Nova seção INSTAGRAM no sidebar:**
- DMs → /instagram/dms (inbox 3 colunas: lista | thread | contexto)
- Funis → /instagram/funis (grid + construtor de etapas com botões)

**Bubbles estilo Instagram:** gradiente roxo/rosa

Commits: 8a29a1d3, 42849963

---

## SHA em produção: 42849963

## Migrations do dia

| # | Nome | O que faz |
|---|---|---|
| 155 | ad_campaign_ai_system | Presets, regras e análises IA |
| 156 | meta_advisor_memory | Memória do consultor |
| 157 | meta_comments_system | Comentários Meta |
| 158 | instagram_dm_funnels | Instagram DMs e funis |
| — | 20260627_ig_account_id | ig_business_account_id na conexão |

---

## Pendências para sessão 41

### Configuração imediata
- [ ] Adicionar INSTAGRAM_VERIFY_TOKEN=shark-instagram-webhook-2026 no EasyPanel
- [ ] Registrar webhook no app Meta: https://app.sharkpanel.com.br/api/webhooks/instagram
- [ ] Solicitar instagram_manage_messages Advanced Access no app Meta
- [ ] Gravar screencast para App Review Meta
- [ ] Corrigir DKIM DNS revistagosto.com.br na Hostinger: dkim_domainkey → dkim._domainkey
- [ ] Criar mailbox vinicius@sharkpanel.com.br no Mailcow

### Melhorias planejadas
- [ ] Canvas drag-and-drop para construtor de funis
- [ ] Fase 2 Meta Ads: linking Meta campaign_id ↔ ad_campaigns (ROI real)
- [ ] VPS nova Hostinger KVM2 (SharkMail + SharkFlow)

### Backlog técnico
- [ ] trigger_id nos jobs do processAutomaticTriggers
- [ ] Campo throttle_limit editável na UI de compliance
- [ ] 174 vendas checkout_pix sem sold_by_user_id
- [ ] Badge payment_type na página de Pedidos
- [ ] Botão PDF no modal de criação de empresa
- [ ] Query lenta com filtro data + nome na prospecção
- [ ] MinIO custom domain
- [ ] Wildcard cert expira 09/09/2026 — renovar em agosto
- [ ] Política de retenção de audit_logs

---

## Lições aprendidas

- App Review Meta tem 2 níveis: Standard (funciona hoje para contas próprias) e Advanced (precisa aprovação)
- Meta não fornece telefone do comentarista — ponte é via link wa.me ou permissão especial de parceiro
- restart-condition: any obrigatório para processos contínuos como supercronic
- Sempre filtrar instâncias por provider = evolution em verificações de webhook Evolution
- Construtor de funis em lista JSONB é funcionalmente equivalente ao canvas visual para MVP
