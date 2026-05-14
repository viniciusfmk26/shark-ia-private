# Módulo: Master Panel

## Responsabilidade
Painel administrativo global — gerencia workspaces, revendedores, planos, features e billing.

## Arquivos principais
```
app/api/master/workspaces/            → CRUD workspaces
app/api/master/resellers/             → gestão de revendedores
app/api/master/features/route.ts      → feature flags por workspace
app/api/master/financeiro/            → financeiro global
app/api/master/users/                 → usuários
app/api/master/plans/                 → planos SaaS
app/api/master/trials/                → trials de módulo
app/api/master/ai-agents/             → agentes globais
app/api/master/module-trials/         → trials de módulos
app/master-login/page.tsx             → login master separado
components/layout/master-sidebar.tsx  → sidebar master
components/master/                    → componentes master
lib/auth/superadmin.ts                → guard de superadmin
lib/auth/require-superadmin.ts
```

## Acesso
- URL: `/master-login`
- Role: `superadmin`
- Guard: `lib/auth/require-superadmin.ts`

## Feature flags (módulos)
Controlados em `master/features`. Flags importantes:
- `iptv` → módulo IPTV
- `billing` → cobrança
- `ai_responses` → IA automática
- `campaigns` → campanhas
- `sales_brain` → Sales Brain
- `knowledge` → base de conhecimento

## Multi-tenant
- Cada workspace tem seu `workspace_id` (UUID)
- Workspace do Shark Panel (smoke test): `00000000-0000-0000-0000-000000000002`
- Isolamento via RLS no Postgres + verificação em cada route handler
