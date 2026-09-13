# Sessão 28 — Incidente Worker + Migração Domínio appcineflick → sharkpanel

Data: 12 de junho de 2026
Commits: 9e27b0b7

---

## Incidente 1: Worker rodando imagem errada (causa raiz do "pending")

**Sintoma:** mensagens do inbox ficavam em "pending", nunca persistidas.

**Diagnóstico:**
- `worker_heartbeats.last_seen` com 88 min de atraso
- 1 job `send_message` preso em "Uncaught: fetch failed"
- 217 `process_webhook` + 18 `send_message` acumulados na fila

**Causa raiz:** serviço `wp_zapflix-worker` rodava imagem **errada** (`zapflix-tech:latest` — servidor Next.js) em vez de `easypanel/wp/zapflix-worker:latest` (worker real, buildado via `Dockerfile.worker`).

**Correção:**
```bash
docker service update --image easypanel/wp/zapflix-worker:latest --force wp_zapflix-worker
```

**Resultado:** heartbeat voltou a segundos, fila drenou, jobs travados processados com sucesso.

---

## Health check automático do worker

- Criado `/root/scripts/check-worker-health.sh`, rodando a cada 5 min via cron
- Detecta: heartbeat morto (>120s) **e/ou** imagem errada do worker
- Auto-corrige via `docker service update --force` (e `--image` se necessário)
- Revalida após 60s; se falhar, envia alerta WhatsApp via Evolution API
  - Requer `whatsappAlertPhone` configurado em Configurações > Notificações
- Validado com simulação real do bug (forçou imagem errada, script detectou e corrigiu em segundos)
- `CLAUDE.md` atualizado com a imagem correta do worker documentada

---

## Incidente 2: Crons silenciosamente quebrados

- 2 crons (`trial-followup` hourly, `promote-expired-trials` a cada 15 min) apontavam para `https://appcineflick.com.br` (domínio antigo)
- `appcineflick.com.br` retorna 308 redirect; `curl` sem `-L` não segue
- Esses crons **nunca executavam** de fato, possivelmente há dias/semanas
- Corrigido: ambos atualizados para `https://app.sharkpanel.com.br`, testados retornando HTTP 200

---

## Migração de domínio: varredura e correção final

Varredura completa identificou referências residuais a `appcineflick.com.br` em banco, env vars e código.

**Banco de dados (4 tabelas):**
- `ai_agents.cta_message` — agente Denise enviava link de checkout antigo para clientes reais ✅ corrigido
- `ai_learned_responses` — 21 respostas aprendidas pelo chatbot ✅ corrigido
- `whatsapp_instances.webhook_url` — 11 instâncias ✅ corrigido
- `whitelabel_settings` — `access_url` + `is_active` ✅ corrigido

**Env vars (3 serviços):**
- `wp_zapflix`: `PUBLIC_WEBHOOK_BASE_URL`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_CHECKOUT_URL`, `NEXTAUTH_URL` ✅
- `wp_zapflix-checkout`: `CHECKOUT_BASE_URL` ✅

**Código (27 arquivos):** resellers, checkout Vite, fallbacks de URL, HTTP-Referer ✅

**Domínio confirmado:**
- `APP_URL=https://app.sharkpanel.com.br`
- `CHECKOUT_URL=https://checkout.sharkpanel.com.br`

**Deploy:** build + update de `wp_zapflix-web`, `wp_zapflix`, `wp_zapflix-worker`, `wp_zapflix-checkout` — todos convergidos sem erro.

---

## Pendências em aberto (carry-forward)

- **guided_funnel_steps** (`step celular_android`): 1 `image_url` ainda em `appcineflick.com.br/uploads/...` — funciona via redirect 308, baixa prioridade; re-upload para MinIO sharkpanel quando conveniente
- **38 short_links** com `target_url` em `checkout.appcineflick.com.br` — mantidos intencionalmente (links já distribuídos a clientes)
- Configurar `whatsappAlertPhone` em Configurações > Notificações para ativar alerta do health check do worker
- 174 `checkout_pix` sem `sold_by_user_id`
- MinIO custom domain
- `audit_logs` retention policy
- Bloquear `/api/migrate/*` em produção
- pgvector/RAG quebrado
- 153 contatos funnel presos em Oferta + PIX
- VPS reboot pendente (security updates)

---

## Aprendizados

- A imagem **correta** do worker é `easypanel/wp/zapflix-worker:latest` (**NÃO** `zapflix-tech:latest`) — `CLAUDE.md` já corrigido
- Sempre validar após reboot ou correção manual:
  ```bash
  docker service inspect wp_zapflix-worker --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
  ```
- Migrações de domínio precisam varrer: banco (todas tabelas `text`/`jsonb`), env vars de **todos** os serviços (não só os que recebem tráfego), código (fallbacks hardcoded), e configs de provedores externos
