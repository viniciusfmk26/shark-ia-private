# bugs.md — Bugs e Problemas Conhecidos

> Registro de bugs conhecidos que ainda não foram corrigidos.
> Problemas de **segurança** estão em [[SECURITY]]. Plano de correção em [[FIXES]].
> Atualizado em 29/04/2026.

---

## Como usar este arquivo

- Registrar bugs que foram identificados mas ainda não corrigidos
- Incluir: descrição, impacto, como reproduzir, arquivo afetado
- Mover para "Corrigidos" quando o fix for aplicado
- Problemas de segurança vão em [[SECURITY]], não aqui

---

## Bugs ativos

### BUG-001 — handleSyncContacts atualiza contatos cross-tenant

**Arquivo:** `apps/worker/src/worker.ts` (função `handleSyncContacts`)
**Severidade:** Alta
**Identificado em:** 25/04/2026

**Descrição:**
O UPDATE final da sincronização de contatos não filtra por `workspace_id`:
```sql
UPDATE contacts SET name=$1, avatar_url=$2
WHERE phone_e164=$3 OR phone=$4
-- falta: AND workspace_id=$5
```

**Impacto:** Sincronização da instância do tenant A pode sobrescrever nome/avatar de um contato do tenant B se ambos tiverem o mesmo número de telefone.

**Fix planejado:** Fix 2.2 no FIXES.md

---

### BUG-002 — automations.workspace_id tem DEFAULT errado

**Arquivo:** Schema do banco (tabela `automations`)
**Severidade:** Média
**Identificado em:** 25/04/2026

**Descrição:**
```sql
-- DEFAULT atual:
workspace_id UUID DEFAULT '00000000-0000-0000-0000-000000000001'
-- ↑ UUID do workspace Superadmin
```

Automações criadas sem `workspace_id` explícito ficam no workspace do Superadmin em vez de retornar erro.

**Impacto:** Automações "perdidas" que somem da visão do tenant mas aparecem no superadmin.

**Fix planejado:** Fix 4.1 (migration `097_fix_automations_default.sql`)

---

### BUG-003 — Três triggers duplicados na tabela jobs

**Tabela:** `jobs`
**Severidade:** Baixa (funcional, mas custoso)
**Identificado em:** 25/04/2026

**Descrição:** A tabela `jobs` tem 3 triggers fazendo a mesma coisa (atualizar `updated_at`):
- `jobs_updated_at`
- `jobs_updated_at_trigger`
- `trg_jobs_updated_at`

**Impacto:** Cada UPDATE na tabela `jobs` dispara 3 triggers em vez de 1, triplicando o custo.

**Fix planejado:** Fix 4.2 (remover 2 dos 3 triggers)

---

### BUG-004 — Crons críticos não estão agendados no supercronic

**Arquivo:** `apps/cron/crontab`
**Severidade:** Média
**Identificado em:** 25/04/2026

**Descrição:** Vários crons existem no código mas não estão agendados:
- `plan-expiry` — vencimentos de planos não verificados automaticamente
- `renewal-check` — renovações não processadas
- `pix-followup` — follow-up de PIX pendentes
- `trial-followup` — follow-up de trials
- `drip-campaigns` — campanhas de gotejamento paradas
- `close-inactive` — conversas inativas não fechadas automaticamente
- `promote-expired-trials` — trials expirados não promovidos

**Impacto:** Funcionalidades de automação silenciosamente inativas.

**Fix planejado:** Fix 3.6

---

### BUG-005 — instância "01" da Fábrica sem número e desconectada

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa
**Identificado em:** 26/04/2026

**Descrição:** A instância "01" do workspace Fábrica está com `phone_number = NULL` e status `disconnected`. Provavelmente foi criada mas nunca configurada.

**Impacto:** Mensagens enviadas para essa instância falharão silenciosamente.

**Ação:** Verificar com cliente se instância deve ser configurada ou excluída.

---

### BUG-006 — "Disparo 01" do Iphone sem número e desconectada

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa
**Identificado em:** 26/04/2026

**Descrição:** Mesma situação do BUG-005 — instância criada mas nunca conectada ao WhatsApp.

**Ação:** Verificar com cliente Iphone.

---

### BUG-007 — "Uniflix Web" usa tipo "webchat" no phone_number

**Tabela:** `whatsapp_instances`
**Severidade:** Baixa (comportamento proposital?)
**Identificado em:** 26/04/2026

**Descrição:** A instância "Uniflix Web" tem `phone_number = 'webchat'` — string literal, não um número. Status `disconnected` desde 23/04/2026.

**Ação:** Confirmar se é comportamento esperado do webchat ou bug de dados.

---

### B-002 — audit_logs.workspace_id FK não casa com SUPERADMIN_ID seed — ✅ RESOLVIDO 28/04/2026

**Arquivo:** `lib/server/audit.ts` · seed de `workspaces`
**Severidade:** Média (sem auditoria histórica de aprovações/operações superadmin)
**Identificado em:** 28/04/2026 (durante validação técnica do B-001 fix)
**Status:** ✅ **Resolvido** em 28/04/2026 — Opção (a)

**Descrição:**
`audit_logs.workspace_id` tem `FK → workspaces(id) ON DELETE CASCADE` e é `NOT NULL`. Mas `SUPERADMIN_ID = '00000000-0000-0000-0000-000000000001'` (env ou hardcoded em `lib/auth/superadmin.ts`) referencia um workspace que **não existe** no banco. Apenas `00000000-0000-0000-0000-000000000002` (Shark Panel) está seedado.

`logAudit` é fire-and-forget (linha 55: `.catch(() => {})`), então toda chamada com fallback `workspaceId: SUPERADMIN_ID` falha o FK silenciosamente. Comprovado: `SELECT COUNT(*) FROM audit_logs WHERE entity_type='reseller'` → 0 (nenhum approve/reject jamais foi auditado).

**Impacto:**
- Nenhuma auditoria de ações superadmin que cai no fallback (aprovação de reseller/affiliate quando workspace_id ainda não existe, etc.)
- Aprendido: o try/catch do logAudit oculta erros estruturais — sem alarme

**Solução aplicada:** Opção (a) — seed do workspace `00000000-0000-0000-0000-000000000001` ("Superadmin Sistema") como linha real em `workspaces`, mais filtros em 6 listagens do master (excluem o workspace seed da view do tenant).

**Validação:** `INSERT INTO audit_logs` com `workspace_id = '00000000-0000-0000-0000-000000000001'` aceito sem erro de FK.

**Commit:** `4002699d`

---

### B-003 — lib/server/audit.ts cast user_id text→uuid — ✅ RESOLVIDO 28/04/2026

**Arquivo:** `lib/server/audit.ts:40`
**Severidade:** Alta (auditoria silenciosamente quebrada em ~10 callers)
**Identificado em:** 28/04/2026 (durante validação E2E de esqueci-senha)
**Status:** ✅ **Resolvido** em 28/04/2026

**Descrição:**
INSERT em `audit_logs` usava `$2::text` enquanto a coluna `user_id` é `uuid`. Postgres rejeitava o INSERT com `column "user_id" is of type uuid but expression is of type text`. Como `logAudit()` é fire-and-forget (`.catch(() => {})`), o erro era silenciosamente engolido em **todos os callers**.

Confirmado por agregação em `audit_logs`: nenhuma linha com `action` esperado dos callers (todas as linhas existentes vêm do worker, que usa um caminho diferente).

**Impacto:**
~10 callers de `logAudit()` jamais escreveram em `audit_logs`:
- `password.changed` (`app/api/auth/change-password`)
- `password.reset.requested` / `password.reset.completed` (forgot/reset password)
- `module.activated` (`app/api/workspace/activate-module`)
- `whitelabel.*` (`app/api/workspace/whitelabel`)
- `member.*` (`app/api/workspaces/members/create`)
- `knowledge.*` (`app/api/knowledge/items/bulk`)
- `master.*` (`app/api/master/{plans,settings,resellers}`)

**Solução aplicada:**
```diff
-     ) VALUES ($1,$2::text,$3,...)`,
+     ) VALUES ($1,$2::uuid,$3,...)`,
```
`nextauth_users.id` (text) já guarda valores em formato UUID válido — cast `text → uuid` funciona.

**Validação:** Após redeploy, `INSERT` em `audit_logs` via `logAudit()` passa, `password.reset.requested` aparece com `details.sent=true` no fluxo real.

**Commit:** `4dd33d45`

---

### B-004 — Evolution API: callers usavam UUID em vez do name — 🟡 EXPANDIDO E PARCIAL (7/11)

**Arquivo:** múltiplos (ver tabela abaixo)
**Severidade:** Alta (afetou esqueci-senha, aprovação de revendedor, e mais)
**Identificado em:** 28/04/2026
**Status:** 🟡 **Expandido e parcial (7/11)** — investigação 28/04 revelou que B-004 tinha 11+ callers, não 4

**Descrição:**
A Evolution API espera o **nome** da instância no path (com `encodeURIComponent`), não o `evolution_instance_id` (UUID). Confirmado por teste direto:
- `POST /message/sendText/Marsbaks` → 400 (instância achada, payload rejeitado)
- `POST /message/sendText/027390a5-...` → **404 Not Found**

Inicialmente identificado em forgot-password; investigação posterior achou outros 7 callers com o mesmo padrão (uns latentes, outro ativo afetando aprovações de revendedor).

**Estado dos 11 callers:**

| Caller | Status | Severidade real | Commit |
|---|---|---|---|
| `app/api/auth/forgot-password/route.ts` | ✅ Fixado | Alta — quebrava o fluxo | `4dd33d45` |
| `app/api/resellers/withdraw/route.ts:119` | ✅ Fixado | Média | `d799ce4b` |
| `app/api/resellers/public-signup/route.ts:39` | ✅ Fixado | Média | `d799ce4b` |
| `app/api/trial/web/route.ts:329` | ✅ Fixado | Média | `d799ce4b` |
| `app/api/admin/resellers/[id]/route.ts:252` | ✅ Fixado | **Alta — ATIVO** (3 aprovações esta semana sem WhatsApp) | `f1a6e667` |
| `app/api/affiliates/public-signup/route.ts:35` | ✅ Fixado | Média (notifica superadmin) | `f1a6e667` |
| `app/api/cron/weekly-report/route.ts:200` | ✅ Fixado | Média (latente: 0 workspaces com `report_enabled=true`) | `f1a6e667` |
| `app/api/pedidos/[id]/recibo/route.ts:311` | ✅ Fixado | Média (sendMedia, UI visível) | `f1a6e667` |
| `app/api/cron/check-worker-alerts/route.ts:389` | ⏳ Pendente | Baixa (`alerts_triggered=0` sempre) | — |
| `app/api/cron/reseller-levels/route.ts:96` | ⏳ Pendente | Baixa (schema sem coluna `level` — investigar antes) | — |
| `app/api/v1/messages/send/route.ts:52` | ⏳ Pendente | Baixa (0 api_tokens existentes) | — |
| `app/api/iptv/generate-and-send/route.ts:283,576` | ⏳ Pendente | Baixa (caminho raro com `conversationId`) | — |

**Solução aplicada (padrão):**
```diff
-  const { rows } = await query<{ evolution_instance_id: string }>(
-    `SELECT evolution_instance_id FROM whatsapp_instances WHERE ...`,
+  const { rows } = await query<{ name: string }>(
+    `SELECT name FROM whatsapp_instances WHERE ...`,
    ...
   );
-  await fetch(`${url}/message/sendText/${rows[0].evolution_instance_id}`, ...);
+  await fetch(`${url}/message/sendText/${encodeURIComponent(rows[0].name)}`, ...);
```

Em `pedidos/[id]/recibo` a variável foi renomeada `evolutionInstanceId → evolutionInstanceName` para refletir o conteúdo. Em `trial/web` e `iptv/generate-and-send` o `instance.id` (UUID do banco) ainda é necessário para FKs internas (`contact_tags`, `conversations`), então mantido um `instanceName` paralelo só para o path do Evolution.

**Commits:** `4dd33d45` (forgot) · `d799ce4b` (3 callers BLOCO 1) · `f1a6e667` (4 callers extras BLOCO 4)

**Débito:** Aplicar mesmo fix nos 4 callers BAIXA pendentes — ver [[../Empresa/débitos]].

---

### B-005 — phone_whatsapp não normalizado pra E.164 com 55 BR — ✅ RESOLVIDO 28/04/2026

**Arquivo:** `lib/utils/phone.ts` (novo) · 7 fluxos de escrita refatorados · `app/api/auth/forgot-password/route.ts` refatorado
**Severidade:** Alta (esqueci-senha falhava com 400 mesmo após B-004 fix)
**Identificado em:** 28/04/2026
**Status:** ✅ **Resolvido** em 28/04/2026 — helper + migration backfill + escrita sanitizada

**Descrição:**
`nextauth_users.phone_whatsapp` e `resellers.phone_whatsapp` estavam armazenados **sem código de país** (ex: `53991086613` com 11 dígitos, em vez de `5553991086613`). Evolution API rejeita com `400 Bad Request` quando o número não tem `55`. O código de envio só fazia `replace(/\D/g, '')` — não normalizava.

Validado: `sendText` com `53991086613` → 400; com `5553991086613` → PENDING (entregue).

**Solução completa aplicada:**

1. **Helper compartilhado** `lib/utils/phone.ts`:
   ```typescript
   export function normalizeBrPhone(input: string | null | undefined): string {
     if (!input) return '';
     const digits = input.replace(/\D/g, '');
     if (!digits) return '';
     if (digits.startsWith('55')) return digits;
     return `55${digits}`;
   }
   ```

2. **Migration de backfill** rodada em produção (3 rows: 2 em `nextauth_users` + 1 em `resellers`):
   ```sql
   UPDATE nextauth_users SET phone_whatsapp = '55' || phone_whatsapp
     WHERE LENGTH(phone_whatsapp) IN (10, 11) AND NOT phone_whatsapp LIKE '55%';
   UPDATE resellers SET phone_whatsapp = '55' || phone_whatsapp
     WHERE LENGTH(phone_whatsapp) IN (10, 11) AND NOT phone_whatsapp LIKE '55%';
   ```

3. **Sanitização nos fluxos de escrita** (7 lugares):
   - `app/api/resellers/register/route.ts` (INSERT users + resellers)
   - `app/api/resellers/public-signup/route.ts` (INSERT resellers)
   - `app/api/internal/resellers/route.ts` (INSERT + UPDATE resellers)
   - `app/api/master/resellers/route.ts` (INSERT resellers)
   - `app/api/affiliates/public-signup/route.ts` (INSERT resellers)
   - `app/api/profile/route.ts` (UPDATE nextauth_users)
   - Validação de tamanho mínimo ajustada de `>=10` → `>=12` (phone agora vem com `55`).

4. **Refactor do `forgot-password/route.ts`** — substituída a lógica inline pelo helper, eliminando o quick fix do commit `e97acdbe`.

**Validação:** Smoke test E2E pós-deploy — `POST /api/auth/forgot-password` para `viniciusfernandesfmk24@gmail.com` (phone backfillado de `5381062741` → `555381062741`) gerou audit `password.reset.requested` com `details.sent=true`.

**Commits:** `e97acdbe` (quick fix inicial) · `33bf9052` (helper + escrita sanitizada + refactor)

**Lições:**
- `phone-validator.ts` (mais antigo) já tinha lógica robusta similar (`validateAndNormalizePhone`), mas era código órfão — nunca foi usado em fluxo de escrita. Optamos por criar `normalizeBrPhone` simples e drop-in em vez de adaptar o código órfão (escopo controlado).

---

### B-007 — "Anual" mapeado pra pacote de 3 meses Sigma — 📘 NÃO É BUG (estratégia)

**Status:** Reclassificado em 29/04/2026. Documentado como estratégia comercial.
**Ver:** [[../Empresa/decisoes-arquiteturais]] **ADR-002**.

**Descrição original (descartada):**
Auditoria do catálogo Sigma via API (`GET sharks10.top/api/webhook/package`) revelou que `sigma_plan_mapping.sigma_package_id = 'RYAWRk1jlx'` configurado pra plan_key `anual-s1` é, no Sigma, **"3 MESES COMPLETO COM ADULTOS"** — não 12. Inicialmente parecia bug crítico afetando todos clientes que compraram "Anual" no `/comprar?ref=X`.

**Esclarecimento (29/04):**
Vinicius: "não é bug, é estratégia — modelo reseller com servidor reserva."

Cliente paga "Anual" (12 meses), sistema ativa apenas 3 meses no Sigma principal, restantes 9 meses ficam em "reserva" — Vinicius migra manualmente quando expira no principal. Modelo financeiramente saudável e em produção há tempo.

**Ação tomada:**
- Schema atualizado em F-001 Fase 2.2 BLOCO 3.0: `special_iptv_plans` agora tem `client_months` (12) e `sigma_months` (3) separados — modelo formalizado
- UI `/reseller/clientes` mostra "Restam migrar: N meses (reserva)" pra reseller saber o que tem em reserva
- Detalhes em [[feature-creditos-iptv]]

---

### B-006 — AmploPay URL legada em 4 rotas — 🟡 PARCIAL (1/4)

**Arquivos:** `app/api/resellers/credits/purchase/route.ts` (✅ fixado) · `app/api/workspace/buy-credits/route.ts` (⏳) · `app/api/workspace/buy-agent/route.ts` (⏳) · `app/api/workspace/plan/subscribe/route.ts` (⏳)
**Severidade:** Alta (3 rotas latentes ainda quebradas em produção)
**Identificado em:** 28/04/2026 (durante E2E do F-001 Fase 2)

**Descrição:**
Rotas antigas usam URL legada `https://api.amplopay.com/gateway/pix/receive` que retorna **404 com HTML do Next.js** (AmploPay aparentemente desligou esse endpoint sem aviso). URL atual: `https://app.amplopay.com/api/v1/gateway/pix/receive`.

**Diferenças entre as APIs:**
| Aspecto | Legada (404 hoje) | Atual |
|---|---|---|
| URL | `api.amplopay.com/gateway/pix/receive` | `app.amplopay.com/api/v1/gateway/pix/receive` |
| Auth | `Authorization: Bearer ${secretKey}` | `x-public-key` + `x-secret-key` (2 headers) |
| Body | `customer: {name, email}` | `client: {name, email, phone, document}` |
| Phone | opcional | **obrigatório** (string) |
| Document/CPF | não enviado | **obrigatório** |
| Response | `pixCode` / `qrCode` | `pix.code` / `pix.base64` |

**Estado por rota:**
| Rota | Status | Commits |
|---|---|---|
| `app/api/resellers/credits/purchase` | ✅ Fixado | `dae155a2` (URL+auth+body) + `f26d383e` (phone fallback) |
| `app/api/workspace/buy-credits` | ⏳ Pendente | — |
| `app/api/workspace/buy-agent` | ⏳ Pendente | — |
| `app/api/workspace/plan/subscribe` | ⏳ Pendente | — |

**Como descobri:**
E2E manual do F-001 Fase 2 — Vinicius clicou "Comprar créditos" e recebeu toast "Falha de rede". Logs do server mostraram `[resellers/credits/purchase] amplopay non-ok status=404 body=<!DOCTYPE html>...`. Comparei com `checkout/create-pix/route.ts` (que funciona) e identifiquei a divergência de URL/headers/body.

**Validação do fix:**
Curl manual contra AmploPay: sem `client.phone` → 400 GATEWAY_INVALID_DATA com Zod error path `["client","phone"]`. Com phone → 200 + `pix.code` + `pix.base64`. Pagamento real (R$ 5) creditou normalmente — ver [[feature-creditos-iptv]].

**Débito:** As 3 rotas restantes precisam do mesmo fix. São fluxos com baixo volume (compra de créditos AI workspace, compra de agente, assinatura de plano workspace) — provavelmente por isso passou despercebido. Listadas em [[../Empresa/débitos]].

---

### B-001 — public-signup não cria nextauth_users (afiliados + revendedores) — ✅ RESOLVIDO 28/04/2026

**Arquivos:** `app/api/resellers/public-signup/route.ts` · `app/api/affiliates/public-signup/route.ts` · `app/api/admin/resellers/[id]/route.ts`
**Severidade:** Alta (revendedor) / Média contornada (afiliado)
**Identificado em:** 28/04/2026 (durante implementação F-001 fase 1)
**Status:** ✅ **Resolvido** em 28/04/2026 — Opção C2 + change-password + skip workspace

**Descrição original:**
Ambas as rotas públicas de cadastro inseriam em `resellers` com `user_id=NULL`. O fluxo de aprovação (`PATCH /api/admin/resellers/[id]` action='approve') dependia de `reseller.user_id` para:
1. `UPDATE nextauth_users SET status='approved' WHERE id=$user_id` (silenciosamente fazia nada)
2. `INSERT INTO workspaces (..., owner_id) VALUES (..., $user_id)` — falhava porque `workspaces.owner_id` é `NOT NULL`

**Impacto original:**
- Revendedor: cadastros públicos aprovados não conseguiam logar; aprovação master via UI quebrava silenciosamente
- Afiliado: aprovação manual explodia (apesar do afiliado não precisar logar)

**Solução final aplicada:**

| Commit | Conteúdo |
|---|---|
| `c92dc777` | `lib/auth/temp-password.ts` — gerador legível com `crypto.randomBytes`, alfabeto sem ambíguos. `POST /api/auth/change-password` autenticado (bcrypt cost 12). UI `/configuracoes/senha` com 3 campos. Botão "Trocar senha" no header do `/reseller`. |
| `d1a82488` | `app/api/admin/resellers/[id]/route.ts` action='approve' reescrito: gera senha temp em memória se `user_id IS NULL`, `INSERT INTO nextauth_users` com hash bcrypt. Idempotente (`if password IS NULL`). Reaproveita user_id existente em caso de email duplicado. **Pula workspace pra `type='affiliate'`**. WhatsApp ganha bloco condicional com credenciais. |

**Garantias:**
- Senha em texto **só vive em variável local da request** — nunca persiste em coluna
- Re-aprovar não troca senha de quem já tem
- Afiliado nunca cria workspace (correto — não usa)
- Fluxo de troca disponível em `/configuracoes/senha`

**Validação técnica (afiliado teste WYYKP6):**
- `resellers`: `status='approved'`, `user_id=841e40a8-…`, `workspace_id=NULL` ✓
- `nextauth_users`: linha nova, `status='approved'`, `password` bcrypt 60 chars ✓
- `workspaces`: 0 rows com owner_id do afiliado ✓
- `audit_logs`: 0 rows — descoberta secundária registrada como **B-002** (não regressão)

**Ver também:** [[feature-afiliados]] · [[auth-change-password]]

---

### B-009 — Anual e Semestral usam package de 3 meses (MÉDIA) — ✅ RESOLVIDO 29/04/2026

**Arquivo:** dados de configuração — `special_iptv_plans` workspace Uniflix
**Severidade:** Média
**Identificado em:** 29/04/2026 (auditoria pós-Fase 2.2)
**Status:** ✅ Resolvido — UPDATE aplicado direto no banco (29/04/2026)

**Descrição:**
Workspace Uniflix tem `special_iptv_plans.annual` e `semiannual` apontando pro `sigma_package_id = 'RYAWRk1jlx'` (3 meses). Cliente pagando R$240 anual recebe só 3 meses no Sigma.

IDs corretos identificados via `GET sharks10.top/api/webhook/package`:
- 6m → `VpKDaJWRAa` (12000 cents, 6 cred sugerido)
- 12m → `o231qzL4qz` (24000 cents, 12 cred sugerido)

**Fix aplicado:**
```sql
UPDATE special_iptv_plans SET sigma_package_id='VpKDaJWRAa', sigma_months=6
  WHERE workspace_id='00000000-0000-0000-0000-000000000002' AND slug='semiannual';
UPDATE special_iptv_plans SET sigma_package_id='o231qzL4qz', sigma_months=12
  WHERE workspace_id='00000000-0000-0000-0000-000000000002' AND slug='annual';
```

**Validação:** SELECT pós-fix mostra annual=`o231qzL4qz`/12m, semiannual=`VpKDaJWRAa`/6m.

> Nota: difere do antigo B-007 ("Anual" mapeado pra 3m) — aquele caso era estratégia comercial documentada em ADR-002. B-009 cobre o cenário Fase 2.2 onde `client_months ≠ sigma_months` precisa de package alinhado.

---

### B-AMPLOPAY-001 — webhook não popula subscriptions.iptv_* (MÉDIA) — ✅ RESOLVIDO 29/04/2026

**Arquivo:** `app/api/payments/amplopay-webhook/route.ts:1418-1442`
**Severidade:** Média (subscriptions inconsistentes para clientes via checkout)
**Identificado em:** 29/04/2026
**Status:** ✅ Resolvido — commit `edff115d` + backfill de 169 subscriptions

**Descrição:**
Subscriptions com `source='amplopay'` ficam com `iptv_username = NULL` (idem `iptv_password`, `iptv_server`, `iptv_expires_at`). Credenciais ficam apenas em `payments.metadata` (jsonb).

`sigmaResult` é capturado em `route.ts:1141`, mas o INSERT/UPDATE em `subscriptions` (linhas 1418-1442) ignora os campos mesmo estando no escopo.

**Fix aplicado:**
- Código: INSERT/UPDATE em `subscriptions` agora incluem `iptv_username/password/server/expires_at` (commit `edff115d`)
- Backfill: 169 subscriptions legadas restauradas a partir de `payments.metadata`

**Investigação completa:** `/root/b-amplopay-001-investigation.md`.

---

### D-SIGMA-painel — visibilidade reseller no painel sharks10.top (BAIXA)

**Arquivo:** investigação operacional
**Severidade:** Baixa (operacional, não bloqueia ativação)
**Identificado em:** 29/04/2026

**Descrição:**
Investigar se cliente criado pelo reseller via Fase 2.2 aparece no painel `sharks10.top` do reseller (e não somente do admin). Vinicius vê cliente "real" sob reseller `adm-shark`, mas o sistema marca cliente teste sob `super-sharkstreaming`.

**Bloqueado em:** precisa contexto da conta admin sharks10.top.

---

### B-PARSER-001 — Sigma DD/MM/YYYY rejeitado pelo Postgres — ✅ RESOLVIDO 29/04/2026

**Arquivo:** `lib/sigma/provision.ts` (`parseSigmaDate`)
**Severidade:** Alta (Fase 2.2 quebrava no INSERT subscription)
**Identificado em:** 29/04/2026 (madrugada)
**Status:** ✅ Resolvido — entregue em Fase 2.2

**Descrição:**
Sigma retorna `expiresAt` em formato BR (`DD/MM/YYYY HH:MM:SS`). Postgres `TIMESTAMPTZ` rejeita esse formato. Causava erro fatal no INSERT subscription (que ficou exposto após ADR-003 fail-loud).

**Solução:** `parseSigmaDate()` em `lib/sigma/provision.ts` converte BR → ISO antes do INSERT.

**Validação:** subscription `644352438` tem `iptv_expires_at = 2026-05-30` ✓

---

### B-DRIP-001 — Cron drip-campaigns INSERT em coluna inexistente — ✅ RESOLVIDO 29/04/2026

**Arquivo:** `app/api/cron/drip-campaigns/route.ts:118`
**Severidade:** Alta (drips ativos = 0 mensagens enviadas, falha silenciosa)
**Identificado em:** 29/04/2026 (deep-dive automações)
**Status:** ✅ Resolvido — commit `ec2061b9`

**Descrição:**
Cron `drip-campaigns` fazia `INSERT INTO jobs (type, payload_json, status, run_at)`. A coluna `payload_json` **não existe** em `jobs` — o nome correto é `payload` (`jsonb NOT NULL`). INSERT falhava silenciosamente via try/catch externo.

Adicionalmente o INSERT não passava `workspace_id` (NOT NULL na tabela) nem `max_attempts`, divergindo do padrão dos outros 20+ INSERTs em `jobs` espalhados pelo projeto.

**Fix aplicado:**
- `payload_json` → `payload` (jsonb NOT NULL)
- adicionado `workspace_id` (vindo de `campaign.workspace_id`, já no escopo)
- adicionado `max_attempts: 3` (padrão dos demais INSERTs)
- cast `$2::jsonb` explícito

**Como descoberto:** deep-dive 29/04 (`auditorias/2026-04-29-multitenant-bugs/deep-drip.md`). Confirmado via `information_schema.columns` que `payload_json` não existe.

**Impacto:** Adoption atual de `drip_campaigns` = 0 → fix preventivo, sem necessidade de backfill.

---

### B-MULTITENANT-001 — 5 endpoints IA sem WHERE workspace_id em ai_provider_settings — ✅ RESOLVIDO 29/04/2026

**Arquivos:**
- `app/api/ai-studio/chat/route.ts`
- `app/api/ai/agent-chat/route.ts`
- `app/api/ai/assistant/route.ts`
- `app/api/ai/generate-agent-prompt/route.ts`
- `app/api/ai/generate-followup/route.ts`

**Severidade:** Alta (vazamento de API key cross-tenant — \$\$ + GDPR)
**Identificado em:** 29/04/2026 (deep-dive IA)
**Status:** ✅ Resolvido — commit `962ecdb4`

**Descrição:**
Cinco endpoints faziam `SELECT ... FROM ai_provider_settings LIMIT 1` sem `WHERE workspace_id`. Como a tabela é multi-tenant, workspaces sem AI configurada acabavam consumindo a key configurada por outro tenant (na prática: chupavam a key do `shark-panel`, único com `openai_api_key` em produção).

**Fix aplicado:**
- `getWorkspaceIdSafe()` resolvido após `auth()`
- Query: `WHERE workspace_id = $1 LIMIT 1`
- Resposta `400 { error: 'no_config' }` se workspace sem AI configurada
- Mantido `422 { error: 'no_key' }` se row existe mas key vazia

**Estado prod ao corrigir:** apenas `shark-panel` tinha `openai_api_key` configurada → vazamento real era unidirecional. Fix preventivo antes de adicionar IA pra outros tenants.

**Pendentes (decisão arquitetural):**
- `app/api/master/ai-agents/[id]/app-flow/chat` — rota master, cross-tenant por design (deve usar workspace do agent, não do user)
- `app/api/sales-brain/process` — comentário explícito "global", inconsistente com outros 10 endpoints

**Como descoberto:** deep-dive 29/04 (`auditorias/2026-04-29-multitenant-bugs/deep-ia.md`).

---

### BUG-008 — zapflix-monitor offline há mais de 3 semanas

**Serviço:** `wp_zapflix-monitor`
**Severidade:** Operacional
**Identificado em:** 25/04/2026

**Descrição:** O serviço de monitoramento (Flask) está com 0/1 réplicas, exit code 255. Nenhum alerta de WhatsApp está sendo disparado.

**Impacto:** Sistema operacionalmente cego — nenhuma notificação em caso de falha.

**Fix planejado:** Fix 3.5 (configurar variáveis de ambiente corretas)

---

## Bugs corrigidos

| ID | Descrição | Corrigido em | Commit |
|----|-----------|-------------|--------|
| — | Auth ausente em /api/debug/* e /api/migrate/* | 26/04/2026 | b102cb02 |
| — | Cron secret hardcoded 'zapflix2026' | 26/04/2026 | — |
| B1 | Anti-ban quebrado — queries SQL filtravam `direction='outbound'` mas banco usa `'out'`, contadores sempre 0 e limite diário nunca disparava (worker.ts linhas 3692, 4592, 4601) | 27/04/2026 | fe65a0ca |
| B2 | AI Agent histórico vazio — SELECT usava coluna `body` (correta é `text`) e filtro JS comparava com `'outbound'` (worker.ts linhas 3299/3306) | 27/04/2026 | e2f5ba16 |
| B3 | Cross-tenant no AI Agent — query `app_flow_nodes JOIN ai_writing_agents` sem filtro de `workspace_id`, prompt do agente vazava nodes de outros tenants (worker.ts linha 3390) | 27/04/2026 | c9d90b87 |
| B4 | Pool de conexões saturado — `handleProcessWebhook` segurava o client do `BEGIN` até o `finally`, mantendo a conexão durante chamadas Whisper/Vision/GPT-4o-mini (10-30s); 5 webhoooks simultâneos travavam o worker. Fix: `safeRelease()` movido para logo após o `COMMIT` (worker.ts linha 1949) | 27/04/2026 | 73d4257f |
| BUG-009 | Sidebar do cliente reorganizada — nova estrutura: Atendimento / Canais / Vendas / IPTV / Automação / IA / Analytics / Equipe / Revendedor / Configurações / Desenvolvedor / Interno. "Vitrine Netflix"→"Vitrine"; Loja de Módulos com roles owner/admin (e fora de viewerPaths); Documentação Webchat e Follow-up Automático removidos do menu; Revendedor consolidado em /reseller único; Meu Setup → Configurações; Faturamento sem dependência de iptv_trials; Painel Master encapsulado em "Interno" com Mapa de Workspaces e Sigma (todos superAdminOnly). `IPTV_RESELLER_ALLOWED_HREFS` atualizado de `/reseller-dashboard` → `/reseller`. (`components/layout/sidebar-nav.tsx`) | 27/04/2026 | eeecb23e |
| BUG-010 | Bipe de notificação tocava em todo carregamento de página — useEffect comparava `unreadCount` contra `prevUnreadRef=-1`, mas o segundo run (após `fetchNotifications` resolver) tinha `prev=0` e `count=N>0`, disparando o som como se fosse notificação nova. Fix: `notifInitializedRef` (true só após primeiro fetch) + `baselineSetRef` (true após gravar baseline pós-fetch) garantem que o som só toca em incremento real (`components/layout/top-bar.tsx`) | 27/04/2026 | b04b09a2 |
| BUG-011 | Flash visual de skeleton "fake-dashboard" em toda navegação entre páginas filhas — `app/(dashboard)/loading.tsx` renderizava header + stats cards + activity grid em todas as transições, mesmo quando navegando para /contacts, /campaigns, etc. Removido o skeleton, mantido o componente retornando `null` (Suspense boundary continua existindo para CSR bailout do `/settings` durante prerender do build). Resultado: navegação mantém a página anterior visível até a nova carregar (`app/(dashboard)/loading.tsx`) | 27/04/2026 | b03eebee |
| BUG-012 | `/audit-logs` exibia dados falsos (`generateMockLogs`) como fallback quando `/api/audit-logs` falhava, gerando confusão com auditoria real. Sidebar agora aponta "Logs de Auditoria" para `/audit-log` (real, alimentado por `/api/audit-log`); `/audit-logs/page.tsx` substituído por redirect server-side para `/audit-log`. Snapshot da análise master×cliente em [[master-vs-cliente-mapping]]. (`components/layout/sidebar-nav.tsx`, `app/(dashboard)/audit-logs/page.tsx`) | 27/04/2026 | 07923218 |
| BUG-013 | `/monitoring` era rota órfã (não estava no menu) e duplicava no rodapé as 3 tabs de settings (Notificações/Segurança/Webhooks) já existentes em `/settings` — incluindo state, fetch para `/api/settings` e handlers `handleSettingsSave`/`handleSettingsDiscard`. Removido o bloco "Configurações do Sistema" e seus imports/state/handlers (page.tsx: 1483→1367 linhas). Adicionado item "Monitoramento" na seção Analytics do sidebar (icon `Activity`, roles owner/admin, permissionKey `settings`). Conteúdo real (worker, jobs, mensagens, instâncias, alertas, timeline) preservado. (`app/(dashboard)/monitoring/page.tsx`, `components/layout/sidebar-nav.tsx`) | 27/04/2026 | ce1a3617 |
| BUG-014 | Páginas de revendedor duplicadas — `/reseller` (versão simples no sidebar) coexistia com `/reseller-dashboard` (versão rica órfã do sidebar após BUG-009). Migrado para `/reseller` o que faltava: card de níveis (bronze/prata/ouro/diamante) com Progress bar, gráfico de vendas mensais (recharts BarChart), tabela de clientes indicados. Mantida a estrutura de gating (pending/blocked/rejected) e o modal de saque do `/reseller`. Page agora carrega `/api/resellers/me` + `/api/resellers/my-sales` + `/api/reseller/dashboard` em paralelo; o card de nível só renderiza quando `dashboard` estiver disponível (revendedor aprovado). `/reseller-dashboard/page.tsx` virou redirect server-side para `/reseller`. (`app/(dashboard)/reseller/page.tsx`, `app/(dashboard)/reseller-dashboard/page.tsx`) | 27/04/2026 | 243de1b6 |
| BUG-015 | `/ai-assistant` era rota órfã do sidebar principal, embora tivesse 6 tabs ativas (dashboard/chat/knowledge/documents/suggestions/audio) com APIs reais (`/api/ai/dashboard`, `/api/ai/chat`, `/api/ai/knowledge`, `/api/ai/process-conversations`). Plugada no sidebar na seção "Inteligência Artificial" como "Assistente IA" (icon `MessageSquare`, roles owner/admin, permissionKey `ai`), entre "Estúdio IA" e "Cérebro de Vendas". (`components/layout/sidebar-nav.tsx`) | 27/04/2026 | 243de1b6 |
| BUG-016 | Componentes de layout órfãos removidos — `components/layout/app-sidebar.tsx` (sidebar alternativo nunca importado, referenciava rotas inexistentes `/chat` e `/conversations`) e `components/layout/app-layout.tsx` (importava só o `app-sidebar` e também não era importado em lugar algum). Verificado por grep recursivo antes da remoção. `route-title-updater.tsx` mantido — é importado por `app-shell.tsx`. | 27/04/2026 | 243de1b6 |
| BUG-017 | Identidade visual desalinhada — sidebar do master mostrava ícone `Crown` (lucide) e o cliente caía em `Sparkles` quando não havia logo de whitelabel, ambos divergindo do favicon 🦈. Master agora exibe 🦈 no quadrado dourado; cliente passa a usar 🦈 como fallback do logo. Topo do sidebar do cliente também ficou mais compacto: `h-14`→`h-12`, gap `2.5`→`2`, padding `px-4`→`px-3`, logo `h-7 w-7`→`h-6 w-6` (rounded-md), texto `text-sm font-bold`→`text-xs font-semibold` com `truncate` para nomes longos. Sem mudança de lógica — só visual. (`components/layout/master-sidebar.tsx`, `components/layout/sidebar-nav.tsx`) | 28/04/2026 | 758ae437 + cd1f1c44 |

---

## Template para novo bug

```
### BUG-XXX — [Título curto]

**Arquivo/Serviço:** 
**Severidade:** Crítica / Alta / Média / Baixa / Operacional
**Identificado em:** DD/MM/AAAA

**Descrição:**
[O que acontece]

**Impacto:**
[O que quebra para quem]

**Como reproduzir:**
1. 
2. 

**Fix planejado:** [referência ao FIXES.md ou "a definir"]
```
