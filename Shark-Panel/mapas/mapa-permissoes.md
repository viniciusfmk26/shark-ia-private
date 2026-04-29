# Mapa de Permissões — Shark Panel

> RBAC em duas camadas (global + por workspace) + módulos gated por plano + permissões granulares (`feature_access`).

---

## Camadas de auth/authz

### 1. Global (`nextauth_users.role`)
```
'user'        → padrão
'admin'       → não usado em prod (CHECK permite mas só superadmin existe)
'superadmin'  → bypass total. Acesso a /master/*, ignora workspace_memberships
```

### 2. Por workspace (`workspace_memberships.role`)
```
'owner'   → dono do tenant (3=mais alto em ROLE_HIERARCHY)
'admin'   → gestão sem destruir o workspace
'agent'   → atendente
'viewer'  → menor (raramente usado)
```

### 3. Plano (`workspace_plans.plan`)
```
'free'        → 1 instance, 500 msg/mês, 0 IA
'starter'     → 2 instance, 2k msg, 100 IA, sem IPTV/billing/automations
'pro'         → 5 instance, 10k msg, 1k IA, IPTV+billing+campaigns+automations+funnels+knowledge
'enterprise'  → ilimitado, todos os módulos incluindo gamification + resellers
```

Definição em `lib/auth/rbac.ts:11-86` (`PLAN_HIERARCHY` + `PLAN_DEFINITIONS`).

### 4. `feature_access` (granular per-workspace)
Tabela `feature_access(workspace_id, feature_key, enabled)`. Usada pelos `permissionKey` no sidebar.

---

## Helpers de auth (server-side)

### `lib/auth/superadmin.ts`

```ts
export const SUPERADMIN_ID = process.env.SUPERADMIN_ID || '00000000-0000-0000-0000-000000000001';

isSuperAdminId(userId)           // sync, só compara legacy id
isSuperAdmin()                   // async — checa session + nextauth_users.role
requireSuperAdmin()              // guard: { userId, error: NextResponse | null }
getSuperAdminContext()           // { userId, email, name, isSuperAdmin } pra audit
```

Estratégia: primeiro consulta `nextauth_users.role='superadmin'`; fallback para o UUID legado caso a coluna `role` não exista (defensivo). **Em prod a coluna existe** e tem 1 superadmin (Vinicius).

### `lib/auth/rbac.ts`

```ts
getUserRole(workspaceId, userId)                  → string | null  (workspace_memberships.role)
getWorkspacePlan(workspaceId)                     → PlanName       (default 'free')
planMeetsMinimum(current, required)               → boolean
isModuleEnabledForPlan(plan, moduleName)          → boolean
getAuthContext()                                  → { userId, workspaceId, role, plan } | null
                                                  → superadmin força role='owner', plan='enterprise'
requireRole(...allowedRoles)                      → guard
requireModule(ctx, moduleName)                    → 403 ou null
requirePlan(ctx, minPlan)                         → 403 ou null
```

### Outros (`lib/auth/`)

```
api-token.ts                — valida `x-api-key` em /api/external/* contra api_tokens
getActiveWorkspaceId.ts     — resolve workspace via cookie + memberships
getAllowedInstances.ts      — filtra instâncias por member_instance_permissions
getUser.ts                  — facade auth() + user details
require-superadmin.ts       — alias compat
requireAuth.ts              — guard simples (só auth)
reset-token.ts              — gera/valida password reset
resolveTeamAuth.ts          — para /api/team/[userId] (owner pode ver agentes)
superadmin-client.ts        — versão client (só legacy id, sem DB)
temp-password.ts            — gera senha temporária (cadastro reseller)
useSuperAdminGuard.ts       — hook React (deprecated em favor do server check)
```

### `auth.config.ts` + `auth.ts`

- `auth.config.ts` → leve, importável no Edge runtime (middleware)
- `auth.ts` → completo, com `pg` + `bcryptjs`, NÃO importar em middleware
- Provider: `Credentials` (email + bcrypt-compared password)
- Sessão: JWT (cookie HTTP-only)
- Callback `jwt({ token, user, trigger })` re-busca `name`, `nickname`, `phone_whatsapp`, `avatar_url` do banco em login e em `update`
- Bloqueia login se `nextauth_users.status IN ('pending', 'rejected')`

---

## Middleware (`middleware.ts`)

Wrapper `auth()` do NextAuth v5. Fluxo:

1. **Pathname excluído** → `next()` (sem checagem)
2. **Sessão NextAuth válida** (`request.auth.user.id` presente) → `next()`
3. **Basic Auth** (header `Authorization: Basic <base64>`, vars `BASIC_AUTH_USER`/`PASS`) → `next()`
4. **Falhou:**
   - rota `/api/*` → 401 JSON
   - rota página → redirect para `/login` (ou `/master-login` se host = `admin.sharkpanel.com.br`)

`EXCLUDED_PREFIXES` (29 entradas):
```
/api/webhook              /api/jobs/process         /api/cron/
/api/migrate/             /api/health               /api/version
/api/admin/run-migration  /api/admin/job-analysis   /api/admin/media-debug
/api/admin/requeue-dead-jobs  /api/admin/test-media-send  /api/admin/test-image-send
/api/admin/audit          /api/auth                 /api/automations/funis/enroll
/api/checkout/            /api/payments/webhook     /api/payments/amplopay-webhook
/api/external/            /api/internal/            /api/notifications
/api/rotation/            /api/webchat/             /api/trial/
/api/debug/               /api/resellers/lookup     /api/resellers/public-signup
/api/affiliates/public-signup
/login  /master-login  /esqueci-senha  /resetar-senha  /registro
/cadastro-revendedor  /afiliado/  /comprar  /r/  /pix/
/_next  /favicon  /icon  /apple-icon
```

Cada um destes deve ter sua própria auth interna (token de webhook, x-api-key, x-cron-secret, etc.) — **exceto `/api/debug/*`, `/api/migrate/*` e `/api/notifications`**, que são vulnerabilidades documentadas em SECURITY.md.

---

## Matriz Role × Ações (resumo)

|                                    | Public | Agent | Owner | Admin | Reseller | Superadmin |
|------------------------------------|:------:|:-----:|:-----:|:-----:|:--------:|:----------:|
| Login                              | ✅ (formulário) | — | — | — | — | — |
| Ver Dashboard `/`                  | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ver Inbox                          | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Listar contatos                    | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Editar contato                     | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Ver Tickets                        | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Criar Blacklist                    | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Listar instâncias WhatsApp         | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Conectar / parar instância         | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Vitrine / produtos / pedidos       | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Cobrança rápida / billing          | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Trials IPTV                        | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Planos IPTV                        | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Automações / Funis / Campanhas     | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Templates                          | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| IA & Agentes / Knowledge           | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Painel reseller (`/reseller`)      | ❌ | — | ✅ (se reseller) | ✅ (se reseller) | ✅ | ✅ |
| Comprar créditos                   | ❌ | — | ❌ | ❌ | ✅ | ❌ |
| **Ativar cliente IPTV**            | ❌ | — | ❌ | ❌ | ✅ | ❌ |
| Saque comissão                     | ❌ | — | ❌ | ❌ | ✅ | ❌ |
| Configurações `/settings`          | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Meu Plano (mudar plano)            | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Usuários & Permissões              | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| API Tokens / Webhooks              | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Audit Logs (workspace)             | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Painel Master (`/master/*`)        | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Master Workspaces / Pessoas / Financeiro | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Master Trials / Jobs / Blacklist global | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Mapa de Workspaces                 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Sigma admin (`/sigma`)             | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Checkout público (`/comprar`)      | ✅ | — | — | — | — | — |
| `/api/health`                      | ✅ | — | — | — | — | — |
| `/api/cron/*` (com x-cron-secret)  | ✅ via header | — | — | — | — | — |
| `/api/payments/amplopay-webhook`   | ✅ via token JSON | — | — | — | — | — |

> **"Reseller"** acima refere-se ao *user* que tem `resellers.user_id = nextauth_users.id` e `resellers.status='approved'`. A entrada na sidebar "Revendedor" aparece pra todos os logados, mas a página `/reseller/clientes` chama `POST /api/resellers/clients/activate` que faz lookup em `resellers WHERE user_id = $1 AND workspace_id = $2 AND status='approved' AND type IN ('reseller', 'affiliate')` — se não encontrar, 404.

---

## Como rotas protegem permissões (padrão típico)

### Rota workspace (autenticação + role)
```ts
import { auth } from '@/auth';
import { getWorkspaceIdSafe } from '@/lib/auth/getActiveWorkspaceId';
import { requireRole } from '@/lib/auth/rbac';

const session = await auth();
if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

const { ctx, error } = await requireRole('owner', 'admin');
if (error) return error;
// ctx.userId, ctx.workspaceId, ctx.role, ctx.plan
```

### Rota com módulo gated por plano
```ts
const { ctx, error } = await requireRole('owner', 'admin');
if (error) return error;

const moduleErr = requireModule(ctx, 'iptv_trials');
if (moduleErr) return moduleErr;
```

### Rota master
```ts
import { requireSuperAdmin } from '@/lib/auth/superadmin';

const { userId, error } = await requireSuperAdmin();
if (error) return error;
```

### Rota cron
```ts
const token = request.headers.get('x-cron-secret');
if (token !== process.env.CRON_TOKEN) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
}
```

### Multi-tenant query (regra de ouro)
```ts
// ✅ SEMPRE filtrar workspace_id
const { rows } = await query(
  'SELECT * FROM contacts WHERE workspace_id = $1 AND id = $2',
  [workspaceId, contactId]
);

// ❌ NUNCA confiar em RLS — role zapflix é BYPASSRLS
```
