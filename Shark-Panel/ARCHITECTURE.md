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
- ElevenLabsTab → nunca importado
- PlansModulesTab → nunca importado
- 15+ componentes de inbox sem uso
- flow-editor de automações sem uso

## Zona mista (problemas)
- /api/admin/* → terceira camada órfã
- /workspaces-map → no cliente mas é master
- /audit-log e /audit-logs → duplicado
- checkout-admin → no cliente mas nome sugere master
