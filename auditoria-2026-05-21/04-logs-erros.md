---
title: Logs & Erros — Auditoria 2026-05-21
date: 2026-05-21
---

# 04 — Logs de Produção (últimas 2h)

## Web (`wp_zapflix-web`) — erros recorrentes

| Freq | Mensagem |
|-----:|----------|
| 3× | `[Avatar] Evolution API error: 404` |
| 1× | `[API] Error fetching from Evolution API: error: duplicate key value violates unique constraint "idx_whatsapp_instances_ws_phone"` |
| 1× | `[MediaAPI] Evolution API error: 400` — `Failed to fetch stream from https://mmg.whatsapp.net/...enc` |
| 1× | `severity: 'ERROR'` (suffix do erro anterior) |

### Análise

- **Avatar 404 (×3)** — Evolution API não retorna avatar do contato. Não é fatal, mas o log gritando "error" polui o sinal. Tratar como warning.
- **`duplicate key idx_whatsapp_instances_ws_phone`** — alguma rotina tenta criar uma `whatsapp_instances` para um (workspace, phone) que já existe. Faltando `ON CONFLICT (workspace_id, phone) DO NOTHING/UPDATE`. Ver [[05-bugs-encontrados#BUG-01]].
- **Media 400** — WhatsApp recusa download de mídia criptografada antiga. Falha esperada; logar como `info` ou `warn`, não `error`.

### Warnings relevantes

Nenhum warning fora do ruído normal de `DeprecationWarning` (filtrado).

## Worker (`wp_zapflix-worker`) — erros recorrentes

**Zero erros nas últimas 2h.** ✅

Atividade saudável: ciclo `claimed → succeeded` em 1–40 ms, `pix_followup_cycle_done`, `process_webhook` para `messages.upsert` e `messages_update_ok` (status read/sent).

## Itens de ação

- [ ] 🟠 **P1** Rebaixar avatar 404 e media 400 de `error` para `warn`/`info` — reduz ruído sem perder sinal
- [ ] 🔴 **P0** Investigar e corrigir o `duplicate key` em `whatsapp_instances` (causa raiz da rotina chamadora). Ver [[05-bugs-encontrados]]
- [ ] 🟡 **P2** Adicionar agregador (Loki/Grafana ou simples script) para histograma de erros — hoje só temos `docker service logs | grep`
