# Sistema de Créditos IPTV (F-001 Fase 2)

Permite afiliados/revendedores comprarem pacotes de crédito via PIX e usarem pra ativar clientes IPTV.

**Status:** ✅ E2E validado em produção (28/04/2026) — Vinicius pagou R$ 5 PIX real, saldo 0 → 1.

## Schema

### Tabelas novas
- `special_iptv_plans` — mapa configurável (slug, name, months_sigma, credits_cost, display_order, is_active)
  - Seed inicial: monthly (1 mês = 1 cred), quarterly (3 = 3), annual (12 = 12)
- `reseller_credit_ledger` — ledger imutável de transações
  - `kind`: `'purchase' | 'usage' | 'admin' | 'refund'`
  - `amount`: positivo (entrada) ou negativo (saída)
  - `balance_after`: snapshot do saldo após a operação
  - `pix_identifier UNIQUE`: idempotência do webhook
  - `cents_paid`, `iptv_customer_id`, `special_plan_id`, `months_sigma_activated`, `description`, `performed_by`

### Colunas novas em `resellers`
- `iptv_credits INTEGER NOT NULL DEFAULT 0`
- `payout_mode TEXT NOT NULL DEFAULT 'commission' CHECK (payout_mode IN ('commission', 'credit'))`
- Index parcial: `idx_resellers_payout_mode_credit` (otimiza webhook em modo credit)

## Pacotes (`lib/credits/packages.ts`)
| Quantidade | Preço | Desconto |
|---|---|---|
| 1 crédito | R$ 5,00 | — |
| 10 créditos | R$ 47,50 | -5% |
| 50 créditos | R$ 225,00 | -10% |
| 100 créditos | R$ 425,00 | -15% |

## Fluxo end-to-end

1. Reseller abre modal "Comprar créditos" em `/reseller` (card) ou `/reseller/creditos` (página dedicada)
2. Escolhe pacote → `POST /api/resellers/credits/purchase`
3. Backend valida pacote (`isValidQty`), busca reseller approved, gera `pix_identifier` único:
   `sharkpanel-resellercredits-{full-uuid}-{qty}-{ts-ms}`
4. AmploPay chamada (URL nova): `POST https://app.amplopay.com/api/v1/gateway/pix/receive`
5. Frontend exibe QR + copy-paste no Dialog
6. Cliente paga PIX
7. AmploPay envia webhook `TRANSACTION_PAID` → handler `'sharkpanel-resellercredits-'` no `amplopay-webhook/route.ts`
8. `addCredits()` insere no ledger com `kind='purchase'` + UPDATE saldo (em `tx` com `SELECT FOR UPDATE`)
9. Frontend faz polling `/api/resellers/credits/balance` a cada 5s e detecta `balance > pixInitialBalance` → toast 🎉 + fecha modal

## Helpers (`lib/credits/ledger.ts`)
- `addCredits({resellerId, amount, kind, centsPaid?, pixIdentifier?, description?, performedBy?})`
- `useCredits({resellerId, amount, iptvCustomerId?, specialPlanId?, monthsSigmaActivated?, description?, performedBy?})`
- `getCreditsBalance(resellerId)` — leitura simples
- `getCreditsLedger(resellerId, limit=50)` — histórico raw

Todas as mutações usam `tx()` + `SELECT FOR UPDATE` pra evitar race. Idempotência via `pix_identifier UNIQUE` no banco — segundo webhook do mesmo PIX vira erro `23505` que o handler trata como `{ ok: true, idempotent: true }`.

## API endpoints
| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/resellers/credits/purchase` | Gera PIX |
| GET | `/api/resellers/credits/balance` | Saldo atual + 5 últimas |
| GET | `/api/resellers/credits/ledger?limit=50` | Histórico paginado |

Todas exigem auth + reseller/affiliate `status='approved'` no workspace ativo.

## Webhook handler

`app/api/payments/amplopay-webhook/route.ts` linhas ~924-991. Detecta identifier por prefixo `sharkpanel-resellercredits-` e regex full-UUID. Validações silenciosas (200 com `ignored:'...'`) pra:
- Identifier malformado
- qty fora dos pacotes (anti-tampering)
- Reseller deletado/inexistente

Audit logs:
- `credits.purchase.requested` (na rota de gerar PIX)
- `credits.purchase.confirmed` (no webhook ao creditar)
- `credits.purchase.failed` (no webhook se erro genérico)

## UI

### Página dedicada `/reseller/creditos`
- Server Component faz auth + lookup + fetch inicial (saldo + 50 ledger rows com JOIN special_iptv_plans)
- Client Component (`CreditsClient.tsx`) renderiza saldo grande, grid 4 pacotes, tabela histórico, modal QR
- Sidebar tem entry "Créditos" no grupo "Revendedor"

### Card no dashboard `/reseller`
- `CreditsCard.tsx` — fetch on-mount via `/api/resellers/credits/balance`
- Auto-hide quando API retorna 404 (não-reseller)
- Saldo + 5 últimas transações + botão "Comprar"
- Modal compacto com state machine `'select' | 'pix'`
- Detecta pagamento via comparação `newBalance > pixInitialBalance` → fecha após 2s

## Próximas fases
- **Fase 2.2** — ativação manual em `/reseller/clientes` (gastar crédito pra ativar IPTV via Sigma)
- **Fase 3** — webhook condicional: link do afiliado em modo `credit` desconta crédito automático
- **Fase 4** — UI master pra ajustar/ver saldos arbitrários

## Validação E2E (28/04/2026)

| Hora UTC | Evento |
|---|---|
| 00:51:33 | `credits.purchase.requested` audit + AmploPay charge `cmojcakz5...` |
| 00:51:34 | Webhook `TRANSACTION_CREATED` |
| 00:53:02 | Webhook `TRANSACTION_PAID` (~89s depois do PIX gerado) |
| 00:53:02 | INSERT no ledger + balance 0 → 1 |
| 00:53:02 | `credits.purchase.confirmed` audit |

Sistema funcionou ponta a ponta no primeiro teste real.

## Bugs encontrados durante o lançamento

- **AmploPay URL legada** — `api.amplopay.com/gateway/pix/receive` retorna 404 (caiu sem aviso). URL nova é `app.amplopay.com/api/v1/gateway/pix/receive` com auth via `x-public-key` + `x-secret-key`. Corrigido em commits `dae155a2` + `f26d383e`. Outras 3 rotas legadas ainda usam URL antiga — ver B-006 em [[bugs]].
- **Phone obrigatório no AmploPay** — campo `client.phone` exigido como string sempre; resellers podem ter `phone_whatsapp` vazio. Corrigido com fallback `generatePhone()` (`f26d383e`).
- **Modal não fechava após pagamento** — auto-refresh atualizava saldo mas não detectava confirmação. Corrigido com snapshot `pixInitialBalance` + comparação no polling (`914f8a51`).

## Commits
- `78eebc96` — feat: implementação inicial (schema + helpers + API + UI)
- `dae155a2` — fix: URL AmploPay nova + toasts informativos
- `f26d383e` — fix: phone sempre como string
- `914f8a51` — fix: detectar pagamento e fechar modal automaticamente
