# Sistema de Instâncias WhatsApp — Arquitetura de Seleção

> Como o sistema escolhe **qual instância WhatsApp envia** mensagens em cada cenário.
> Documento arquitetural — para o snapshot operacional do estado das instâncias, ver [[instancias]].
> Auditado em 29/04/2026.

---

## Visão geral

29 callers no codebase invocam `POST /message/sendText` da Evolution API. **Não há helper centralizado** de seleção de instância — cada caller implementa sua estratégia, e existem 5 padrões distintos consolidados.

Este doc mapeia esses 5 padrões + decide qual usar em cada categoria de mensagem.

---

## Schema relevante de `whatsapp_instances`

| Coluna | Tipo | Default | Uso runtime |
|---|---|---|---|
| `id` | uuid PK | gen | FK em `conversations.instance_id` |
| `workspace_id` | uuid FK | — | filtro principal de tenant |
| `name` | text NOT NULL | — | display + path Evolution |
| `evolution_instance_id` | text NOT NULL | — | preferido sobre `name` no path |
| `phone_number` | text | — | número conectado |
| `status` | text | `disconnected` | CHECK in (`connected`, `disconnected`, `connecting`) — filtro hard |
| `is_payment_confirmation` | bool | `false` | **só webhook usa**: instância dedicada a confirmações |
| `payment_confirmation_enabled` | bool **NOT NULL** | `true` | "instância pode mandar confirmação?" |
| `is_confirmation_fallback` | bool | `false` | sub-prioridade em casos de múltiplas dedicadas |
| `instance_type` | text | `atendimento` | informativo, **nenhum caller filtra** |
| `is_backup`, `failover_priority` | bool/int | `false`/`0` | indexados, **latentes** |
| `is_paused` | bool NOT NULL | `false` | indexado, **não usado em filtro** |
| `daily_limit`, `hourly_limit`, `anti_ban_enabled`, `warmup_day` | — | — | anti-ban (não decide seleção) |
| `banned_at`, `ban_count`, `ban_expires_at` | — | — | banimento (latente como filtro) |

**Não existem** `is_recovery`, `is_default`, `is_credentials`. Só `is_payment_confirmation` cumpre papel de "instância oficial" hoje.

**Conexão com conversas**: `conversations.instance_id` FK → `whatsapp_instances.id`. **`contacts` NÃO tem `instance_id`** — a "instância de uma conversa" é por linha em `conversations`, não por contato.

---

## Os 5 patterns de seleção

### Pattern A — Confirmação de pedido (3-tier fallback)

**Caller principal:** `app/api/payments/amplopay-webhook/route.ts` (linhas 252-310).

**Estratégia em 3 tiers:**

```sql
-- Tier 1: instância preferida do identifier do PIX
WHERE workspace_id=$1 AND (evolution_instance_id=$2 OR name=$2)
-- Guards: payment_confirmation_enabled=true E status='connected'

-- Tier 2: dedicadas
WHERE workspace_id=$1 AND status='connected'
  AND payment_confirmation_enabled=true
  AND is_payment_confirmation=true
ORDER BY is_confirmation_fallback DESC NULLS LAST, created_at ASC

-- Tier 3: qualquer enabled connected
WHERE workspace_id=$1 AND status='connected'
  AND payment_confirmation_enabled=true
ORDER BY is_confirmation_fallback DESC NULLS LAST, created_at ASC
```

**Tem fallback chain** se Evolution responde 404 (instância dessincronizada).

### Pattern B — Conversa em andamento

**Callers:** `iptv/sigma-activate`, `iptv/extra-screen`, `iptv/generate-and-send`, `iptv/trial/web`, `inbox/conversations/.../send-product`, `groups/[id]/send`.

**Estratégia:**
```sql
-- 1. Pega instance_id da conversa em sessão
SELECT instance_id FROM conversations WHERE id = $1

-- 2. Resolve o nome
SELECT name, evolution_instance_id FROM whatsapp_instances
  WHERE id = $1 AND workspace_id = $2
```

**Sem fallback.** Se não tem conversa, não envia.

### Pattern C — Sistema-wide (auth)

**Caller:** `auth/forgot-password`.

**Estratégia (preferência por affinity):**
```sql
SELECT name FROM whatsapp_instances
WHERE status='connected' AND evolution_instance_id IS NOT NULL
  AND evolution_instance_id <> 'webchat-virtual'
ORDER BY
  CASE WHEN workspace_id = $superadmin THEN 0
       WHEN workspace_id IN (workspaces do user) THEN 1
       ELSE 2 END,
  created_at ASC
LIMIT 1
```

### Pattern D — `instance_id` explícito

**Callers:** `instances/[id]/test-send`, `cron/abandoned-cart`, `cron/renewal-check`, `cron/check-instance-health`.

**Estratégia:** O ID vem como parâmetro do caller (config persistida ou cron com instância vinculada). Sem decisão de seleção.

### Pattern E — Sem padrão consolidado

**Callers:** `resellers/withdraw`, `resellers/public-signup`, `affiliates/public-signup`, `pedidos/.../recibo`, `master/workspace/[id]/action`, `cron/weekly-report`, `cron/check-worker-alerts`, `cron/reseller-billing`, `cron/reseller-levels`, `admin/resellers/[id]`, `payments/send-receipt`, `renewal/send-now`.

**Estratégia:** variada — cada um faz o seu (reuso parcial de A/B/C ou hardcoded). **Débito técnico D-WA-002.**

---

## Lógica "instância da conversa"

- **Onde está armazenada:** `conversations.instance_id` (FK → `whatsapp_instances.id`)
- **Quando é setada:** quando o webhook Evolution recebe a primeira mensagem do contato — a conversa é criada com a instância que recebeu
- **Como mudar:** via `inbox/conversations/[id]/transfer-instance/route.ts` (UI tem botão de transferir)
- **Não há config "instância padrão por contato"** — é por conversa. Se o contato tem múltiplas conversas, cada uma tem sua instância.

---

## 11 categorias de mensagem identificadas

| # | Categoria | Caller principal | Pattern |
|---|---|---|---|
| 1 | Confirmação de pedido pago | amplopay-webhook | A |
| 2 | Credenciais IPTV (admin em conversa) | sigma-activate | B |
| 3 | Tela extra IPTV | extra-screen | B |
| 4 | Trial IPTV (compartilhar acesso) | generate-and-send | B |
| 5 | Reset de senha | forgot-password | C |
| 6 | Cobrança de revendedor | cron/reseller-billing | D |
| 7 | Aviso de renovação | cron/renewal-check | D |
| 8 | Disparos em massa | cron/process-bulk-send | D |
| 9 | Carrinho abandonado | cron/abandoned-cart | D |
| 10 | Recibo manual | payments/send-receipt | E |
| 11 | **Ativação por reseller via crédito (Fase 2.2)** | clients/activate | **híbrido B+A** (ver ADR-001) |

---

## Configurações disponíveis vs latentes

### Em uso runtime
- `whatsapp_instances.is_payment_confirmation` — usado APENAS pelo webhook
- `whatsapp_instances.payment_confirmation_enabled` — usado APENAS pelo webhook
- `whatsapp_instances.is_confirmation_fallback` — sub-prioridade, só webhook
- `conversations.instance_id` — usado por todos os Pattern B
- `workspaces.settings.sigma_message` — template custom de credenciais (override do default)

### Latentes no schema
- `whatsapp_instances.is_backup` — indexado mas nenhum caller filtra (D-WA-001)
- `whatsapp_instances.failover_priority` — idem
- `whatsapp_instances.is_paused` — idem
- `whatsapp_instances.instance_type` — informativo, nenhum filtro
- `whatsapp_instances.banned_at`, `ban_count`, `ban_expires_at` — banimento sem filtro runtime

### Configurações ausentes (poderia existir)
- `is_recovery` — mencionado no plano mas não está no schema
- `is_default` — não existe
- `is_credentials_delivery` — proposto mas rejeitado em ADR-001 (Opção 2)

---

## Estado atual UNIFLIX (snapshot 29/04/2026)

| name | status | `is_payment_confirmation` |
|---|---|---|
| Iphone | connected | f |
| Projeto Salmos | connected | f |
| Gabriele Garcia | connected | f |
| Denise | connected | f |
| Atendimentos Uniflix | connected | f |
| Amanda Soares | connected | f |
| Viniciusa30 | disconnected | f |
| Uniflix Web | disconnected | f |
| **Bruninhahh** | **disconnected** | **t** |
| Juliana Lima | disconnected | f |

→ Única instância marcada `is_payment_confirmation=true` está desconectada (D-WA-003). Webhook hoje cai pro Tier 3 (qualquer connected) → pega "Iphone" (created_at mais antigo entre conectadas).

---

## Decisão arquitetural Fase 2.2

**Adotada Opção 5 (híbrido B + A)** — ver [[../Empresa/decisoes-arquiteturais]] ADR-001.

Implementação: a rota `POST /api/resellers/clients/activate` resolve a instância com:

1. **Tier 1 (Pattern B):** `SELECT instance_id FROM conversations WHERE workspace_id=$1 AND <phone-match>` — se cliente já tem conversa, usa essa instância
2. **Tier 2 (Pattern A subset):** SELECT `whatsapp_instances` filtrando `is_payment_confirmation=true` em `connected`, prioridade `is_confirmation_fallback DESC`
3. **Tier 3 (Pattern A subset):** qualquer `payment_confirmation_enabled=true AND status='connected'`, ordenado por `created_at ASC`

**Pré-requisito de prod:**
```sql
UPDATE whatsapp_instances 
SET is_payment_confirmation = true 
WHERE workspace_id = '00000000-0000-0000-0000-000000000002' 
  AND name = 'Atendimentos Uniflix';
```

---

## Débitos identificados nesta auditoria

- **B-008** — `buildSigmaMessage` duplicado (inline em `amplopay-webhook` + `lib/sigma/build-message.ts` criado em Fase 2.2). Migrar webhook pra usar o helper. Ver [[bugs]].
- **D-WA-001** — 4 colunas latentes (`is_backup`, `failover_priority`, `is_paused`, `instance_type`). Decidir se removemos ou começamos a usar.
- **D-WA-002** — Pattern E não consolidado: 12+ callers com estratégias variadas. Refactor pra usar helpers padronizados.
- **D-WA-003** — `Bruninhahh` órfã: marcada `is_payment_confirmation=true` mas desconectada há tempo. Decidir: desmarcar ou reconectar.

Todos em [[../Empresa/débitos]].
