# Sessão 28 — Shark Panel
**Data:** 14/06/2026
**Commits:** c8bbdb3b → 53269022 (13 commits)
**Status:** Web + Worker em produção

## Commits da sessão
- `c8bbdb3b` fix: isentar jobs com trigger_id do throttle/janela 24h Cloud API
- `4285ad65` feat: campo editável throttle_limit na UI de compliance
- `f2e30948` fix: isentar scheduled_message_id do throttle/janela 24h Cloud API
- `38bf8d45` feat: origem nos eventos de compliance + painel breakdown por origem
- `8349b27c` feat: reenvio compliance via Cloud API (Meta Graph) ou Evolution por provider
- `2bea384a` fix: filtrar instâncias Cloud API do modal de reenvio compliance
- `af668579` feat: redesign compliance page com abas Proteções/Monitoramento
- `ef12dc2a` feat: card fallback Evolution com contadores, detalhes e seletor sempre visível
- `28c1c5d4` feat: enrollment funil por provider — cloud_api vs evolution
- `e3ab22e1` feat: UI submissão templates WhatsApp com status e seletor instância Cloud API
- `2ec3b91b` feat: API submissão de templates WhatsApp para Meta Graph API
- `7a1f4ed8` feat: gerador IA de templates WhatsApp com simulação Meta
- `53269022` feat: API gerador IA templates WhatsApp com simulação Meta (OpenAI)

## O que foi feito

### Compliance Meta
- Redesign completo: abas Proteções/Monitoramento
- Throttle: 20 → 5/hora por conversa
- Fallback automático ativado via Denise (Evolution)
- Reenvio inteligente: Cloud API → Graph API Meta, Evolution → Evolution API
- Origem gravada nos eventos (trigger/funnel/flow)
- Card fallback com contadores bloqueios/reenviados/perdidos
- Isenções throttle: trigger_id, scheduled_message_id

### Funis
- Cloud API: delays 30min/110min/1440min (respeita limites Meta)
- Evolution: funil separado com delays 5min/20min/110min
- Enrollment automático por provider da instância

### Templates WhatsApp
- Gerador IA (OpenAI gpt-4o-mini) com prompt em português
- Simulação Meta: score %, checklist 6 pontos, verdict aprovado/risco/rejeitado
- API submissão para Meta Graph API (/api/templates/whatsapp/submit)
- Seção "Meus Templates" com status e botão Submeter para Meta

### Ajustes banco
- Delays funil Cloud API: 30/110/1440min
- Throttle_limit: 5
- Fallback: habilitado → Denise
- 384 pagamentos checkout_pix com sold_by_user_id recuperados

## Pendências Sessão 29
- Completar onboarding WABA (vincular Julia Abreu à empresa)
- Templates dentro de Empresas → WABA → Templates
- Lógica "só avança funil se cliente respondeu"
- 1132 checkout_pix sem vendedor irrecuperáveis
- MinIO domínio customizado
- Campo head/body HTML nas páginas públicas /app/[slug]
- VPS restart pendente (security updates)
- IP Traefik muda se container reiniciar (atual: 10.11.0.169)
- Throttle revisar valor adequado (5 pode ser baixo demais)

## Atualização pós-Obsidian (parte 2)

### Commits adicionais
- `7967b6ab` feat: gate reply no funil — só avança Oferta+PIX e Urgência se cliente respondeu
- `1c5a2903` feat: campo head/body HTML nas páginas públicas /app/[slug] para Meta Pixel e verificação Facebook

### Itens resolvidos (pós-Obsidian)
- Throttle: 5 → 15/hora (Opção B — instância herda workspace)
- Duplicata compliance_settings removida (ficou 1 linha limpa)
- Funil gate reply: requires_reply=true nos stages Oferta+PIX e Urgência
- 39 checkout_pix marcados como organic_funnel
- MinIO: não necessário mudar (URL interna invisível ao usuário)
- head/body HTML: migration + CustomHtml client component + UI + API

### Pendências Sessão 29
- Onboarding WABA completo (Julia Abreu → Empresa Marcia Maria Stahl)
- Migration: company_id em whatsapp_instances
- UI instâncias: seletor empresa + auto-preenche WABA ID
- Templates dentro de Empresas → WABA → Templates
- Conversions API Meta (depende do onboarding WABA)
- VPS restart (19 updates, 13 security) — janela: 2h-4h BRT
- Funil paused_no_reply: cron para reativar quando cliente responder
- Lógica funil Evolution: verificar se gate reply deve aplicar também

## Atualização pós-Obsidian (parte 3 — 15/06/2026)

### Commits adicionais
- `61355360` feat: preview visual WhatsApp nos templates com edição inline
- `1c5a2903` feat: campo head/body HTML nas páginas públicas /app/[slug]
- `7967b6ab` feat: gate reply no funil
- `3474d2ae` feat: Worker popup dados reais compliance/funil
- `6257d6b6` feat: redesign Worker popup seções visuais
- `83d55df9` fix: Cloud API excluída do check-instance-health

### Bugs corrigidos
- Cron wp_zapflix-cron estava na imagem errada (zapflix-tech:latest em vez de easypanel/wp/zapflix-cron:latest) — renewal-check não rodava há dias
- 35 cobranças enviadas manualmente após correção
- Julia Abreu e Marlene Marafiga apareciam como Offline no front — corrigido no banco e no cron

### Pendências Sessão 29
- Onboarding WABA completo (Julia Abreu → Empresa Marcia Maria Stahl)
- Migration: company_id em whatsapp_instances
- UI instâncias: seletor empresa + auto-preenche WABA ID
- Templates dentro de Empresas → WABA → Templates
- Cron heartbeat no banco (mostrar último run de cada job no Worker popup)
- Renovações: mostrar instância que vai cobrar no card
- Funil paused_no_reply: cron para reativar quando cliente responder
- VPS restart (19 updates, 13 security) — janela: 2h-4h BRT
- Amanda Soares: status 'banned' — verificar

## Fix adicional (15/06/2026 tarde)
- Cloud API voltou a aparecer como Offline após cron rodar antes do deploy
- Corrigido no banco novamente + fix já deployado (83d55df9) garante que não volta

## Fix adicional (15/06/2026 tarde)
- Cloud API voltou a aparecer como Offline após cron rodar antes do deploy
- Corrigido no banco novamente + fix já deployado (83d55df9) garante que não volta

## Fix adicional (15/06/2026 tarde)
- Cloud API voltou a aparecer como Offline após cron rodar antes do deploy
- Corrigido no banco novamente + fix já deployado (83d55df9) garante que não volta
