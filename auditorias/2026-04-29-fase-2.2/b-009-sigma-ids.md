# B-009 — Anual e Semestral usam package de 3 meses

## Status
✅ IDs corretos identificados no catálogo Sigma. SQL de UPDATE pronto (não executado).

## Diagnóstico

### Estado atual em prod (workspace Uniflix `00000000-0000-0000-0000-000000000002`)

```text
   slug    |    name    |  sigma_package_id  | sigma_months | credits_cost
-----------+------------+--------------------+--------------+--------------
 monthly   | Mensal     | BV4D3rLaqZ         |    1         |    1   ✅
 quarterly | Trimestral | RYAWRk1jlx         |    3         |    3   ✅
 annual    | Anual      | RYAWRk1jlx         |    3         |    3   ❌
 semiannual| Semestral  | RYAWRk1jlx         |    3         |    3   ❌
```

`annual` e `semiannual` apontam pro mesmo pacote do `quarterly` (3 meses) — clientes que pagam anual/semestral recebem só 3 meses.

## Catálogo Sigma — pacotes "COMPLETO COM ADULTOS" (família atual da Uniflix)

Endpoint consultado: `https://sharks10.top/api/webhook/package?token=<TOKEN>&userId=BV4D3rLaqZ`

| Duração | ID | Preço (cents) | Créditos | Nome |
|---|---|---|---|---|
| 1 mês  | `BV4D3rLaqZ` | 2500  | 1  | 1 MÊS COMPLETO COM ADULTOS 🔞 (em uso ✅) |
| 2 meses| `Yen129WPEa` | 5000  | 2  | 2 MESES COMPLETO COM ADULTOS 🔞 |
| 3 meses| `RYAWRk1jlx` | 6000  | 3  | 3 MESES COMPLETO COM ADULTOS 🔞 (em uso ✅) |
| **6 meses** | **`VpKDaJWRAa`** | **12000** | **6** | **6 MESES COMPLETO COM ADULTOS 🔞** ⭐ |
| **1 ano**   | **`o231qzL4qz`** | **24000** | **12** | **1 ANO COMPLETO COM ADULTO 🔞** ⭐ |

(Existem variantes `SEM ADULTOS` e `UNITV`, mas o monthly/quarterly atuais usam a família "COMPLETO COM ADULTOS", então mantenho a coerência.)

### Variantes alternativas (caso queiras evitar adulto)
| Duração | Sem adultos | UNITV s/ adultos | UNITV c/ adultos |
|---|---|---|---|
| 6m  | `EMeWepDnN9` | `B0VDVALK3q` | `boQ1Ye1ONY` |
| 12m | `z2BDvoWrkj` | `bQELo0Dgro` | `Ar0WZg1a7z` |

## SQL de UPDATE (NÃO executar — aguardar aprovação)

```sql
-- Semestral: 6 meses
UPDATE special_iptv_plans
   SET sigma_package_id = 'VpKDaJWRAa',
       sigma_months     = 6,
       credits_cost     = 6,
       updated_at       = NOW()
 WHERE workspace_id = '00000000-0000-0000-0000-000000000002'
   AND slug = 'semiannual';

-- Anual: 12 meses
UPDATE special_iptv_plans
   SET sigma_package_id = 'o231qzL4qz',
       sigma_months     = 12,
       credits_cost     = 12,
       updated_at       = NOW()
 WHERE workspace_id = '00000000-0000-0000-0000-000000000002'
   AND slug = 'annual';
```

### ⚠️ Decisão pendente: `credits_cost`
Atualmente todos os 3 (`quarterly`/`semiannual`/`annual`) custam **3 créditos**, o que é incoerente. O preço Sigma sugere:
- 6m = 6 créditos (R$120 = 6 × R$20)
- 12m = 12 créditos (R$240 = 12 × R$20)

Se o **business model** do Vinicius for "1 crédito = 1 mês", então o UPDATE acima está correto.
Se for diferente (ex: descontos progressivos pra fidelizar plano longo), Vinicius deve ajustar `credits_cost` antes de rodar.

## SELECT de validação (rodar antes pra confirmar que vai bater 1 row cada)

```sql
SELECT slug, name, sigma_package_id, sigma_months, credits_cost
  FROM special_iptv_plans
 WHERE workspace_id = '00000000-0000-0000-0000-000000000002'
   AND slug IN ('semiannual','annual');
-- Esperado: 2 rows, ambas com sigma_package_id='RYAWRk1jlx' e sigma_months=3
```

## SELECT pós-UPDATE (rodar depois pra verificar)

```sql
SELECT slug, sigma_package_id, sigma_months, credits_cost, updated_at
  FROM special_iptv_plans
 WHERE workspace_id = '00000000-0000-0000-0000-000000000002'
   AND slug IN ('monthly','quarterly','semiannual','annual')
 ORDER BY sigma_months;
-- Esperado:
--  monthly    | BV4D3rLaqZ | 1  | 1
--  quarterly  | RYAWRk1jlx | 3  | 3
--  semiannual | VpKDaJWRAa | 6  | 6
--  annual     | o231qzL4qz | 12 | 12
```

## Risco
**Baixo.** Mudança 100% data-only, reversível com 2 UPDATEs voltando IDs antigos. Não afeta clientes já provisionados (apenas próximas ativações usarão pacote correto).

## Backfill de clientes que pagaram annual/semiannual e receberam só 3 meses?
**Provavelmente SIM** — clientes prejudicados merecem ajuste. Identificar:

```sql
-- Quantos clientes foram impactados
SELECT s.id, s.iptv_username, s.plan_name, s.iptv_expires_at, s.created_at
  FROM subscriptions s
 WHERE s.workspace_id = '00000000-0000-0000-0000-000000000002'
   AND s.source = 'amplopay'
   AND s.plan_name ILIKE ANY (ARRAY['%anual%','%semestral%','%annual%','%semiannual%'])
 ORDER BY s.created_at DESC;
```

Pra cada um, fazer renovação manual no Sigma usando o pacote correto (não dá pra fazer via SQL — exige chamada na API Sigma).

## Tempo estimado
- Aplicar 2 UPDATEs: 2min
- Validar com SELECT: 2min
- Identificar clientes afetados (se houver): 5min
- **Total fix: ~10min**
- Backfill manual de clientes (se aplicável): variável (5min/cliente)
