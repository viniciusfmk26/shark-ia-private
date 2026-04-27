# Arquitetura Shark Panel

## Painéis
- (master)/master/* → painel superadmin
- (dashboard)/* → painel cliente (60 páginas)

## Hosts e telas de login
- `app.sharkpanel.com.br` → painel cliente, login em `/login`
- `admin.sharkpanel.com.br` → painel superadmin, login em `/master-login`
  - `/login` redireciona para `/master-login` (next.config.mjs)
  - `/` redireciona para `/master`
  - rotas não autenticadas → middleware envia para `/master-login` preservando o host (constrói URL via header `host` + `x-forwarded-proto`)
  - `/master-login` valida `isSuperAdmin` via `/api/me/permissions` após signIn; se não for superadmin, signOut + erro "Acesso negado"
  - Visual diferenciado: ícone 🔐, título "Shark Panel Admin", subtítulo "Acesso restrito ao administrador", sem link de cadastro (footer comum "© <ano> Shark Panel")
- `app.sharkpanel.com.br/master-login` → 307 para `/login` (não vaza login admin no domínio cliente)

## Site institucional (separado do painel)
- Serviço Docker Swarm: `wp_shark-landing`
- Imagem: `shark-landing:latest` (nginx:alpine + index.html estático)
- Código: `/root/shark-landing/` (HTML/CSS puro, sem dependências externas)
- Rede: `easypanel`
- Domínio futuro: `sharkpanel.com.br` (apontamento pendente)
- CTA principal: `https://app.sharkpanel.com.br`
- NÃO compartilha código nem build com `wp_zapflix-web` — totalmente isolado

## Banco de dados
- 191 tabelas total
- 159 workspace-scoped
- 11 globais legítimas
- ~21 junction/log tables (sem workspace_id por design)

## Tabelas globais principais
- app_meta → configurações globais (fonte de verdade)
- workspaces → tenants
- global_blacklist → blacklist cross-workspace
- nextauth_users/sessions → autenticação
- worker_heartbeats/runs → telemetria worker
- ai_writing_agents → agentes IA compartilhados

## Autenticação superadmin
- Guard frontend: (master)/layout.tsx (client-side)
- Guard API: lib/auth/require-superadmin.ts
- UUID hardcoded: 00000000-0000-0000-0000-000000000001
- Problema: 4 implementações diferentes

## Componentes órfãos
Limpeza realizada em 27/04/2026 — 8 componentes removidos (commit 3d970cbc):
- components/settings/tabs/elevenlabs-tab.tsx
- components/settings/tabs/plans-modules-tab.tsx
- components/shared/internal-chat.tsx
- components/shared/chat-view.tsx (apenas em barrel não usado)
- components/shared/ai-chat-assistant.tsx
- components/shared/data-table.tsx (apenas em barrel não usado)
- components/automations/tabs/followup-dashboard-tab.tsx
- components/dashboard/global-alerts.tsx

`components/shared/index.ts` atualizado para remover refs aos arquivos deletados.

Falsos positivos da auditoria anterior (estavam sendo usados):
- ai-mode-selector, ai-autonomous-banner, ai-copilot-panel, ai-suggestion-panel → todos importados em components/inbox/chat-view.tsx
- components/automations/flow-editor.tsx → usado em automations/tabs/fluxos-tab.tsx
- components/audit-logs/json-viewer.tsx → usado em audit-log-details-drawer.tsx

## Zona mista (problemas)
- /api/admin/* → terceira camada órfã
- /workspaces-map → no cliente mas é master (gated por `useSuperAdminGuard()` na page + `superAdminOnly: true` na sidebar — verificado 27/04/2026)
- /audit-log e /audit-logs → duplicado; em 27/04/2026 redirect invertido para `/audit-log → /audit-logs` em `next.config.mjs` (sidebar agora usa o plural — página mais completa: 20.873 bytes vs 12.026). Páginas mantidas para não quebrar links antigos.
- checkout-admin → no cliente mas nome sugere master

## Favicon
- Convenção `app/icon.tsx` + `app/apple-icon.tsx` renderizam 🦈 via `next/og` (PNG dinâmico).
- `app/layout.tsx` só define `metadata.icons` quando há whitelabel ativo; caso contrário o Next usa as rotas auto-geradas `/icon` e `/apple-icon`.
- `whitelabel-meta.tsx#resetFavicon` aponta para `/icon` (não mais `/icon.svg` legado do Next).
- `/icon` e `/apple-icon` estão em `EXCLUDED_PREFIXES` do `middleware.ts` (favicon precisa carregar mesmo sem sessão).
- Arquivos legados em `public/` (icon.svg, icon-*-32x32.png, apple-icon.png — todos com o "N" do Next) seguem no repo mas não são mais referenciados pelo HTML.
