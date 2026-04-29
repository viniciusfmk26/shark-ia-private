# Pipeline Sales-Brain — Fix 29/04/2026 (segunda parte do dia)

## Contexto
Após auditoria deep-dive da manhã, descobrimos que `lib/sales-brain/pipeline.ts`
existia há 5 semanas (criado 24/03/2026) com 5 funções pra atualizar
sales_opportunities, mas **nenhuma era chamada em produção**.

Resultado: 2.600 opportunities, 0 won/lost. Sales Brain mostrava conversion
rate 0% mesmo com clientes pagando.

## Fix aplicado (escopo mínimo)
✅ **onPaymentConfirmed** plugado no webhook AmploPay (commit `f48af9b8`)
✅ **logger.warn estruturado** (pino) substituiu console.error nas 5 funções
✅ **Backfill** 147 opportunities → 'won' (Opção C: payment_after_stage_change)

## Backfill — critério Opção C
```sql
WHERE so.stage NOT IN ('won', 'lost')
  AND EXISTS (
    SELECT 1 FROM payments p
    WHERE p.workspace_id = so.workspace_id
      AND (p.contact_id = so.contact_id OR p.contact_phone = so.contact_phone)
      AND p.status = 'confirmed'
      AND p.created_at >= so.stage_changed_at  -- KEY: pagamento DEPOIS da opp
  )
```

**Por que C e não A:**
- Opção A (UPDATE direto por phone) promoveria 367 opps
- 597 opps tinham phone duplicado entre opps abertas
- A causaria falsos won (opp antiga + cliente que voltou meses depois)
- C usa critério temporal: só promove se pagamento veio APÓS a opp ser aberta

## Resultado
| Stage      | Antes | Depois | Δ    |
|------------|-------|--------|------|
| lead       | 467   | 426    | -41  |
| qualified  | 642   | 622    | -20  |
| trial      | 1495  | 1409   | -86  |
| **won**    | **0** | **147**| +147 |

147 sales_events 'payment_received' criados com
`metadata.source='backfill_29_04'` (rastreável).

## Não incluído (deferido)
Ver `pipeline-pendentes.md` neste mesmo diretório:
- onTrialExpired (1.198 trials >30d candidatos)
- onTicketResolved (endpoints resolve conversation)
- onPaymentConfirmed em outros webhooks (manual, etc)
- onPlanExpired (cron plan-expiry)
- Auto-lost cron pra opps abandonadas (>90d)

## Como descoberto
Deep-dive sales-brain 29/04 (`auditorias/2026-04-29-multitenant-bugs/deep-sales-brain.md`).

## Commits relacionados
- f48af9b8 — Fix do código + backfill SQL

---

## Update 29/04/2026 (segunda parte da sessão)

Após shipping do `onPaymentConfirmed`, continuamos com `onTrialExpired`.

**Fix aplicado:**
- Plugado `onTrialExpired` no cron `promote-expired-trials` (commit `b2946863`)
- Mesma estrutura do AmploPay fix (resolve contactId, try/catch fail-safe)

**Backfill: 219 opportunities → 'lost'**

| Stage      | Antes | Depois | Δ    |
|------------|-------|--------|------|
| trial      | 1412  | 1193   | -219 |
| **lost**   | **0** | **219**| +219 |

### Bug arquitetural descoberto: phone format chaos
JOIN literal: 80 matches | JOIN normalizado: 218 matches
- `sales_opportunities.contact_phone`: 59% JID, 41% digits
- `iptv_trials.contact_phone`: 100% digits
- `payments.contact_phone`: 100% digits

Toda query JOIN/NOT EXISTS por contact_phone EXIGE `REGEXP_REPLACE` em ambos os lados.

### Estado final do pipeline (29/04/2026 fim do dia)
```
lead      |   430
lost      |   219   (NOVO via cron promote-expired-trials)
qualified |   625
trial     |  1193
won       |   147   (NOVO via webhook AmploPay)
```

### Commits relacionados
- `f48af9b8` — onPaymentConfirmed + backfill 147 won
- `b2946863` — onTrialExpired + backfill 219 lost
