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
