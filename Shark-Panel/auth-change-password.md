# auth-change-password.md — Troca de senha autenticada

> Rota e UI pra usuário logado trocar a própria senha. Criado em 28/04/2026 como pré-requisito do B-001 fix (afiliados aprovados recebem senha temporária e precisam de um caminho pra trocar).
>
> Relacionado: [[bugs]] (B-001) · [[feature-afiliados]]

---

## Endpoints

### `POST /api/auth/change-password`
**Auth:** sessão NextAuth (cookie). 401 se sem sessão.

**Body:**
```json
{ "currentPassword": "string", "newPassword": "string" }
```

**Validações:**
- Ambos os campos obrigatórios e do tipo string
- `newPassword.length >= 8`
- `newPassword !== currentPassword`
- `bcrypt.compare(currentPassword, user.password)` precisa bater

**Sucesso:** `200` `{ "ok": true }`. UPDATE em `nextauth_users.password` com `bcrypt.hash(newPassword, 12)` e log em `audit_logs` com `action='auth.password_changed'`.

**Erros:**
- `400` — campos faltando, senha curta, ou nova == atual
- `400` — "Conta sem senha definida" (caso de B-001 antigo, não deve mais ocorrer)
- `401` — não autenticado OU senha atual incorreta
- `500` — falha interna

---

## UI

### `/configuracoes/senha`
Página dashboard simples com 3 campos:
- Senha atual
- Nova senha (placeholder "Mínimo 8 caracteres")
- Confirmar nova senha (validação cliente: precisa bater)

Submit → `POST /api/auth/change-password`. Toasts pra feedback. Após sucesso: limpa form, toast "Senha alterada com sucesso 🦈" e redireciona pra `/` em 800ms.

### Acesso
- Botão **"Trocar senha"** (ícone `KeyRound`) no header do `/reseller`, ao lado do "Solicitar Saque"
- Link no WhatsApp pós-aprovação (B-001 fix): `https://appcineflick.com.br/configuracoes/senha`

---

## Fluxo do afiliado novo (uso típico)

1. Afiliado se cadastra em `/afiliado/cadastro` (sem senha)
2. Vinicius aprova em `/master/revendedores`
3. Afiliado recebe WhatsApp com email + senha temporária + link `/configuracoes/senha`
4. Afiliado faz login com a temp
5. Acessa `/configuracoes/senha`, troca pra senha pessoal
6. Senha temp deixa de ser válida no banco

---

## Implementação

| Arquivo | Função |
|---|---|
| `lib/auth/temp-password.ts` | Gerador de senhas legíveis com `crypto.randomBytes`, alfabeto sem ambíguos (`0/O`, `1/I/l` excluídos) |
| `app/api/auth/change-password/route.ts` | POST handler, bcrypt cost 12, audit log |
| `app/(dashboard)/configuracoes/senha/page.tsx` | UI com 3 inputs + validações cliente |
| `app/(dashboard)/reseller/page.tsx` | Link "Trocar senha" no header |

Commit: `c92dc777` em `viniciusfmk26/Zapflix-Tech`.

---

## Pendências futuras

- **Esqueci minha senha:** ainda não existe. Hoje, usuário sem senha precisa pedir reset manual ao Vinicius (que pode rodar approve novamente — gera nova temp).
- **Política de complexidade:** atualmente só exige >= 8 chars. Sem regra de maiúscula/número/símbolo.
- **Histórico de senhas:** não há proteção contra reusar última senha (além da nova ≠ atual).
- **Rate limiting:** rota não tem throttle hoje.
