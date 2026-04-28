# feature-afiliados.md — Sistema de Afiliados (F-001)

> Sistema de indicação onde qualquer pessoa pode se cadastrar como afiliado público, ser aprovado manualmente pelo Vinicius e ganhar comissão (30%) por cada venda gerada via seu `referral_code`.
>
> Relacionado: [[roadmap]] · [[bugs]] (B-001) · [[ARCHITECTURE]]
> Lançado em **28/04/2026** (Fase 1).

---

## Arquitetura

**Reuso máximo da tabela `resellers`** — afiliados são apenas linhas de `resellers` com `type='affiliate'`. Sem migração de schema, sem nova tabela.

```
resellers
├── type='reseller'  → revendedor IPTV (paga mensalidade R$197, comissão 50%)
├── type='atendente' → atendente interno (legado)
└── type='affiliate' → afiliado novo (NÃO paga, comissão 30%)
```

A coluna `type` já existia no schema (default `'reseller'`). Bastou começar a usar `'affiliate'`.

---

## Fluxo completo

1. **Lead acessa** `/afiliado/cadastro` (rota pública, fora do middleware de auth)
2. **Submete o form** (nome, email, WhatsApp) → POST `/api/affiliates/public-signup`
3. **API insere row** com:
   - `type='affiliate'`
   - `status='pending'` (aprovação manual)
   - `plan='affiliate'`, `plan_amount_cents=0` (não paga)
   - `commission_percent=30.00`
   - `referral_code` único (6 chars, alfanumérico legível)
   - `user_id=NULL`, `workspace_id=NULL`
4. **Vinicius é notificado** via WhatsApp na instância cubot (`SUPERADMIN_PHONE`)
5. **Lead vê** `/afiliado/cadastro/sucesso` com mensagem "aguarde 24h"
6. **Master abre** `/master/revendedores`, filtra por tipo "Afiliados", clica **Aprovar**
7. **API** `PATCH /api/admin/resellers/[id]` action='approve' (com B-001 fix):
   - Cria `nextauth_users` com senha temporária se `user_id IS NULL`
   - Marca `status='approved'`
   - **Pula workspace pra afiliado** (`type='affiliate'` não cria workspace nem subscription)
   - Manda WhatsApp pro afiliado com link `https://appcineflick.com.br/comprar?ref={CODE}` + credenciais (email/senha temp/link de troca)
   - Loga em `audit_logs`
8. **Afiliado divulga o link** — toda venda no checkout que vier com `?ref={CODE}` gera comissão automática via webhook PIX (lógica já existia para revendedores).

---

## Diferenças vs revendedor

| Campo | Revendedor | Afiliado |
|---|---|---|
| `type` | `'reseller'` | `'affiliate'` |
| `commission_percent` | 50% (Bronze) → 60% (Diamante) | 30% fixo |
| `plan_amount_cents` | 19700 (R$197/mês) | 0 |
| Cria workspace? | Sim | **Não** |
| Cron `reseller-billing` | Cobra mensalmente | Pulado via `WHERE type != 'affiliate'` |
| Onboarding | Form completo (cidade/estado/origem) | Form simples (nome/email/WhatsApp) |
| Cor visual | roxo | ciano #06b6d4 (Shark Panel) |

---

## Arquivos tocados (28/04/2026)

```
app/(public)/afiliado/cadastro/page.tsx        novo  — form público
app/(public)/afiliado/cadastro/sucesso/page.tsx novo — pós-cadastro
app/api/affiliates/public-signup/route.ts      novo — INSERT em resellers
app/(dashboard)/reseller/page.tsx              edit — header/pending por tipo
app/(master)/master/revendedores/page.tsx      edit — sub-tabs por tipo + TypeBadge ciano
app/api/cron/reseller-billing/route.ts         edit — AND r.type != 'affiliate'
middleware.ts                                  edit — EXCLUDED_PREFIXES
```

Commit fase 1: `38b6f587` em `viniciusfmk26/Zapflix-Tech`.

---

## UI

### Página pública `/afiliado/cadastro`
- Visual escuro com ciano (Shark Panel)
- Campos: nome, email, WhatsApp
- Aviso "Seu cadastro será analisado em até 24h"
- Botão "Quero ser afiliado"

### Master `/master/revendedores`
- Mantém abas existentes: Pendentes / Aprovados / Saques / Financeiro / Bloqueados / Rejeitados
- **Sub-tabs ortogonais por tipo:** Todos | Revendedores | Afiliados (com contadores)
- **`TypeBadge`:**
  - Afiliado → ciano
  - Revendedor → roxo
  - Atendente → azul

### Painel `/reseller` (acessado pelo afiliado aprovado)
- Header: "Painel de Afiliado" / "Acompanhe suas indicações"
- Tela de pending: "Aguardando aprovação 🦈 / Em breve você terá acesso ao link de afiliado"
- Resto do dashboard reusado (saldo, vendas, link de indicação, saque, etc.)

---

## Decisões importantes

### Por que aprovação manual?
Pra evitar spam/cadastros falsos no início. Auto-aprovação fica como Fase 4 (toggle no master).

### Por que reusar `resellers` e não criar `affiliates`?
- Toda lógica de comissão, saldo, saques, sales tracking já existe em `reseller_sales`/`reseller_commissions`/`reseller_withdrawals`
- Webhook PIX já incrementa saldo via `reseller_id`
- Painel `/reseller` já tem todos os componentes (level, gráfico, link copy, etc.)
- Risco de divergência de dados entre duas tabelas

Trade-off aceito: o código fica com nomes "reseller" mas representa ambos os papéis.

### Por que `commission_percent=30` fixo?
Decisão de produto pra Fase 1. Diferente do revendedor que tem progressão (Bronze 40% → Diamante 60%). Em Fase 2 podemos rever se compensar gamificar.

### Por que cron pula via `type != 'affiliate'` (e não via `plan_amount_cents > 0`)?
Explícito > implícito. Se um afiliado um dia tiver `plan_amount_cents > 0` (algum plano pago futuro), o filtro por type continua correto.

### Por que afiliado NÃO cria workspace?
Afiliado opera só via link e comissão — não acessa funcionalidades de workspace (instâncias WhatsApp, automações, contatos, etc). Criar workspace gera ruído (linhas em workspaces, memberships, subscriptions sem uso). Ver B-001.

---

## Próximas fases

- **Fase 2:** Crédito avulso — afiliado pode "alugar" 1 crédito = 1 cliente/mês de instância. Permite afiliado virar mini-revendedor sem mensalidade fixa.
- **Fase 3:** Notificação WhatsApp ao aprovar — já existe via reuso do approve do revendedor (manda link + código + credenciais com B-001 fix).
- **Fase 4:** Auto-aprovação opcional — toggle global no master pra aprovar todos automaticamente.
