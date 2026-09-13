# Sessão 27 — Polling PIX, Media Cloud API, Upload Mídia Renovação

Data: 10 de junho de 2026
Commits: f066ce20 to e74c2e09

## Media via Cloud API
- Instâncias Cloud API servem mídia diretamente da URL armazenada
- Evolution API não acessa mídia Meta, fluxo separado por provider
- Fallback correto para instâncias sem evolution_instance_id

## media_url no webhook
- Campo media_url gravado no INSERT de mensagens (ambos os paths)
- Necessário para servir mídia de instâncias Cloud API

## Polling PIX pendentes
- Nova função handleCheckPendingPayments()
- Roda 60s após start, depois a cada 10 minutos
- Consulta checkout_orders status=created há mais de 5min e menos de 24h
- Chama AmploPay API para verificar status real
- COMPLETED/PAID/APPROVED: atualiza para paid + enfileira chatbot_payment_trigger
- CANCELLED/EXPIRED: atualiza para cancelled
- Credenciais lidas do checkout_config com fallback para env vars

## Badge API Oficial no Drawer de Renovação
- Instâncias Cloud API exibem badge verde nos selects e chips
- renewal/config/route.ts retorna campo provider nas instâncias

## Upload direto de mídia no Drawer de Renovação
- Botão Upload no seletor de mídia das mensagens de renovação
- Usa /api/upload/media via FormData
- Aceita audio ou image conforme tipo do dia

## Fixes
- e74c2e09: sold_by_user_id inexistente trocado por reseller_id
- e74c2e09: paid_at removido do UPDATE (coluna não existe)

## Deploy
- wp_zapflix: convergido
- wp_zapflix-web: convergido
- wp_zapflix-worker: convergido (rebuild Dockerfile.worker)

## Pendências
- 174 checkout_pix sem sold_by_user_id
- MinIO custom domain
- audit_logs retention policy
- Bloquear /api/migrate/* em produção
- pgvector/RAG quebrado
- 153 contatos funnel presos em Oferta + PIX
- VPS reboot pendente (security updates)
