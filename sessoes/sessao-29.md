# Sessão 29 — Shark Panel (15/06/2026, continuação)

## Commits da sessão
- `c7cf991d` feat: editor visual checkout IPTV — API, dashboard, pixels, preview ao vivo
- `2ffb399c` fix: adicionar componente Collapsible shadcn/ui
- `5b47df0e` feat: WABA vinculado à empresa — migrations, página detalhe empresa, seletor instância
- `51deec0e` feat: redesign cards de renovação — valor em destaque, instância no botão, borda colorida por status

## O que foi implementado

### Editor Visual Checkout IPTV
- API GET/PUT em /api/checkout/iptv-config/route.ts
- Dashboard /checkout/iptv com 6 abas: Visual, Conteúdo, Depoimentos, Conversão, Páginas, Pixels
- Preview ao vivo com iframe mobile/desktop + postMessage debounce 300ms
- Pixels GA4 e TikTok no /comprar com eventos Purchase
- custom_head_html e custom_body_html via CustomHtml
- Link "Checkout IPTV" no menu lateral

### WABA vinculado à empresa
- Migration 141: company_id em whatsapp_instances
- Migration 142: waba_onboarding_id em whatsapp_templates
- Onboarding Julia Abreu: status=completed, todos steps=true, waba_id=2053050685571211
- Julia Abreu vinculada à empresa Marcia Maria Stahl
- Página detalhe empresa /admin/empresas/[id] com WABAs + instâncias
- API /api/admin/companies/[id] retorna company + wabas + instances
- Seletor de empresa no formulário de instância Cloud API

### Redesign cards de renovação
- Borda colorida por status (verde/laranja/roxo/vermelho)
- Valor do plano em destaque ao lado do nome
- Ciclo + vencimento + instância em linha de metadados
- Botão Cobrar mostra instância: "Cobrar · Denise"
- Barra de ações separada com border-top

## Pendências para Sessão 30
- Validar editor visual /checkout/iptv em produção
- Testar preview ao vivo do checkout
- Templates dentro de Empresas → WABA → Templates
- Conversions API Meta (depende do onboarding WABA)
- VPS restart (19 updates, 13 security)
- Cron heartbeat no banco
- Order bumps no checkout IPTV
- phone_number real da Julia Abreu (GET /v20.0/1147025105164350?fields=display_phone_number)

## Atualização final (16/06/2026)

### Commits adicionais
- `77e946cd` fix: formatar CNPJ no formato XX.XXX.XXX/XXXX-XX nas páginas públicas
- `581283c0` fix: passar GIT_SHA como build-arg para consistência do Service Worker
- `042095dd` fix: formatar número telefone/WhatsApp com +55 (DDD) na página de contato
- `05ae4df1` fix: forçar recompilação do chunk recurrence-panel
- `b1b33dfd` fix: Service Worker cache invalidation por deploy via git-sha
- `2755f362` fix: processar status failed Cloud API, corrigir statusOrder e guard 24h

### Bugs corrigidos
- PIX avulso/valor personalizado na página pública dava Unauthorized — removida restrição de sessão
- CNPJ formatado: 46544438000131 → 46.544.438/0001-31
- Telefone formatado: 5399180773 → +55 (53) 99180-773
- Service Worker não invalidava cache após deploy (GIT_SHA inconsistente entre env e arquivo)
- Webhook Cloud API descartava silenciosamente statuses[] (failed/delivered/read)
- Status 'failed' nunca era gravado no banco (statusOrder não incluía 'failed')
- Guard de janela 24h era pulado para envios automáticos com sent_by_user_id do sistema
- Chave Anthropic: use_shared_key=true impedia uso da chave configurada no banco
- PIX copia-e-cola com valor livre no checkout dialog enviava link em vez de PIX

### Bugs de usuário resolvidos
- Senha do painel: resetada via bcrypt no banco (nextauth_users)
- use_shared_key=false para workspace master (geração de conteúdo IA funcionando)

### Pendências Sessão 30
- Sistema de distribuição de conversas (botão "Estou disponível")
- Editor visual checkout IPTV — passos finais (order bumps, upsell)
- Templates dentro de Empresas → WABA → Templates
- VPS restart (19 updates, 13 security)
- Cron heartbeat no banco
- Redesign cards de renovação (visual antigo ainda aparece por SW cache)
- Página de detalhe da empresa com WABAs vinculados
