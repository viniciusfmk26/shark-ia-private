# Auditoria 2026-04-29 — Fase 2.2 entregue + mapeamento completo

> Snapshot dos arquivos gerados durante a sessão noturna 28-29/04/2026.
> Conteúdo é referência histórica — não atualizado depois desta data.
> Para o estado vivo do produto, ver as notas em `Empresa/` e `Shark-Panel/`.

## Índice

### Mapeamento completo do sistema (gerado pela auditoria)
- [`MAPA-COMPLETO-SHARK-PANEL.md`](./MAPA-COMPLETO-SHARK-PANEL.md) — visão geral em 17 seções
- [`mapa-rotas.md`](./mapa-rotas.md) — frontend (92 pages) + backend (595 APIs)
- [`mapa-banco.md`](./mapa-banco.md) — schema Postgres (192 tabelas, top volumes, relações)
- [`mapa-permissoes.md`](./mapa-permissoes.md) — RBAC + matriz role × ações
- [`mapa-fluxos.md`](./mapa-fluxos.md) — 9 fluxos críticos E2E código-a-código
- [`mapa-integracoes.md`](./mapa-integracoes.md) — Sigma, AmploPay, Evolution, MinIO, Redis, etc.

### Brief da sessão
- [`MORNING-BRIEF-29-04.md`](./MORNING-BRIEF-29-04.md) — resumo da sessão noturna pra Vinicius
- [`auditoria-noturna.md`](./auditoria-noturna.md) — descobertas técnicas (BLOCO 3.4.7)

### Bugs investigados
- [`b-009-sigma-ids.md`](./b-009-sigma-ids.md) — IDs Sigma corretos pra annual/semiannual + SQL pronto
- [`b-amplopay-001-investigation.md`](./b-amplopay-001-investigation.md) — webhook AmploPay não popula subscriptions.iptv_*

### Specs detalhadas
- [`spec-f002-manual.md`](./spec-f002-manual.md) — Manual estilo Netflix (~3-4h)
- [`spec-f003-landing-quiz.md`](./spec-f003-landing-quiz.md) — Landing + Quiz Whitelabel (~12-15h)
- [`password-policy.md`](./password-policy.md) — política de senha forte proposta (~30-45min)

### Mudanças não-commitadas (referência)
- [`changes-detail.md`](./changes-detail.md) — detalhamento das mudanças do working tree pré-commit Fase 2.2
- [`commit-bloco-3.5.txt`](./commit-bloco-3.5.txt) — mensagem de commit usada/sugerida

## Updates aplicados nas notas vivas

A partir desta auditoria, foram atualizados:

- [[../../Shark-Panel/feature-creditos-iptv]] — Fase 2.2 marcada como ✅ entregue
- [[../../Shark-Panel/bugs]] — adicionados B-009, B-AMPLOPAY-001, D-SIGMA-painel, B-PARSER-001 (resolvido)
- [[../../Empresa/decisoes-arquiteturais]] — ADRs 003 (provisionSigmaByPackage) e 004 (INSERT subscription FATAL); ADR-001 marcada como implementação completa
- [[../../Empresa/roadmap.md]] — F-001 Fase 2.2 entregue + opções A/B/C pra Fase 3

## Estatísticas

- **3.500+ linhas** de documentação técnica nova
- **2 arquivos** commitados na Fase 2.2 (`components/layout/sidebar-nav.tsx` + `lib/sigma/provision.ts`)
- **4 ADRs** ativos (001 a 004)
- **4 bugs novos** catalogados (B-009, B-AMPLOPAY-001, D-SIGMA-painel + B-PARSER-001 resolvido)
- **3 specs** prontas pra futuras sessões (F-002, F-003, password-policy)
