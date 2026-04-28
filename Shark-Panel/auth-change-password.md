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

## Recuperação de senha esquecida

Implementada em 28/04/2026.

**Commits:**
- `9a14ede6` — backend (token, rate limit, envio Evolution, audit)
- `e8f5e1fe` — UI `/esqueci-senha` + `/resetar-senha`
- `4dd33d45` — fixes B-003 (audit cast user_id uuid) + B-004 (Evolution name vs UUID)
- `e97acdbe` — fix B-005 (phone E.164 com 55 BR)

### Fluxo
1. Usuário acessa `/esqueci-senha`
2. Insere email → `POST /api/auth/forgot-password`
3. Sistema gera token (64 chars hex via `crypto.randomBytes(32)`), armazena em `password_reset_tokens` com TTL 1h
4. Manda WhatsApp via Evolution com link `https://app.sharkpanel.com.br/resetar-senha?token=XYZ`
5. Usuário clica link → `/resetar-senha?token=XYZ`
6. Insere nova senha (min 8 chars) → `POST /api/auth/reset-password`
7. Sistema valida token (não usado, não expirado, com `FOR UPDATE`), bcrypt cost 12, transação atualiza senha + marca `used_at`
8. Redirect `/login` + audit log `password.reset.completed`

### Política
- Token válido: 1h
- Rate limit: 3/hora por user_id (conta tokens criados na última hora)
- Resposta sempre `200` em `/forgot-password` (não vaza existência de email)
- Erros 401/410 só em `/reset-password` (token inválido/expirado/já usado)
- Audit logs em ambas operações (`password.reset.requested` + `password.reset.completed`)

### Tabela
`password_reset_tokens (id, user_id, token, expires_at, used_at, created_at, ip)`
FK `ON DELETE CASCADE` pra `nextauth_users(id)`. `user_id` é `text` (espelhando `nextauth_users.id`).

### Seleção da instância de envio
Query em `whatsapp_instances` com prioridade:
1. Instância do workspace `SUPERADMIN_ID`
2. Instância de qualquer workspace de que o user é membro
3. Qualquer outra instância conectada (tie-break por `created_at ASC`)

A URL do `sendText` usa o **nome** da instância (`encodeURIComponent`), não o UUID — ver B-004.

### Riscos conhecidos
- Usuário **sem `phone_whatsapp`** não consegue resetar (débito futuro: fallback Resend/email)
- Telefones armazenados sem código `55 BR` causavam 400 — quick fix em B-005; sanitização na escrita ainda pendente

---

## Pendências futuras

- **Política de complexidade:** atualmente só exige >= 8 chars. Sem regra de maiúscula/número/símbolo.
- **Histórico de senhas:** não há proteção contra reusar última senha (além da nova ≠ atual).
- **Rate limiting (change-password):** rota autenticada não tem throttle hoje (a de forgot-password tem).
- **Fallback de envio do reset:** se Evolution estiver fora ou usuário não tiver phone, não há canal alternativo (email/Resend).
- **B-005 fix completo:** sanitizar phone na escrita + migration de backfill — ver [[bugs]] B-005.
