# Sessao Tecnica — 2026-05-01 (Parte 11)

## Resumo
Auditoria e correcao do sistema de tags de contatos.

## Auditoria — o que foi encontrado
- 2 sistemas paralelos: tags de conversa (3 usos) e contact_tags (17k usos)
- contact_count desatualizado: Mensalista 37 real 124, Plano Anual 46 real 165
- Filtros filterTrialStatus e filterPlan rodavam client-side (quebrados com paginacao)
- Filtro aceitava apenas 1 tag por vez

## Correcoes — commit 8ca17b57

### Banco
- Trigger trg_contact_tag_assignments_count: recalcula contact_count automaticamente
- Recontagem aplicada: divergencias zeradas

### API /api/contacts
- tagIds=uuid1,uuid2: filtro AND por multiplas tags
- trialStatus=active|expired|never_tested|converted: server-side via auto_rule
- plan=monthly|annual|lifetime: server-side via auto_rule

### Frontend contacts/page.tsx
- filterTag → filterTags (array com chips removiveis)
- filterPlan e filterTrialStatus agora enviam para API
- Filtragem client-side removida: paginacao mostra totais reais

## Para nicho de produto
- Tags manuais ja funcionam: revendedor cria "Academia", "IPTV", "Software"
- Com multiplas tags agora funciona: filtrar "Academia" + "Mensalista" simultaneamente
- Sem necessidade de campo extra no banco

## Commits
| Hash | Descricao |
|---|---|
| 8ca17b57 | fix(contacts): contact_count correto, filtros server-side, multiplas tags |
