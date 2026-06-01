# 00 — Visão Geral do SharkPanel / Zapflix-Tech

> Documento gerado em: 2026-05-20  
> Branch auditado: `main` (commit `80c95596`)  
> Banco: PostgreSQL 5433 — 2,5 GB — 220+ tabelas

---

## O que é

**SharkPanel / Zapflix-Tech** é um SaaS multi-tenant voltado para **revendedores de IPTV** e infoprodutores que vendem e atendem clientes via WhatsApp. Combina em um único produto:

- **Inbox unificado** (atendimento WhatsApp em equipe)
- **CRM + Kanban** de leads
- **IPTV** — geração de testes, ativação, renovação
- **Checkout PIX** (via Amplo Pay)
- **Automações** — funis guiados, drip campaigns, triggers
- **IA** — agentes autônomos, copiloto, sugestões, vision, transcrição
- **Gamificação** para equipe de vendas
- **Painel Master** para administrar workspaces clientes (multi-conta)

---

## Stack técnica

| Camada | Tecnologia |
|--------|-----------|
| Frontend | Next.js 16.0.10 + App Router, React 19.2, Tailwind v4, Radix UI, Recharts, xyflow |
| Backend | Next.js Route Handlers (600+ rotas), Node.js 20 |
| Banco | PostgreSQL (pg pool singleton em `lib/db.ts`), porta 5433 |
| Fila | Jobs Postgres puro (`FOR UPDATE SKIP LOCKED`) — worker dedicado |
| Cache / Broker | Redis (compartilhado com Evolution API) |
| Auth | NextAuth v5 (beta.30) — Credentials provider + JWT httpOnly |
| Mídia | MinIO / AWS S3 (R2/Tigris) via `lib/s3.ts` |
| WhatsApp | Evolution API v2 (instâncias internas) |
| Pagamentos | Amplo Pay (PIX + webhook) |
| TTS | ElevenLabs |
| IA | Claude / OpenAI (via `lib/ai/`) |
| Infra | Docker Swarm + EasyPanel + Traefik (TLS automático) |
| Crons | supercronic (`supercronic.cron`) + possível Vercel duplicado |
| Checkout externo | App separado Vite + tRPC em `checkout/` (MySQL + Amplo Pay) |

---

## URLs de produção

| URL | Serviço |
|-----|---------|
| `appcineflick.com.br` | App principal Next.js |
| `checkout.appcineflick.com.br` | Checkout Vite |
| `claw.appcineflick.com.br` | Admin SPA (Manus.im) |
| `minio.zapflix.shop` | MinIO (objetos) |

---

## Módulos ativos (resumo)

| Módulo | Status |
|--------|--------|
| Inbox / Atendimento | ✅ Completo |
| IPTV Trials + Apps | ✅ Completo |
| Checkout PIX | ✅ Completo |
| Automações / Funis Guiados | ✅ Completo |
| AI Agents | ✅ Completo |
| Gamificação | ✅ Completo |
| Master Panel | ✅ Completo |
| Recorrência | 🔧 Parcial (infra pronta, cobrança automática ausente) |
| Resellers | 🔧 Parcial (withdraw incompleto) |
| Sales Brain | 🔧 Embrionário (UI existe, dados vazios) |
| CRM (deals/pipeline) | 🔧 0 deals em produção |
| Knowledge / RAG | 🔧 Bloqueado por pgvector quebrado |
| Campanhas Drip/Bulk | 🔧 Código pronto, 0 campanhas criadas |
| Marketplace IA | ❌ Esqueleto, 0 agentes |
| Cobrança SaaS recorrente | ❌ Crítico — monetização quebrada |
| API externa v1 | ❌ 0 tokens emitidos |
| Webchat widget | ❌ Implementado, sem snippet embed |
| Afiliados | ❌ Só signup, sem comissionamento |

---

## Dados do banco em produção (2026-05-16)

| Tabela | Linhas |
|--------|--------|
| `messages` | 262.308 |
| `audit_logs` | **2.398.669** ⚠️ sem retenção |
| `processed_events` | 391.720 |
| `worker_runs` | 383.560 |
| `webhook_token_audit` | 250.268 |
| `contacts` | 17.643 |
| `conversations` | 16.062 |
| `payments` | 2.039 (R$ 88.971,73 transacionado) |
| `whatsapp_instances` | 29 (18 conectadas) |
| `iptv_trials` | 1.287 |
| `iptv_generated_tests` | 2.872 |
| `jobs` | 17.571 (16.439 succeeded) |

---

## Receita atual (estimada)

- **Receita SaaS mensal real:** ~R$ 991/mês (2 clientes pagantes reais)
- **Receita potencial:** R$ 2.000–3.500/mês se cobrar workspaces elegíveis
- **Receita IPTV/checkout transacionada:** R$ 88.971 (histórico total)
- **Cobrança SaaS recorrente: NÃO ESTÁ FUNCIONANDO** — veja [[04-pendencias]]

---

## Workspaces em produção

| Workspace | Plano | Paga? | Contatos |
|-----------|-------|-------|----------|
| Shark Panel (dono) | enterprise R$397 | ✅ | 15.235 |
| Fábrica | pro (price=R$0!) | ❌ | 1.089 |
| Eduardo | free | ❌ | 1.001 |
| Personal-Luciano | reseller R$197 | ✅ | 58 |
| Diario-das-Bruxas | enterprise R$397 | ✅ | 44 |
| Denise | starter | ❌ | 116 |

---

## Links internos

- [[01-modulos]] — status detalhado por módulo
- [[02-api-routes]] — catálogo completo de rotas
- [[03-banco-de-dados]] — schema de tabelas
- [[04-pendencias]] — bugs P0/P1 e features faltando
- [[05-fluxos-principais]] — os 5 fluxos centrais
