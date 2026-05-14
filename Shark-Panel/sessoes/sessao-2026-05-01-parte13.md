# Sessao Tecnica — 2026-05-01 (Parte 13 — Final)

## Resumo
Bugs criticos corrigidos, inbox profissionalizado.

## 1. Bug: conversa sumia apos pagamento — commit 9e471088
- amplopay-webhook escrevia status='resolved'
- CHECK constraint so aceita open|pending|closed
- UPDATE falhava silenciosamente — conversa ficava aberta
- Fix: resolved → closed

## 2. Ordenacao inteligente do inbox — commit f60650fb
- Antes: ordenado por ultima mensagem recente (confuso)
- Depois: cliente respondeu = topo, voce respondeu = baixo
- ORDER BY: last_message_from_me = false primeiro, depois last_message_at DESC
- Cursor de paginacao ajustado: > para 
- Atendente ve quem precisa de atencao sem procurar

## Commits
| Hash | Descricao |
|---|---|
| 9e471088 | fix(payments): status resolved closed no amplopay-webhook |
| f60650fb | feat(inbox): ordenacao inteligente cliente respondeu sobe topo |
