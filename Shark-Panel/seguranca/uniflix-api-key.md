# Uniflix External API Key

## Status
✅ Rotacionada em 30/04/2026

## Localização
- Env var: `UNIFLIX_EXTERNAL_API_KEY`
- Serviço: `wp_zapflix-web` (Easypanel + Docker Swarm)
- Histórico: key antiga `uniflix2026` estava hardcoded no código (git history). Removida em commit `f66dd185`.

## Key atual
Guardada APENAS no Easypanel (env var). Não está no código nem no git.
Para consultar: `docker service inspect wp_zapflix-web --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' | grep UNIFLIX`

## Endpoints protegidos
- `GET /api/external/metricas` — métricas de vendas/faturamento Uniflix
- `GET /api/external/pedidos` — listagem de pedidos Uniflix

## Como usar (quando tiver cliente)
Header obrigatório em todas as requests:
x-api-key: <valor da env var>

## Rotação futura
1. Gerar nova key: `openssl rand -hex 32`
2. Atualizar no Easypanel → Deploy
3. Avisar o cliente Uniflix para atualizar o header
4. Confirmar que nova key retorna 200 e antiga retorna 401
5. Atualizar esta nota
