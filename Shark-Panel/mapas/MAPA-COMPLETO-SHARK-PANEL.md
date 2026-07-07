# Mapa Completo — Shark Panel

> ⚠️ **Mapa de referência vigente: [MAPA-OFICIAL-2026-07-07.md](MAPA-OFICIAL-2026-07-07.md)** (auditoria fresca de 8 dimensões em 2026-07-07 — 899 rotas, 285 tabelas, achados priorizados). Leia aquele primeiro. Esta tabela permanece como visão rápida de status/feature-flags.

## Visão geral dos módulos

| Módulo | Status | Feature Flag | Doc |
|--------|--------|-------------|-----|
| Inbox/Atendimento | ✅ Ativo | — (sempre) | CHATBOT.md |
| IPTV | ✅ Ativo | `iptv` | feature-creditos-iptv.md |
| Financeiro | ✅ Ativo | `billing` | FINANCEIRO.md |
| CRM | ✅ Ativo | — | CRM.md |
| Automações/Funis | ✅ Ativo | `campaigns` | deep-dives/ |
| IA/Agentes | ✅ Ativo | `ai_responses` | APIs.md |
| Gamificação | ✅ Ativo | — | GAMIFICACAO.md |
| Master Panel | ✅ Ativo | superadmin | README-MASTER.md |
| Instâncias WA | ✅ Ativo | — | instancias.md |
| Checkout/Loja | ✅ Ativo | `checkout` | APIs.md |
| Sales Brain | ✅ Ativo | `sales_brain` | deep-dives/deep-sales-brain.md |
| Knowledge/RAG | ✅ Ativo | `knowledge` | deep-dives/deep-knowledge.md |
| Webchat | ✅ Ativo | — | deep-dives/deep-webchat-recorrencia.md |
| Revendedores | ✅ Ativo | — | README-MASTER.md |

## Infraestrutura
- VPS: `69.62.91.79`
- App: `/root/Zapflix-Tech`
- DB: Postgres porta `5433`
- Cache/Queue: Redis (BullMQ)
- Storage: S3 (`lib/s3.ts`)
- WhatsApp: Evolution API
- Deploy: Docker Swarm via EasyPanel

## Conta de teste
- Email: `test@zapflix.dev`
- Workspace: `00000000-0000-0000-0000-000000000002`
- Role: admin
