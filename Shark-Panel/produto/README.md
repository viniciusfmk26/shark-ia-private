# Produto — Documentação

## Arquivos
- [[auditoria-completa-2026-04-30]] — Auditoria completa (banco, fluxos, problemas, glossário)
- [[auditoria-config-2026-04-30]] — Configurações: env vars, secrets, instâncias, evolution, planos
- [[configuracoes-e-secrets]] — Mapa de secrets, env vars faltando, hardcoded scan (sessão noturna 2)

## Resumo executivo (auditoria 2026-04-30)
- 192 tabelas, 1,5 GB · 12.716 contatos · 170k mensagens · **1.337 subscriptions ativas (era 317 antes do backfill)**
- 75 tabelas vazias (~40% do schema)
- 3 sistemas de pagamento paralelos (payments / iptv_payments / workspace_plan_payments)
- ~~1.307 pagamentos (88%) sem subscription~~ → resolvido na sessão noturna (+1.020 backfill)
- ~~21 de 25 crons não agendados~~ → **CORREÇÃO**: estava errado. Crons estavam todos no `Dockerfile.cron` (sem `supercronic.cron`). Refatorado e adicionado `recorrencia-sync` (era o único faltando)
- Estado de "cliente ativo" desnormalizado em 4 lugares (próx: `lib/server/customer-lifecycle.ts`)

## Próximos passos priorizados
1. **Definir env vars críticas no Easypanel**: OPENAI_API_KEY, AMPLOPAY_PUBLIC_KEY/SECRET_KEY, NEXT_PUBLIC_APP_URL, ALERT_PHONE_NUMBER
2. **Mover ELEVENLABS api_key** (atualmente exposta em `workspace_settings.elevenlabs.api_key`) para env var
3. **Centralizar customer lifecycle** em `lib/server/customer-lifecycle.ts` (consolidar 4 lugares)
4. **Implementar plano SaaS** com limites por workspace (max_contacts, max_instances, mensagens/mês)
5. **Limpar duplicatas WhatsApp** (Lucía, cubot, Marsbaks, Samsung A30, suporte, Mayara Kook em múltiplos workspaces)
6. **Configurar planos para server=1 (megabox)** no checkout
7. **Adicionar auth** em `/api/debug/*` e `/api/migrate/*`
8. **Limpar env vars legadas**: POSTGRES_URL, EVOLUTION_BASE_URL/TOKEN, MIGRATE_SECRET, CRON_SECRET (consolidar com CRON_TOKEN)
