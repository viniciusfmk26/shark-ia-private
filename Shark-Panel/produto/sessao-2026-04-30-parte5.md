# Sessão Técnica — 2026-04-30 (Parte 5)

## Resumo
Self-service de revendedor, feature gating completo, correções de middleware e bugs menores.

---

## 1. Self-service de Revendedor — commit `7c34a52a`

**Problema:** `/registro-revendedor` criava usuário `pending` sem workspace, vinculado à tabela `resellers` (legado).

**Novo fluxo:**
- Campos: nome, nome da empresa, email, senha
- Transação atômica cria: `nextauth_users` (approved), `workspaces`, `workspace_memberships` (owner), `workspace_plans` (trial 7 dias), `workspace_settings`
- Usuário já pode logar na hora, sem aprovação manual
- `/registro` (agentes) intocado

---

## 2. Fix Middleware — commit `e19af7c8`

`/registro-revendedor` e `/api/resellers/register` adicionados ao `EXCLUDED_PREFIXES` do middleware (estavam bloqueados por auth).

---

## 3. Fix Botão Login — commit `af92014f`

`<Link>` do Next.js substituído por `<a>` em `/registro-revendedor` — navegação HTTP completa resolve o redirecionamento.

---

## 4. Sistema de Feature Gating — commit `9b5f31fa`

**Banco:**
- Nova tabela `workspace_features` (workspace_id, feature_key, enabled)
- 42 linhas seedadas para 6 workspaces baseado no plano atual
- Separada de `feature_access` (que é per-user)

**Backend:**
- `lib/server/features.ts` — getWorkspaceFeatures, checkFeature, setWorkspaceFeature, DEFAULT_FEATURES_BY_PLAN
- `GET /api/workspace/features` — features da workspace ativa, cache 60s
- `GET|PATCH /api/master/features` — superadmin only com auditoria

**Frontend:**
- `hooks/use-features.ts` — SWR + hasFeature(key), safe default false durante loading
- Sidebar: IPTV, IA, Funis, Campanhas, Webchat somem quando desabilitados
- `/master/configuracoes` → nova seção com toggles workspace×feature

**Por plano:**
| Plano | Features |
|---|---|
| trial/free | inbox, instances |
| pro | + iptv, ai_responses, funnels, campaigns, webchat |
| enterprise | tudo |

---

## 5. Limpeza — Yann Ferreira

Usuário de teste `yannferreira234@gmail.com` deletado em cascata (memberships, workspace_features, workspace_plans, workspaces, nextauth_users).

---

## Pendências abertas

1. **Trial enforcement** — `plan_expires_at` gravado mas nunca enforced. Workspace expirada permanece 100% funcional.
2. **Tabelas duplicadas** — 3 de payment + 2 de subscription a consolidar.

---

## Commits desta sessão (parte 5)

| Hash | Descrição |
|---|---|
| `7c34a52a` | feat(registro): self-service de revendedor — workspace criada automaticamente |
| `e19af7c8` | fix(auth): liberar /registro-revendedor e /api/resellers/register do middleware |
| `9b5f31fa` | feat(features): sistema completo de feature gating por workspace |
| `af92014f` | fix(registro): corrigir botão ir para login |
