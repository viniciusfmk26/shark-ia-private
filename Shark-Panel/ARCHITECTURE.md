# Arquitetura Shark Panel

## Painéis
- (master)/master/* → painel superadmin
- (dashboard)/* → painel cliente (60 páginas)

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
- /workspaces-map → no cliente mas é master
- /audit-log e /audit-logs → duplicado
- checkout-admin → no cliente mas nome sugere master
