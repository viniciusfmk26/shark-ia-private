# F-003 — Landing Page + Quiz Whitelabel

## Visão
Cada workspace tem landing customizável + quiz que detecta perfil do visitante e direciona pra plano ideal.

## URLs
- `/[workspace-slug]` (landing)
- `/[workspace-slug]/quiz?ref=X` (quiz, `ref` = reseller_id pra atribuição)
- `/[workspace-slug]/resultado/[profile-id]` (resultado + CTA pro plano recomendado)

## 5 Perfis detectados
1. **Maratonista de Filme** — foco filmes/séries, prefere catálogo VOD massivo
2. **Esportista** — foco canais esporte ao vivo, PPV, multi-câmeras
3. **Família Conectada** — multi-tela, infantil, controle parental
4. **Curioso Adulto** — filmes 18+, canais variados, sem restrição
5. **Testador** — quer trial primeiro, plano curto antes de fechar mensal/anual

## Schema (6 tabelas)

```sql
-- 1. Landing customizável por workspace
CREATE TABLE landing_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  hero_title TEXT,
  hero_subtitle TEXT,
  hero_video_url TEXT,
  primary_color TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Quiz por workspace (1:1 nesta primeira versão)
CREATE TABLE quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL,
  title TEXT NOT NULL,
  intro TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Perguntas do quiz
CREATE TABLE quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id),
  question TEXT NOT NULL,
  order_idx INT DEFAULT 0
);

-- 4. Respostas com pesos pra cada perfil
CREATE TABLE quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES quiz_questions(id),
  answer_text TEXT NOT NULL,
  profile_scores JSONB DEFAULT '{}',
  order_idx INT DEFAULT 0
);

-- 5. Definição dos 5 perfis (configurável por workspace)
CREATE TABLE quiz_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL,
  profile_key TEXT NOT NULL,           -- 'maratonista' | 'esportista' | 'familia' | 'curioso' | 'testador'
  name TEXT NOT NULL,
  description TEXT,
  recommended_plan_slug TEXT,
  UNIQUE(workspace_id, profile_key)
);

-- 6. Tracking das respostas/leads
CREATE TABLE quiz_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL,
  reseller_id UUID,                    -- veio via ?ref=
  phone TEXT,                          -- captura opcional pra remarketing
  answers JSONB,                       -- {question_id: answer_id}
  detected_profile TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices úteis
CREATE INDEX idx_quiz_questions_quiz ON quiz_questions(quiz_id, order_idx);
CREATE INDEX idx_quiz_answers_question ON quiz_answers(question_id, order_idx);
CREATE INDEX idx_quiz_responses_workspace_created ON quiz_responses(workspace_id, created_at DESC);
CREATE INDEX idx_quiz_responses_reseller ON quiz_responses(reseller_id) WHERE reseller_id IS NOT NULL;
```

## Detecção de perfil
Cada `answer` tem `profile_scores` no formato:

```json
{
  "maratonista": 2,
  "esportista": 0,
  "familia": 1,
  "curioso": 0,
  "testador": 0
}
```

No final do quiz, soma scores de todas answers escolhidas. **Perfil vencedor = maior score** (com tiebreaker em ordem de prioridade fixa: testador > familia > esportista > maratonista > curioso, pra evitar empates ambíguos).

### Pseudocódigo
```ts
function detectProfile(selectedAnswers: Answer[]): string {
  const totals = { maratonista: 0, esportista: 0, familia: 0, curioso: 0, testador: 0 };
  for (const a of selectedAnswers) {
    for (const [k, v] of Object.entries(a.profile_scores || {})) {
      totals[k] = (totals[k] ?? 0) + v;
    }
  }
  const priority = ['testador', 'familia', 'esportista', 'maratonista', 'curioso'];
  return priority.reduce((best, key) => totals[key] > totals[best] ? key : best, priority[0]);
}
```

## Routes

### Públicas (sem auth)
- `GET  /api/public/[slug]/landing`         → retorna landing_page + planos do workspace
- `GET  /api/public/[slug]/quiz`            → retorna quiz + questions + answers (sem profile_scores expostos)
- `POST /api/public/[slug]/quiz/respond`    → recebe respostas, calcula perfil, grava em quiz_responses, retorna profile + plano recomendado

### Admin (auth obrigatório, escopo workspace)
- `GET    /api/admin/landing`                → landing do workspace ativo
- `PUT    /api/admin/landing`                → atualiza hero/cores/video
- `GET    /api/admin/quiz`                   → quiz + questions + answers + profiles
- `POST   /api/admin/quiz/questions`         → cria pergunta
- `PUT    /api/admin/quiz/questions/[id]`    → edita pergunta
- `DELETE /api/admin/quiz/questions/[id]`
- `POST   /api/admin/quiz/answers`           → cria resposta com profile_scores
- `PUT    /api/admin/quiz/answers/[id]`
- `DELETE /api/admin/quiz/answers/[id]`
- `GET    /api/admin/quiz/profiles`          → 5 perfis do workspace
- `PUT    /api/admin/quiz/profiles/[key]`    → edita nome/descrição/plano recomendado
- `GET    /api/admin/quiz/responses`         → lista leads (filtro por reseller, perfil, data)

## Componentes

### Públicos
- `app/[workspace-slug]/page.tsx`            — landing
- `app/[workspace-slug]/quiz/page.tsx`       — quiz multi-step (client component, mantém estado)
- `app/[workspace-slug]/resultado/[profile]/page.tsx` — resultado + CTA
- `components/landing/HeroSection.tsx`
- `components/landing/PlansGrid.tsx`
- `components/quiz/QuizStepper.tsx`
- `components/quiz/QuizQuestion.tsx`
- `components/quiz/QuizProgressBar.tsx`
- `components/quiz/ResultCard.tsx`

### Admin
- `app/admin/landing/page.tsx`               — editor com preview
- `app/admin/quiz/page.tsx`                  — lista perguntas/respostas
- `app/admin/quiz/profiles/page.tsx`         — config dos 5 perfis
- `app/admin/quiz/responses/page.tsx`        — leads capturados
- `components/admin/QuizQuestionEditor.tsx`  — drag-and-drop ordering
- `components/admin/ProfileScoresInput.tsx`  — sliders 0-3 por perfil

## Tempo estimado
| Bloco | Horas |
|---|---|
| Schema + seed (5 perfis padrão) | 1h |
| API routes (CRUD admin + público) | 3h |
| Landing UI | 3h |
| Quiz UI (multi-step) | 4h |
| Resultado UI | 1h |
| Admin (configurar quiz) | 3h |
| **Total versão admin completa** | **~15h** |
| OU MVP com Uniflix hardcoded (sem admin) | ~12h |

## Pré-requisitos
- F-001 Fase 2.2 ENTREGUE ✅
- B-006 corrigido (rotas AmploPay legadas)
- F-002 ideal (manual primeiro pra cobrir o caso "quer testar antes de comprar")

## Notas de implementação
- `slug` em `landing_pages` deve bater com workspace.slug (ou ser independente pra permitir multi-domínio futuro)
- `profile_scores` aceitar qualquer chave permite expandir além de 5 perfis sem migração
- `quiz_responses.answers` JSONB facilita análise sem normalizar 1 row por resposta
- Considerar rate-limit no `POST /quiz/respond` pra evitar flood de leads falsos
- `?ref=` deve persistir em cookie/sessionStorage durante o quiz pra atribuir ao reseller correto no checkout
