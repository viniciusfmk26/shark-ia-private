# Zapflix-Tech — Sessão 4+5 (2026-05-04)

## Contexto
- VPS: 69.62.91.79, EasyPanel + Docker Swarm
- Repo: github.com/viniciusfmk26/Zapflix-Tech
- Workspace teste: shark-panel (00000000-0000-0000-0000-000000000002)

## Commits deployados

| Commit | Feature |
|---|---|
| 77b6660b | Simplificar Meu Negócio |
| cea7d913 | Foto WhatsApp via Evolution |
| f1e102ac | Card "Pedidos hoje" no dashboard |
| e4953de6 | Restaurar Horário de Atendimento |
| 97f7da69 | Pedidos adaptado ao nicho |
| c4b1a9be | NICHO_CONFIG alinhado + infoproduto + produto_fisico |
| 94008e42 | Upload mídia S3 no campo imagem |
| 41c9706b | Toggle canal de suporte por instância |
| 07d9e49f | Feature gating completo no sidebar |
| f6d8152e | Tabela module_trials + getWorkspaceFeatures com UNION |
| 92496e69 | API master GET/POST/DELETE module-trials |
| d0aa5a83 | UI master — aba Módulos & Trials |
| 7b8d42ad | Badge Trial no sidebar + cron cleanup |
| 2145e9bb | Nicho salvo dispara applyDefaultFeatures |
| d2e0eebd | Filtros de status dinâmicos pelo nicho |
| 25da4ccc | Foto WhatsApp corrigida (4 bugs) |

## Arquitetura implementada

### Feature Gating
- workspace_features: módulos permanentes por workspace
- module_trials: módulos temporários com expires_at
- getWorkspaceFeatures faz UNION das duas tabelas
- Workspace nova nasce com inbox + instances apenas
- Nicho salvo chama applyDefaultFeatures automaticamente

### Module Trials (master)
- POST /api/master/module-trials → concede trial por X dias
- DELETE /api/master/module-trials → revoga imediatamente
- Badge "Xd" no sidebar quando trial ≤ 7 dias
- Cron /api/cron/cleanup-module-trials → limpa expirados

### Créditos (mapeamento)
- Créditos IPTV: R$5,00/crédito → 1 ativação = 1 mês
- Créditos workspace: pacotes para IA, ElevenLabs, etc
- São dois sistemas separados

## Backlog próxima sessão
- Whitelabel no checkout (logo/cores do cliente)
- Onboarding guiado (tutorial workspace nova)
- Portal de suporte público
- Ticket automático por compra (fulfillment)
- Corrigir DEFAULT_FEATURES_BY_NICHO se necessário

## Decisões de produto
- Nicho não libera módulo pago automaticamente
- Módulos extras: trial via master ou plano pago
- Toggle "Canal de suporte" por instância WA
- Ticket automático só em instâncias marcadas como suporte
- model_trials: 1 trial por módulo, upsert ao renovar

## Commits adicionais (pós-sessão)

| Commit | Feature |
|---|---|
| 33b22d20 | fix(sidebar): remover exceção ai_studio sempre visível |
| 5b4f149e | fix(settings): gate IPTV no payments + traduzir Segurança e Webhooks |

## Problemas identificados em /settings
- Templates IPTV apareciam para todos os nichos → corrigido
- Seções em inglês (Segurança, Webhooks) → traduzidas
- Estúdio IA aparecia sem feature gate → corrigido

## Sessão 6 — Continuação (2026-05-04 tarde)

### Commits

| Commit | Feature |
|---|---|
| e9a34aa0 | Créditos IA: 100 grátis + débito + tela de compra |
| d7366f1d | Tag automática em automation triggers |
| 7b4b9886 | Seleção em massa de contatos |
| 8a32fd6c | Filtro sem tag + CSV com tag + campanha da lista + toggle IA |
| c1737f26 | Campos endereço ocultos para nichos sem entrega física (pedidos) |
| b2f80ce4 | Fix: nicho salvo corretamente ao trocar em meu-setup |
| 52bb6dee | Limite de membros por plano + compra de vagas R$15 |
| c101eb70 | Fix: endereço oculto no inbox para nichos sem entrega |
| 55c1aa3e | Fix: features desabilitadas por padrão |
| 48336792 | Fix: modules baseado em workspace_features |

### Arquitetura

**Créditos IA:**
- lib/server/ai-credits.ts: getAiBalance, hasAiCredits, debitAiCredits
- 100 créditos grátis no signup
- use_shared_key toggle em ai_provider_settings
- Pacotes: 500/1000/5000 créditos = R$29/49/149

**Feature gating corrigido:**
- /api/settings agora lê workspace_features e mapeia para modules
- iptv → iptv_trials + iptv_apps
- campaigns → campaigns
- ai_responses → ai_agents
- checkout → billing
- funnels → guided_funnel
- use-modules hook: features === true (não !== false)

**Limite de membros:**
- Free: 1 / Starter: 3 / Pro: 10 / Enterprise: 999
- Compra de vaga extra: R$15 via PIX (Amplopay)
- Bloqueia convite quando limite atingido

**Tags automáticas:**
- Trigger type 'tag' no worker → aplica tag ao contato sem job
- UI: select de tags no editor de gatilhos

**Contatos:**
- Seleção em massa com checkbox
- Bulk: aplicar tag, remover tag, deletar, criar campanha
- Filtro "sem tag"
- CSV com coluna tag
- Campanha direto da lista filtrada

### Backlog sessão 7
- Editor visual de checkout com preview iframe
- Página de obrigado customizável
- Onboarding guiado (ÚLTIMO antes do beta)
- Reorganização do Settings (Geral/Mensagens/Chat)
- Amplopay por workspace
- Custom domain (tabela já existe)

## Sessão 6 — Parte 2 (2026-05-04 noite)

### Commits

| Commit | Feature |
|---|---|
| 5e533fad | fix(meu-setup): carregar business_type corretamente |
| 754e3546 | feat(master): descrições módulos + vencimento trials + info plano |
| 52bf5e03 | feat(master): toggle automações + copiar templates Shark Panel |
| 21f287ad | fix(master): toggle módulos permanentes salvando corretamente |
| + excluir | feat(master): excluir workspace com confirmação dupla |

### Fixes críticos
- Nicho não carregava ao abrir meu-setup (campo 'type' vs 'business_type')
- Toggle de módulos permanentes não salvava (feature inexistente no banco)
- Features desabilitadas por padrão quando workspace sem configuração
- /api/settings agora lê workspace_features e mapeia para modules

### Melhorias painel master
- Card "Plano & Vencimento" na Visão Geral (plano, vencimento, nicho, último acesso)
- Descrições de cada módulo em Conceder Trial e Módulos Permanentes
- Toggle ativo/inativo de automações direto do master
- Copiar templates do Shark Panel para workspace do cliente
- Botão excluir workspace com confirmação dupla (digitar nome)
- Proteção: Shark Panel e workspace teste não podem ser excluídos

### Arquitetura feature gating (corrigida)
- /api/settings lê workspace_features e mapeia:
  iptv → iptv_trials + iptv_apps
  campaigns → campaigns
  ai_responses → ai_agents
  checkout → billing
  funnels → guided_funnel
- use-modules: features === true (não !== false)
- Fallback: tudo false quando sem configuração

### Backlog sessão 7
- Editor visual de checkout com preview iframe
- Página de obrigado customizável
- Onboarding guiado (ÚLTIMO antes do beta)
- Reorganização Settings (Geral/Mensagens/Chat)
- Amplopay por workspace
- Custom domain
- Portal de suporte público
- Notificação trial vencendo
- Página de planos pública

## Sessão 6 — Parte 3 (2026-05-04 noite)

### Commits

| Commit | Feature |
|---|---|
| 2bfafff6 | fix(settings): module_trials no cálculo de modules |
| c98d8c20 | fix(sidebar): Automações não exige módulo campaigns |
| bc1a35b1 | fix(automations): esconder Gerar com IA sem feature ai_responses |
| a3d15d0f | feat(automations): CRUD de pastas de áudios dinâmicas |

### Fixes feature gating
- module_trials agora incluídos em /api/settings → trial de Funis libera Automações
- Automações no sidebar não exige mais module 'campaigns'
- Gerar com IA escondido sem feature ai_responses

### CRUD de pastas de áudios
- Tabela automation_folders criada
- API CRUD: GET/POST/PATCH/DELETE /api/automations/folders
- 90 pastas padrão semeadas (6 por workspace)
- UI: pastas dinâmicas + botão Nova pasta
- Hover: lápis e lixo por pasta
- Modal criar/editar com seletor de emoji
- Todos os selects de pasta usam dados do banco

### Backlog
- Mesmo CRUD de pastas para Mídias e Documentos
- Onboarding guiado (ÚLTIMO antes do beta)
- Editor visual de checkout
- Portal de suporte público
