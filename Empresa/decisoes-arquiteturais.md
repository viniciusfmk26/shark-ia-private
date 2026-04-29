# Decisões Arquiteturais (ADRs)

> Registro de decisões importantes do produto com **contexto, opções consideradas, decisão e razão**.
> Inspirado em [Architecture Decision Records](https://adr.github.io/).
> Formato: `ADR-NNN — Título — Data — Status` (Aceita / Substituída / Rejeitada).

---

## ADR-001 — Seleção de instância WhatsApp na Fase 2.2

**Data:** 2026-04-29
**Status:** Aceita

### Contexto

F-001 Fase 2.2 (revendedor ativa cliente IPTV gastando crédito) precisa enviar credenciais por WhatsApp. O sistema já tem **5 padrões diferentes** de seleção de instância espalhados pelo código, sem documentação consolidada.

Auditoria 29/04/2026 mapeada em [[../Shark-Panel/whatsapp-instances]] revelou:
- `whatsapp_instances` tem 33 colunas, das quais só 3 (`is_payment_confirmation`, `payment_confirmation_enabled`, `is_confirmation_fallback`) participam de filtros runtime
- 4 colunas latentes (`is_backup`, `failover_priority`, `is_paused`, `instance_type`)
- Pattern A (webhook) e Pattern B (conversa) cobrem ~70% dos callers; Pattern E (12+ callers ad-hoc) é débito conhecido

### Opções consideradas

| # | Opção | Pró | Contra |
|---|---|---|---|
| 1 | Reuso `is_payment_confirmation` (Pattern A puro) | Zero schema | Semântica suja (flag é "confirmation" mas vai cobrir credenciais também) |
| 2 | Nova flag `is_credentials_delivery` | Semântica limpa | ALTER + duplicação na prática (Vinicius marcaria as duas) |
| 3 | UI: reseller escolhe instância | Self-service multi-tenant | Overkill pra hoje (1 reseller real) |
| 4 | Pattern B puro (lookup conversa) | Coerente com IPTV admin | Falha em cliente novo |
| 5 | **⭐ Híbrido B + A** | Cobre todos os casos · zero schema · alinha com convenções existentes | Lógica um pouco mais longa |

### Decisão

**Opção 5 — Híbrido B + A.**

A rota `clients/activate` resolve instância em 3 tiers:
1. **Pattern B** — Se cliente tem conversa no workspace (lookup por phone), usa `conversations.instance_id`
2. **Pattern A Tier 2** — Senão, instâncias com `is_payment_confirmation=true` connected
3. **Pattern A Tier 3** — Fallback genérico: qualquer `payment_confirmation_enabled=true` connected

### Razão

- **Cobre todos os casos de uso reais:** cliente já existente sai da instância da conversa (continuidade); cliente novo sai da instância "oficial"
- **Zero mudança de schema** — só precisa de 1 UPDATE marcando "Atendimentos Uniflix" com `is_payment_confirmation=true`
- **Alinha com padrões já testados:** rotas IPTV admin (`sigma-activate`, `extra-screen`) usam Pattern B; webhook AmploPay usa Pattern A — ambos consolidados há meses
- **Não introduz nova flag** que precisaria ser sincronizada manualmente em paralelo a `is_payment_confirmation`

### Implementação

1. ✅ DDL aplicada (BLOCO 3.0)
2. ✅ UPDATE `is_payment_confirmation=true` em "Atendimentos Uniflix" feito pré-E2E
3. ✅ `pickEvolutionInstance()` em `app/api/resellers/clients/activate/route.ts` implementado híbrido B+A (3 tiers)
4. ✅ E2E manual concluído 29/04/2026 — Fase 2.2 entregue

### Risco assumido

- Se "Atendimentos Uniflix" cair, sistema cai no Tier 3 (qualquer connected) → pode pegar instância pessoal aleatória. **Aceitável** dado contexto atual: reseller só ativa quando vê o saldo e a UX permite retry.
- Pattern E (callers órfãos) continua existindo. Refactor desses fica como D-WA-002 em [[débitos]].

---

## ADR-002 — Modelo reseller com servidor reserva (B-007)

**Data:** 2026-04-29
**Status:** Aceita

### Contexto

Auditoria do catálogo Sigma via API (`GET /webhook/package` em `sharks10.top/api`) revelou que o mapping atual de "Anual" no `sigma_plan_mapping` aponta pro `sigma_package_id = 'RYAWRk1jlx'`, que no Sigma é **3 MESES COMPLETO COM ADULTOS** — não 12 meses.

Inicialmente classificado como **bug crítico** (B-007), por afetar todos os clientes que compraram "Anual" no `/comprar?ref=X` desde a configuração do mapping.

### Esclarecimento do Vinicius (29/04/2026)

> "Não é bug, é estratégia."

Modelo de operação real:
- Cliente paga "Anual" (12 meses)
- Sistema ativa **3 meses no Sigma principal** (UNIFLIX em `sharks10.top`)
- Os **9 meses restantes** ficam em "reserva" — quando expira no principal, Vinicius migra manualmente o cliente pra um servidor reserva (cobre o restante do contrato)

### Opções consideradas

| # | Opção | Pró | Contra |
|---|---|---|---|
| 1 | Tratar como bug (corrigir Anual → ID de 12 meses) | Semântica direta | Quebra modelo de negócio em produção |
| 2 | **⭐ Documentar como estratégia, manter** | Preserva o que já funciona | Schema precisa expressar a diferença |
| 3 | Renomear "Anual" pra algo tipo "Anual Reserva" | Mais explícito | Mudaria UX externa do checkout (impacto cliente) |

### Decisão

**Opção 2 — Manter comportamento e formalizar no schema.**

Adicionado em `special_iptv_plans` (BLOCO 3.0):
- `client_months INTEGER NOT NULL` — tempo TOTAL de contrato com o cliente
- `sigma_months INTEGER NOT NULL` — tempo ATIVADO no Sigma principal (pode ser menor que client_months)
- `sigma_package_id TEXT NOT NULL` — ID do pacote Sigma específico
- `sigma_server_id uuid` — FK pro server (reserva pra futura distinção)

Configuração UNIFLIX:
| slug | client_months | sigma_months | sigma_package_id |
|---|---|---|---|
| monthly | 1 | 1 | BV4D3rLaqZ |
| quarterly | 3 | 3 | RYAWRk1jlx |
| **semiannual** | **6** | **3** | RYAWRk1jlx (reserva 3m) |
| **annual** | **12** | **3** | RYAWRk1jlx (reserva 9m) |

### Razão

- O modelo já está em produção e financeiramente saudável — Vinicius cobra o pacote completo, ativa parcial, gerencia reserva
- Mudar `sigma_package_id` pra apontar pra 12 meses **inverteria** o modelo: cliente teria 12 meses no principal e Vinicius perderia o controle de migração
- Semântica do schema agora reflete a realidade: `client_months ≥ sigma_months` e a UI `/reseller/clientes` expõe "Restam migrar: N meses" pra reseller saber o que tem em reserva

### Implementação

- ✅ Schema atualizado em BLOCO 3.0
- ✅ UI `/reseller/clientes` mostra "Restam migrar: N meses (reserva)" quando `client_months > sigma_months`
- ✅ Documentado em [[../Shark-Panel/feature-creditos-iptv]]
- B-007 reclassificado em [[../Shark-Panel/bugs]] como **NÃO É BUG**

### Risco assumido

- **Tracking manual de reserva**: hoje o reseller tem que lembrar (via UI) quando migrar. Não há automação que ative o restante automaticamente quando o Sigma principal expirar. Aceitável até feature de "auto-migração".
- **Servidor reserva não está modelado** explicitamente — é externo ao sistema. Pode virar feature futura (campo `reserve_server_id` em `special_iptv_plans` ou nova tabela).

---

## ADR-003 — `provisionSigmaByPackage` (não reusa fluxo legado)

**Data:** 2026-04-29
**Status:** Aceita

### Contexto

F-001 Fase 2.2 ativa cliente IPTV via créditos usando `special_iptv_plans`, que já carrega `sigma_package_id` e `sigma_server_id` direto. Já existia `provisionSigmaCustomer()` para o fluxo de checkout — mas ele faz lookup em `sigma_plan_mapping ↔ checkout_plans` para descobrir o package, o que não faz sentido no caso de créditos onde o package é dado pelo plano selecionado pelo reseller.

### Opções consideradas

| # | Opção | Pró | Contra |
|---|---|---|---|
| 1 | Adaptar `provisionSigmaCustomer` pra aceitar `(serverId, packageId)` opcional | Único caminho | Função fica multi-modal, condicionalmente pula lookup |
| 2 | Adicionar entrada fake em `sigma_plan_mapping` pra cada `special_iptv_plans` | Reusa lookup existente | Polui tabela legada com dados sintéticos |
| 3 | **⭐ Função nova `provisionSigmaByPackage`** | Separação clara entre fluxos | Risco de drift se um for atualizado e o outro não |

### Decisão

**Opção 3 — Função nova, dedicada.**

`provisionSigmaByPackage({ serverId, packageId, customerName, phoneDigits, workspaceId })` em `lib/sigma/provision.ts`:
- Pula lookup `sigma_plan_mapping`
- Reusa funções privadas (`findCustomer`, `createCustomer`, `renewCustomer`)
- Sintetiza um `SigmaMapping` pra preservar shape de `ProvisionResult`
- Reaproveita o mesmo `parseSigmaDate` pra normalizar `expiresAt`

### Razão

- **Separação clara** entre "fluxo checkout (planKey → mapping → package)" e "fluxo crédito (special_iptv_plans → package)"
- Manter `provisionSigmaCustomer` simples evita regressão nos clientes que pagam via PIX
- As duas funções convergem nas chamadas privadas internas (`createCustomer`, `renewCustomer`) — a chamada à API Sigma é idêntica

### Risco assumido

- **Drift**: se o protocolo do Sigma mudar (autenticação, parâmetros), as duas funções precisam ser atualizadas em sincronia. Mitigado pelas funções privadas internas comuns.
- **Duplicação aparente** — vale a pena revisar consolidação se Fase 3+ trouxer um terceiro fluxo de provisão.

---

## ADR-004 — INSERT subscription FATAL (fail-loud)

**Data:** 2026-04-29
**Status:** Aceita

### Contexto

No fluxo `clients/activate`:
1. Sigma cria/renova cliente (chamada externa irreversível — não dá pra rollback)
2. Sistema debita crédito + grava ledger (em transação atômica)
3. **DEPOIS** do COMMIT da tx, sistema faz INSERT em `subscriptions` (tracking local)

Se o passo 3 falha, Sigma já criou e crédito já foi debitado. Como reagir?

### Opções consideradas

| # | Opção | Pró | Contra |
|---|---|---|---|
| 1 | Log silencioso (`console.warn`) + retornar 200 com creds | Não polui UX do reseller | Admin não sabe que precisa backfillar; subscription "some" do painel |
| 2 | **⭐ HTTP 500 + creds no payload + audit log** | Admin sabe imediatamente; creds preservadas | UX de erro pra reseller (mas action concluiu) |
| 3 | Retentar INSERT em loop com backoff | Robustez | Adiciona complexidade; pode mascarar bug estrutural |

### Decisão

**Opção 2 — Fail-loud.**

Se INSERT em `subscriptions` falhar:
- Audit log `clients.activate.subscription_failed` contendo `username`, `password`, `expires_at`, `server_name`, `reseller_id`
- Resposta HTTP 500 com payload incluindo `sigma.{username,password,expires_at,server,isVip}` (creds preservadas pra reseller)
- Reseller vê toast vermelho com mensagem específica

### Razão

- **Visibilidade**: admin sabe que precisa intervir. O log silencioso engole a inconsistência por dias.
- **Não perde creds**: cliente ainda foi criado no Sigma, e as credenciais voltam pro reseller pra backfill manual
- **Estado parcial é tratado explicitamente**: subscription FATAL ≠ ROLLBACK do crédito (Sigma já cobrou; rollback seria tracking incoerente)

### Histórico que justifica

Antes desta decisão, o fluxo tinha `try { INSERT } catch { console.warn }`. Bug encontrado em 29/04 madrugada: `parseSigmaDate` ainda não existia, INSERT falhava com `invalid input syntax for type timestamptz: "30/05/2026 14:30:00"`, e `console.warn` ocultava o erro. Reseller via "ativação OK", mas `subscriptions` ficava sem registro. Fix em 2 etapas: (a) criar `parseSigmaDate`, (b) tornar INSERT FATAL pra próxima vez.

### Risco assumido

- **UX:** reseller pode ver erro 500 mesmo com Sigma OK e crédito debitado — confuso. Mitigação: mensagem de erro inclui aviso de "credenciais já criadas, contate suporte".
- **Recovery manual:** admin precisa SQL pra backfillar subscription quando isso acontecer. Procedimento documentado em RUNBOOK (a fazer).
