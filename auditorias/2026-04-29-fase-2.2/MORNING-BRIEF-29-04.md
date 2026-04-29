# 🦈 Brief Matinal — 29/04/2026

## Status BLOCO 3.4.7 — F-001 Fase 2.2
- ✅ Sistema deployed e healthy
- ✅ Saldo restaurado (1 crédito)
- ✅ Subscriptions gravando corretamente
- ✅ Sigma criação OK
- ✅ Item "Meus Clientes" adicionado ao menu sidebar do reseller
- ⚠️ **2 arquivos ainda NÃO commitados** (`sidebar-nav.tsx` + `lib/sigma/provision.ts`) — pronto pra commit

## ⚠️ Aguarda decisão tua (de manhã)
1. Painel admin **sharks10.top** — qual conta usar?
2. Aprovar fix **B-009** (planos Anual/Semestral)?
3. Aprovar fix **B-AMPLOPAY-001** (rotas legadas)?
4. Confirmar política de senha proposta (10 chars + 1 maiúscula + 1 número)
5. **NOVO:** confirmar que **NÃO** vamos migrar `reseller_levels` (já está OK em prod, vide investigação)

---

## Trabalho adiantado nesta auditoria

### 1. F-003 (Landing+Quiz Whitelabel) — spec completa
- Arquivo: **`/root/spec-f003-landing-quiz.md`**
- 6 tabelas (`landing_pages`, `quizzes`, `quiz_questions`, `quiz_answers`, `quiz_profiles`, `quiz_responses`) com SQL pronto
- 5 perfis definidos (Maratonista, Esportista, Família, Curioso, Testador)
- Algoritmo de detecção com pseudocódigo + tiebreaker por prioridade
- Routes públicas (3) + admin (10+) listadas
- Componentes mapeados (públicos + admin)
- Tempo: ~15h versão completa, ~12h MVP Uniflix hardcoded

### 2. `reseller_levels` — investigação (achado importante)
- Arquivo: **`/root/reseller-levels-investigation.md`**
- 🚨 **A premissa antiga estava errada:** coluna `level` JÁ EXISTE em prod
- Schema atual: `level varchar(20) DEFAULT 'bronze' NOT NULL`
- Junto com `total_sales`, `commission_rate (numeric)`, `perks (jsonb)`, `updated_at`
- **Nenhum ALTER TABLE necessário.**
- Ação proposta: atualizar memória de sessões + opcionalmente promover pra enum nativo

### 3. Política de senha — proposta detalhada
- Arquivo: **`/root/password-policy.md`**
- Estado atual: `password.length < 6` em 4 lugares (registro, registro-revendedor, api/profile, api/resellers/register)
- Proposta: mínimo 10 chars + 1 maiúscula + 1 número (símbolo opcional)
- Regex pronta: `/^(?=.*[A-Z])(?=.*\d).{10,}$/`
- Helper centralizado proposto em `lib/auth/password-policy.ts`
- Tempo: ~30-45min implementação

### 4. Catálogo de mudanças não-commitadas
- Arquivo: **`/root/changes-detail.md`** (+ `/root/changes-summary.txt`)
- 2 arquivos: `components/layout/sidebar-nav.tsx` (+1) e `lib/sigma/provision.ts` (+117/-2)
- Detalhamento por bloco:
  - **2.1** Comentários debug deixados como referência (decidir antes de commit)
  - **2.2** Fix de data PT-BR (`parseSigmaDate`) — Sigma retorna `DD/MM/YYYY HH:MM:SS` que Postgres rejeita
  - **2.3** Nova função `provisionSigmaByPackage` (~88 linhas) — pula lookup `sigma_plan_mapping` legado
- Mensagem de commit sugerida incluída no doc

---

## Tarefas das sessões anteriores que NÃO foram cobertas nesta rodada

Os documentos abaixo foram listados em pré-tarefas mas não estavam presentes em `/root/` quando iniciei esta sequência (6→10). Caso tenham sido produzidos em outra sessão, conferir manualmente:

- `/root/trabalho-noturno-29-04.md`
- `/root/commit-bloco-3.5.txt`
- `/root/spec-f002-manual.md`
- `/root/obsidian-updates-29-04.md`
- Investigação **B-AMPLOPAY-001** (arquivo+linha do bug)
- IDs Sigma candidatos pra **B-009** (6m/12m + SQL)

Se nenhum desses existir ainda, são candidatos pra próxima rodada ou pra você puxar manualmente quando puder.

---

## Tempo estimado de trabalho de manhã

| Tarefa | Tempo |
|---|---|
| Validar painel admin (escolher conta sharks10.top) | 5 min |
| Revisar 2 arquivos não-commitados + decidir comentários debug | 10 min |
| Commit Fase 2.2 (mensagem pronta em `changes-detail.md`) | 5 min |
| Aplicar fixes B-009 + B-AMPLOPAY (depende de decisão) | ~1h |
| Atualizar Obsidian | 30 min |
| **Total mínimo (sem fixes B-X):** | **~50min** |
| **Total com fixes:** | **~2h** |

---

## Backlog próxima sessão
- F-002 (Manual): ~3-4h (spec ainda não criado nesta auditoria)
- F-003 (Landing+Quiz): ~12-15h (**spec pronta** — pode começar)
- Política senha: ~30-45min (**spec pronta**)
- `reseller_levels`: nada a fazer (investigação concluída — ✅)
- B-009 / B-AMPLOPAY-001: depende de aprovação tua

---

## Arquivos prontos pra ti revisar

| Arquivo | Status |
|---|---|
| `/root/auditoria-noturna.md` | ✅ pré-existente (de sessão anterior) |
| `/root/spec-f003-landing-quiz.md` | ✅ **NEW** |
| `/root/reseller-levels-investigation.md` | ✅ **NEW** |
| `/root/password-policy.md` | ✅ **NEW** |
| `/root/changes-detail.md` | ✅ **NEW** |
| `/root/changes-summary.txt` | ✅ **NEW** (output bruto de `git diff --stat`) |
| `/root/MORNING-BRIEF-29-04.md` | ✅ **NEW** (este) |

---

## Resumo em uma frase
**Fase 2.2 funcionando, 2 arquivos prontos pra commit, F-003 e política de senha 100% specadas, e a "tarefa do `reseller_levels`" virou não-tarefa porque a coluna já existe — uma decisão a menos pra ti.**
