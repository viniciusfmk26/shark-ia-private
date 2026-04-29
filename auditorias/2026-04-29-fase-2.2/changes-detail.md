# Catálogo de mudanças não-commitadas — Fase 2.2 (29/04/2026)

## Resumo
```
 components/layout/sidebar-nav.tsx |   1 +
 lib/sigma/provision.ts            | 119 +++++++++++++++++++++++++++++++++++++-
 2 files changed, 118 insertions(+), 2 deletions(-)
```

Branch base: HEAD após commit `914f8a51` (`fix(F-001 Fase 2): detectar pagamento e fechar modal automaticamente`).

---

## 1. `components/layout/sidebar-nav.tsx` (+1 linha)

### Mudança
Adicionado novo item de menu **"Meus Clientes"** no grupo "Revenda".

```diff
@@ -207,6 +207,7 @@ const NAV_CATEGORIES: NavCategory[] = [
     items: [
       { title: 'Painel Revendedor', href: '/reseller', icon: Store, module: null },
       { title: 'Créditos', href: '/reseller/creditos', icon: CreditCard, module: null },
+      { title: 'Meus Clientes', href: '/reseller/clientes', icon: Tv2, module: null },
       { title: 'Meus Revendedores', href: '/resellers', icon: Users, module: null, roles: ['owner', 'admin'], permissionKey: 'settings' },
     ],
   },
```

### Contexto
- Rota `/reseller/clientes` existe pra revendedor visualizar os clientes IPTV criados via crédito.
- Antes, o reseller acessava só via deep-link/manual; agora tem entrada dedicada no menu.
- Ícone reutiliza `Tv2` (já importado), sem nova dependência.

### Por quê
F-001 Fase 2.2 (sistema de crédito IPTV avulso) entregou a página `/reseller/clientes` mas faltou expor no menu — UX quebrada, navegação dependia de URL direta.

### Risco
**Baixo.** Mudança puramente declarativa de menu, sem impacto em backend, permissões ou roteamento.

---

## 2. `lib/sigma/provision.ts` (+117/-2 linhas)

Três blocos de mudanças.

### 2.1 Comentários de debug deixados como referência (linhas ~141 e ~155)

```diff
@@ -141,6 +141,8 @@ async function createCustomer(
     note: phone,
   };

+  // logger.info(`[Sigma DEBUG] createCustomer payload: ${JSON.stringify(body)} url=${url}`);
+
   try {
     ...
     const text = await res.text();
+    // logger.info(`[Sigma DEBUG] createCustomer response: status=${res.status} body=${text.slice(0, 500)}`);
```

**Por quê:** Durante depuração de Fase 2.2 foi necessário ver payload bruto enviado/recebido pra Sigma. Comentários ficaram como pista pra debug futuro — basta descomentar.

**Recomendação:** Antes do commit final, decidir se mantém comentados (útil pra ops) ou remove (limpeza). **Não bloqueante.**

---

### 2.2 Bug fix: Sigma retorna data PT-BR que Postgres rejeita (linhas 162 e 200)

```diff
-      expires_at: data?.expires_at ?? data?.expiresAt ?? data?.expire ?? null,
+      expires_at: parseSigmaDate(data?.expires_at ?? data?.expiresAt ?? data?.expire),
```

E no `renewCustomer` (linha 200):
```diff
-    return { expires_at: data?.expires_at ?? data?.expiresAt ?? data?.expire ?? null };
+    return { expires_at: parseSigmaDate(data?.expires_at ?? data?.expiresAt ?? data?.expire) };
```

Com nova função utilitária:
```ts
function parseSigmaDate(s: string | null | undefined): string | null {
  if (!s || typeof s !== 'string') return null;
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
    const d = new Date(s);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }
  const m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$/);
  if (m) {
    const [, d, mo, y, h, mi, se] = m;
    const date = new Date(`${y}-${mo}-${d}T${h}:${mi}:${se}-03:00`);
    return isNaN(date.getTime()) ? null : date.toISOString();
  }
  const fallback = new Date(s);
  return isNaN(fallback.getTime()) ? null : fallback.toISOString();
}
```

**Por quê:**
- Sigma retorna `expiresAt` em formato `DD/MM/YYYY HH:MM:SS` (PT-BR).
- Postgres `TIMESTAMPTZ` não consegue parsear esse formato.
- Antes: `INSERT` falhava ou ficava com `null`, quebrando a renovação/expiração tracking.
- Depois: converte explicitamente pra ISO 8601 com offset BRT (`-03:00`).

**Casos cobertos:**
1. ISO 8601 já vem do Sigma (alguns endpoints): passa direto.
2. Formato PT-BR `DD/MM/YYYY HH:MM:SS`: converte considerando timezone BRT.
3. Qualquer outro formato parseável por `Date`: fallback.
4. Não parseável: retorna `null` (campo é nullable no schema).

**Risco:** Médio. Mexe em fluxo crítico (provisionamento Sigma). Recomenda-se smoke test no próximo provisionamento real.

---

### 2.3 Nova função `provisionSigmaByPackage` (linhas 337-424, ~88 linhas)

Função pública nova exportada do módulo, usada por F-001 Fase 2.2.

**Assinatura:**
```ts
export async function provisionSigmaByPackage(params: {
  serverId: string;
  packageId: string;
  customerName: string;
  phoneDigits: string;
  workspaceId: string;
}): Promise<ProvisionResult | null>
```

**Por quê existe (em vez de reusar `provisionSigmaCustomer`):**
- O fluxo legado (`provisionSigmaCustomer`) faz lookup `sigma_plan_mapping ↔ checkout_plans` pra descobrir `sigma_package_id`.
- A Fase 2.2 ativa cliente via crédito de reseller usando `special_iptv_plans`, que já carrega `sigma_server_id` e `sigma_package_id` direto.
- O lookup legado não tem o vocabulário novo (slugs `monthly`/`quarterly`/etc) → quebraria.
- Solução: função nova que pula o mapping e usa server+package diretos.

**Comportamento:**
1. Busca `sigma_servers` ativo pelo `serverId`.
2. Sintetiza um `SigmaMapping` fake pra preservar shape de `ProvisionResult` (consumers como webhook acessam `.mapping.is_vip`).
3. Procura cliente existente por `phoneDigits` (note no Sigma).
4. Se existe → renova com novo pacote.
5. Se não existe → cria com nome+phone+pacote.
6. Retorna credenciais + `expires_at` parseado (via 2.2 acima).

**Onde é chamada:** Pelo backend de "ativar cliente IPTV" do reseller (consumir crédito + criar customer Sigma), implementado em commits anteriores desta sessão.

**Risco:** Médio-baixo. Função nova, não impacta caminho antigo. Consumers cobertos por testes manuais Fase 2.2.

---

## Estado pré-commit

- [x] Mudanças funcionalmente validadas (Fase 2.2 entregue e healthy).
- [ ] Decidir se comentários debug em `createCustomer` ficam ou saem.
- [ ] Mensagem de commit sugerida (ver `commit-bloco-3.5.txt` se existir, senão criar).
- [ ] Smoke test próximo provisionamento real pra confirmar `parseSigmaDate`.

## Mensagem de commit sugerida

```
feat(F-001 Fase 2.2): provisionSigmaByPackage + fix de data PT-BR

- Adiciona provisionSigmaByPackage() pra ativar cliente Sigma direto
  via server_id + package_id (usado no fluxo de crédito IPTV avulso),
  pulando o lookup sigma_plan_mapping legado.
- Corrige parseSigmaDate(): Sigma retorna expiresAt em DD/MM/YYYY
  HH:MM:SS que Postgres não parseia. Converte pra ISO 8601 BRT.
- Adiciona item "Meus Clientes" no menu sidebar do reseller.
```
