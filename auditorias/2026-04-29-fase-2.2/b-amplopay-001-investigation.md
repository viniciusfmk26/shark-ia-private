# B-AMPLOPAY-001 — webhook não popula iptv_username/password em subscriptions

## Status
✅ Bug **localizado** e **fix proposto** (não aplicado).

## Diagnóstico

### Comportamento observado
Subscriptions com `source='amplopay'` ficam com `iptv_username=NULL` e `iptv_password=NULL` apesar do Sigma ter sido provisionado com sucesso (credenciais ficam apenas no JSONB de `payments.metadata` e `checkout_orders.metadata`).

### Causa raiz
O webhook AmploPay **chama `provisionSigmaCustomer` e captura `sigmaResult` corretamente**, mas o **INSERT/UPDATE em `subscriptions` ignora as credenciais** — só grava `plan_name`, `plan_price_cents`, `billing_cycle`, etc. As colunas `iptv_username`, `iptv_password`, `iptv_server`, `iptv_expires_at` ficam vazias.

### Localização exata

**Arquivo:** `app/api/payments/amplopay-webhook/route.ts`

**Linha 1141** — `sigmaResult` é obtido:
```ts
sigmaResult = await provisionSigmaCustomer({
  workspaceId,
  planKey: planKeyFromIdentifier,
  phone: normalizedPhone,
  customerName,
});
```

**Linhas 1151-1161** — credenciais são gravadas em metadata (não em colunas dedicadas):
```ts
const sigmaMeta = {
  sigma_username: sigmaResult.username,
  sigma_password: sigmaResult.password,
  sigma_expires_at: sigmaResult.expires_at,
  ...
};
```

**Linhas 1418-1442** — bloco "Sincronizar subscription". Aqui está o bug — INSERT/UPDATE NÃO incluem credenciais:

```ts
// UPDATE branch (linhas 1425-1431)
await query(
  `UPDATE subscriptions
   SET plan_name = $1, plan_price_cents = $2, billing_cycle = $3,
       next_billing_at = $4, updated_at = NOW()
   WHERE id = $5`,
  [planName, amountCents, cycle, nextBilling, subscriptionId]
);

// INSERT branch (linhas 1433-1440)
const { rows: newSub } = await query(
  `INSERT INTO subscriptions
    (workspace_id, contact_id, plan_name, plan_price_cents, billing_cycle,
     started_at, next_billing_at, source, status, payment_id)
   VALUES ($1, $2, $3, $4, $5, NOW(), $6, 'amplopay', 'active', $7)
   RETURNING id`,
  [workspaceId, subContactId, planName, amountCents, cycle, nextBilling, paymentId]
);
```

`sigmaResult` ESTÁ em escopo (declarado fora desse bloco) mas não é referenciado.

### Schema de `subscriptions` (em prod)
Colunas relevantes que existem mas estão sendo ignoradas:
- `iptv_username  text`
- `iptv_password  text`
- `iptv_server    text`
- `iptv_expires_at timestamptz`

(Confirmado via `\d subscriptions` em prod.)

### Comparação com fluxo que funciona
O endpoint `app/api/resellers/clients/activate/route.ts` (linhas 337-354) faz INSERT corretamente, populando todas as colunas IPTV. O webhook AmploPay precisa replicar esse padrão.

## Fix proposto (NÃO aplicar — aguardar aprovação)

### Patch para `app/api/payments/amplopay-webhook/route.ts` linhas 1418-1442

```ts
// UPDATE branch — incluir credenciais quando sigmaResult disponível
if (existing[0]) {
  subscriptionId = existing[0].id;
  if (sigmaResult) {
    await query(
      `UPDATE subscriptions
         SET plan_name = $1, plan_price_cents = $2, billing_cycle = $3,
             next_billing_at = $4,
             iptv_username = $5, iptv_password = $6,
             iptv_server = $7, iptv_expires_at = $8,
             updated_at = NOW()
       WHERE id = $9`,
      [
        planName, amountCents, cycle, nextBilling,
        sigmaResult.username, sigmaResult.password,
        sigmaResult.server.display_name ?? sigmaResult.server.name,
        sigmaResult.expires_at,
        subscriptionId,
      ],
    );
  } else {
    await query(
      `UPDATE subscriptions
         SET plan_name = $1, plan_price_cents = $2, billing_cycle = $3,
             next_billing_at = $4, updated_at = NOW()
       WHERE id = $5`,
      [planName, amountCents, cycle, nextBilling, subscriptionId],
    );
  }
} else {
  // INSERT branch — incluir credenciais
  const { rows: newSub } = await query(
    `INSERT INTO subscriptions
      (workspace_id, contact_id, plan_name, plan_price_cents, billing_cycle,
       started_at, next_billing_at, source, status, payment_id,
       iptv_username, iptv_password, iptv_server, iptv_expires_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), $6, 'amplopay', 'active', $7,
             $8, $9, $10, $11)
     RETURNING id`,
    [
      workspaceId, subContactId, planName, amountCents, cycle, nextBilling, paymentId,
      sigmaResult?.username ?? null,
      sigmaResult?.password ?? null,
      sigmaResult?.server?.display_name ?? sigmaResult?.server?.name ?? null,
      sigmaResult?.expires_at ?? null,
    ],
  );
  subscriptionId = newSub[0].id;
}
```

### Notas do fix
- `sigmaResult` é nullable (provisionamento pode falhar) — fallback pra null nos novos campos.
- No UPDATE, mantemos o caminho antigo se `sigmaResult` não tiver — evita sobrescrever creds existentes com NULL em re-entradas do webhook.
- `iptv_server` recebe `display_name` (mais legível) com fallback pra `name`.

## Backfill de dados antigos (opcional)

Se quiseres recuperar credenciais que ficaram só em `payments.metadata`:

```sql
UPDATE subscriptions s
SET iptv_username = (p.metadata->>'sigma_username'),
    iptv_password = (p.metadata->>'sigma_password'),
    iptv_expires_at = NULLIF(p.metadata->>'sigma_expires_at','')::timestamptz,
    iptv_server = COALESCE(
      p.metadata->>'sigma_server_display_name',
      p.metadata->>'sigma_server_name'
    )
FROM payments p
WHERE s.payment_id = p.id
  AND s.source = 'amplopay'
  AND s.iptv_username IS NULL
  AND p.metadata ? 'sigma_username';
```

(Rodar primeiro um SELECT equivalente pra contar quantas linhas serão atualizadas.)

## Risco do fix
**Médio.** Mudança em hot path do webhook. Recomenda-se:
1. Testar com pagamento real de teste (R$ pequeno) antes de fechar.
2. Verificar `subscriptions.iptv_username IS NOT NULL` após o pagamento.
3. Smoke test com webhook de re-tentativa pra garantir que UPDATE funciona.

## Tempo estimado
~30min implementação + ~15min teste manual = **~45min total**.
