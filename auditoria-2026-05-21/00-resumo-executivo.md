---
title: Auditoria Zapflix-Tech — Resumo Executivo
date: 2026-05-21
sistema: Zapflix-Tech
---

# Resumo Executivo — Auditoria 2026-05-21

> Janela: produção `wp_zapflix-web` + `wp_zapflix-worker` (Docker Swarm em easypanel).
> Banco: `zapflix@localhost:5433` (Postgres 17).

## 🩺 Score de saúde: **58 / 100**

Sistema operacional e funcionalmente saudável (worker processando, instâncias conectadas, banco respondendo, sem queries longas). Mas **exposição de superfície de rede crítica** e dívida operacional (audit_logs crescendo sem retenção, web reiniciando, instâncias desconectadas) puxam o score para baixo.

| Eixo | Nota | Comentário |
|------|------|------------|
| Infra runtime | 70 | Web reiniciou 4× em 19h; worker estável agora (falhou 3× há 32h) |
| Banco | 75 | 2.75 GB no total; audit_logs domina (874 MB / 2.86 M linhas), sem retenção |
| Segurança rede | 25 | 🔴 Postgres, Redis, MinIO, MySQL e Next expostos em 0.0.0.0 |
| Segurança app | 70 | Debug e migrate protegidos por `requireSuperAdmin`, mas com secrets em literal |
| Logs/erros | 65 | Erros recorrentes do Evolution API (avatar 404, mídia 400, dup key) |
| Filas/worker | 80 | 18 156 jobs ok, **7 dead jobs** pendentes, fluxo normal |
| Integridade dados | 90 | 0 conversas com unread > 0 sem contact_id; 4 órfãs sem unread |
| Instâncias WhatsApp | 60 | 14 connected / 15 disconnected — metade do parque desligado |

## 🔴 Top 5 problemas críticos

1. **Postgres/Redis/MinIO/MySQL expostos publicamente em 0.0.0.0** — risco de comprometimento direto. Exigem firewall ou bind em `127.0.0.1`. [[03-segurança]]
2. **`audit_logs` sem política de retenção** — 874 MB, 2.86 M linhas, crescendo ~100 k/dia. Em 90 dias dobra o banco. [[02-banco]]
3. **`wp_zapflix-web` reiniciou 4× nas últimas 19 h** — sem stack trace claro nos logs grep'ados; investigar OOM ou exceção não tratada. [[01-infraestrutura]] [[04-logs-erros]]
4. **Erro recorrente `duplicate key idx_whatsapp_instances_ws_phone`** — alguma rota tenta inserir instância já existente sem `ON CONFLICT`. [[05-bugs-encontrados]]
5. **Secrets hardcoded em rotas `/api/migrate/*`** — strings como `'zapflix-diag-secret'`, `'zapflix-check-inst'`. RBAC já está na frente, mas é defesa em profundidade quebrada. [[03-segurança]]

## ✅ Pontos saudáveis

- Worker processa < 50 ms por job em média, sem erros nas últimas 2 h. [[06-saude-worker]] (não criado — ver [[01-infraestrutura]])
- Zero queries longas (>30 s) no momento da coleta.
- Zero conversas unread sem `contact_id` — correlação contato↔conversa íntegra. [[05-bugs-encontrados]]
- 10 GB de memória disponível, disco em 30 % de uso.
- Endpoints `/api/debug/*` e `/api/migrate/*` protegidos por `requireSuperAdmin`.

## 📁 Arquivos desta auditoria

- [[00-resumo-executivo]] — este arquivo
- [[01-infraestrutura]] — Docker, recursos, restarts
- [[02-banco]] — tabelas, contagens, dead tuples, crescimento
- [[03-segurança]] — portas, endpoints, secrets
- [[04-logs-erros]] — erros recorrentes
- [[05-bugs-encontrados]] — bugs novos com severidade
- [[06-plano-de-acao]] — ações P0/P1/P2/P3

## ⚙️ Próximo passo recomendado

Executar o **P0** do [[06-plano-de-acao]]: firewall nos quatro datastores expostos. Isso sozinho leva o score de segurança de rede de 25 → 80 e o score global para ~75.
