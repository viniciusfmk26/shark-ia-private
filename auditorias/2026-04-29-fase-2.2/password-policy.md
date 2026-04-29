# Política de senha — proposta 2026-04-29

## Regra atual (estado de prod)

Validação client-side **e** server-side, ambas com a mesma régua: **mínimo 6 caracteres**.

### Locais que validam
| Arquivo | Linha | Contexto |
|---|---|---|
| `app/registro/page.tsx` | 23 | `if (password.length < 6)` — registro de usuário admin/owner |
| `app/registro-revendedor/page.tsx` | 40 | `if (password.length < 6)` — registro de reseller |
| `app/api/resellers/register/route.ts` | 21 | `if (password.length < 6)` — backend do registro reseller |
| `app/api/profile/route.ts` | 54 | `if (new_password.length < 6)` — troca de senha pelo perfil |

(Referenciar `lib/auth/temp-password.ts` separadamente — gera senha temporária no fluxo de aprovação afiliado, não envolve input do usuário.)

## Proposta nova

| Requisito | Valor proposto | Justificativa |
|---|---|---|
| Mínimo de caracteres | **10** | 6 é fraco mesmo pra senhas pessoais; 10 é o mínimo razoável em 2026 |
| Pelo menos 1 letra maiúscula | obrigatório | Aumenta entropia |
| Pelo menos 1 número | obrigatório | Aumenta entropia |
| Pelo menos 1 símbolo | **opcional** | Atrito alto, ganho marginal — deixar como recomendação na UI mas não forçar |
| Comparar com senhas comuns (rockyou top-1000) | **futuro** | Boa prática mas pode ficar fora do MVP da política |

## Regex pronta

```ts
// Mínimo 10 chars, com >=1 maiúscula e >=1 número
const PASSWORD_RE = /^(?=.*[A-Z])(?=.*\d).{10,}$/;
```

### Versão com símbolo opcional + mensagem por requisito
```ts
type PasswordCheck = { ok: boolean; reasons: string[] };

export function validatePassword(p: string): PasswordCheck {
  const reasons: string[] = [];
  if (p.length < 10)        reasons.push('Mínimo 10 caracteres');
  if (!/[A-Z]/.test(p))     reasons.push('Pelo menos 1 letra maiúscula');
  if (!/\d/.test(p))        reasons.push('Pelo menos 1 número');
  return { ok: reasons.length === 0, reasons };
}
```

## Onde adicionar a validação

Sugestão: **centralizar num helper único** em `lib/auth/password-policy.ts` e chamar dos 4 pontos atuais. Evita drift entre client/server.

```
lib/auth/password-policy.ts          ← novo helper único (validatePassword)
app/registro/page.tsx                ← substituir if(<6) por validatePassword
app/registro-revendedor/page.tsx     ← idem
app/api/resellers/register/route.ts  ← idem (camada server)
app/api/profile/route.ts             ← idem (camada server)
```

## Migração / dados existentes
- Usuários atuais com senha `>=6 && <10` continuam logando — a nova régua só é aplicada em **criação** e **troca**.
- Considerar forçar troca no próximo login pra usuários com senha curta? **Não recomendado** sem aviso prévio — quebra UX.
- Alternativa: banner discreto "Sua senha tem menos de 10 caracteres, atualize quando puder" no /perfil.

## UI sugerida (não-bloqueante)
- Indicador de força em tempo real (3 níveis: fraca/ok/forte)
- Lista de requisitos com check verde quando atendido
- Botão "Mostrar senha" pra reduzir digitação errada

## Tempo estimado
- Helper + 4 substituições: 30 min
- UI de força: +1h (opcional)
- Testes: 15 min
- **Total mínimo: ~30-45min**

## Pendências de decisão pra Vinicius
1. Confirmar 10 chars como mínimo (pode aumentar pra 12 se quiser ser conservador).
2. Confirmar que símbolo fica opcional.
3. Decidir sobre banner pra usuários legados.
