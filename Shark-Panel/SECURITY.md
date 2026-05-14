# Módulo: Segurança / Auth

## Responsabilidade
Autenticação, autorização, RBAC, multi-tenant isolation, rate limiting.

## Arquivos principais
```
auth.ts                              → configuração NextAuth
auth.config.ts                       → providers e callbacks
middleware.ts                        → proteção de rotas
lib/auth/requireAuth.ts              → guard padrão de rotas API
lib/auth/rbac.ts                     → roles e permissões
lib/auth/getActiveWorkspaceId.ts     → workspace ativo da sessão
lib/auth/getAllowedInstances.ts      → instâncias permitidas
lib/auth/api-token.ts                → tokens de API
lib/server/rate-limit.ts             → rate limiting
lib/rateLimit.ts                     → utilitário de rate limit
```

## Roles
- `superadmin` → acesso master total
- `admin` → admin do workspace
- `agent` → atendente
- `reseller` → revendedor

## P0 Security (pendente)
- [ ] `/api/debug/*` endpoints sem autenticação
- [ ] `/api/notifications` sem autenticação
- [ ] Portas expostas desnecessariamente
- [ ] `Math.random()` em `lib/short-url.ts` (usar `crypto.randomBytes`)
- [ ] `CRON_SECRET` com fallback hardcoded

## Padrão de proteção de rotas API
```typescript
// Sempre no início de cada route handler:
const session = await requireAuth(req)
if (!session) return unauthorized()
const workspaceId = await getActiveWorkspaceId(session)
```
