# Zapflix-Tech — Sessão 2026-09-15 — Fix domínio Sigma (ativação automática)

## Contexto
- VPS: 69.62.91.79, EasyPanel + Docker Swarm
- Repo: Zapflix-Tech (wp_zapflix-web, checkout, lib/sigma)
- Dashboard/workspace de produção SAP: `UNIFLIX` (workspace `00000000-0000-0000-0000-000000000002`, workspace_id `0000...0002`)

## Problema
Ativação automática do Sigma **parou de funcionar** após migração de domínio:
- Painel antigo: `https://sharks10.top/api`
- Painel novo: `https://sharkstreaming.sigmab.pro/api` (painel consolidado UNIFLIX)

Pagamento confirmado via webhook AmploPay → provisionSigmaCustomer → renew/create → chamada a `sharks10.top` → **HTTP 403 Cloudflare** ("Website Access Blocked / Terms of Service violations"). Credencial não era ativada nem renovada; cliente recebia pagamento confirmado mas sem credencial reativa (ou trial expirou).

## Causa raiz
`sigma_servers.panel_url` no banco ainda guardava o domínio antigo (`sharks10.top`). Todo o fluxo Sigma monta a URL a partir desse campo:
- `lib/sigma/provision.ts:139` → `baseUrl(server)` = `panel_url` sem slash final
- `lib/sigma/integration.ts:93` → `integration/v1/*`
- `lib/sigma/provision.ts:278` → `webhook/customer/renew`

O painel migrou para `sharkstreaming.sigmab.pro` mas o banco não foi atualizado.

## Correção aplicada
```sql
UPDATE sigma_servers
SET panel_url = 'https://sharkstreaming.sigmab.pro/api', updated_at = NOW()
WHERE is_global = true AND is_active = true;
```
Container: `wp_zapflix-db` (dbid `ad55ec48aa73`).

**Observação:** a tabela `sigma_servers` NÃO tem coluna `updated_at` (só `panel_url`, `token`, `user_id`, `workspace_id`...). O UPDATE com `updated_at` falhou; reapliquei sem essa coluna.

## Validação (ponta-a-ponta, sem criar nada)
- `POST https://sharkstreaming.sigmab.pro/api/webhook/customer/renew?serverId=...`
  → **HTTP 400 `{"message":"This customer doesn't exists"}`** (token válido, painel responde; user inexistente = operação idempotente, nada foi criado).
- Controle negativo (pós-fix): `sharks10.top` → HTTP 403 Cloudflare (confirmado bloqueado).

## Estado final
- `sigma_servers` (global): `panel_url = https://sharkstreaming.sigmab.pro/api` — ativo.
- Próxima confirmação de pagamento via AmploPay → webhook → `baseUrl(...)/webhook/customer/*` no novo domínio → ativação automática volta a funcionar.
- Sem rebuild necessário: `panel_url` é lido por query a cada chamada.

## Arquivos reais
- `/root/Zapflix-Tech/checkout/server/amplopay-webhook.ts` (chama reactivate-trial)
- `/root/Zapflix-Tech/app/api/checkout/reactivate-trial/route.ts` (reativa trial)
- `/root/Zapflix-Tech/lib/sigma/provision.ts` / `integration.ts` (montam bases via `panel_url`)
