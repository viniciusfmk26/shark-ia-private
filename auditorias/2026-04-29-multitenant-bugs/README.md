# Auditoria 29/04/2026 — Deep-Dive + 4 Fixes Críticos

## Contexto
Sessão pós-Fase 2.2: deep-dive em 8 áreas (Automações, Funis, Drip, IA, Knowledge,
Follow-up, Webchat/Recorrência, Sales Brain) revelou:

## Bugs descobertos e CORRIGIDOS
1. ✅ **B-009** (config) — Anual/Semestral apontavam pra package de 3 meses
2. ✅ **B-AMPLOPAY-001** — webhook não populava iptv_* em subscriptions (169 backfilladas)
3. ✅ **B-DRIP-001** — cron drip-campaigns INSERT em coluna inexistente (payload_json)
4. ✅ **B-MULTITENANT-001** — 5 endpoints IA sem WHERE workspace_id

## Bugs descobertos NÃO corrigidos
- pgvector não instalado (knowledge_chunks.embedding é text)
- Pipeline AmploPay → won nunca chamado (2.600 oportunidades, 0 won/lost)
- Crons órfãos / tabelas dead

## Arquivos
- DEEP-DIVE-INDEX.md — sumário executivo
- deep-automations.md (424 linhas)
- deep-funnels.md (401 linhas)
- deep-drip.md (309 linhas)
- deep-ia.md (466 linhas)
- deep-knowledge.md (327 linhas)
- deep-followup-scheduled.md (368 linhas)
- deep-webchat-recorrencia.md (394 linhas)
- deep-sales-brain.md (360 linhas)

Total: 3.252 linhas de documentação técnica.

## Commits relacionados
- 8f010f88 — F-001 Fase 2.2 (Revendedor ativa cliente IPTV)
- edff115d — B-AMPLOPAY-001 fix
- ec2061b9 — Drip cron fix
- 962ecdb4 — Multi-tenant fix
