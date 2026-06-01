# 02 — Catálogo de Rotas API

> Total: **740 arquivos `route.ts`** (incluindo sub-rotas)  
> Prefixo base: `/api/`  
> Atualizado: 2026-05-20

---

## Autenticação

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/auth/[...nextauth]` | GET/POST | Handler NextAuth v5 |
| `/api/auth/signup` | POST | Criação de conta |
| `/api/auth/logout` | POST | Logout |
| `/api/auth/forgot-password` | POST | Esqueci senha |
| `/api/auth/reset-password` | POST | Resetar senha |
| `/api/auth/change-password` | POST | Alterar senha |
| `/api/auth/check-status` | GET | Status da conta |
| `/api/auth/callback` | GET | Callback OAuth |

---

## Inbox / Atendimento

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/inbox/conversations` | GET/POST | Listar/criar conversas |
| `/api/inbox/conversations/[id]` | GET/PATCH/DELETE | Conversa específica |
| `/api/inbox/conversations/[id]/messages` | GET/POST | Mensagens da conversa |
| `/api/inbox/conversations/[id]/messages/[messageId]/delete` | DELETE | Deletar mensagem |
| `/api/inbox/conversations/[id]/send` | POST | Enviar mensagem |
| `/api/inbox/conversations/[id]/status` | PATCH | Alterar status (open/closed/pending) |
| `/api/inbox/conversations/[id]/assign` | POST | Atribuir a agente |
| `/api/inbox/conversations/[id]/transfer` | POST | Transferir conversa |
| `/api/inbox/conversations/[id]/transfer-instance` | POST | Transferir para outra instância |
| `/api/inbox/conversations/[id]/archive` | POST | Arquivar |
| `/api/inbox/conversations/[id]/ai-mode` | PATCH | Ativar/desativar modo IA |
| `/api/inbox/conversations/[id]/ai-suggestion` | POST | Sugestão de resposta por IA |
| `/api/inbox/conversations/[id]/summarize` | POST | Resumir conversa (IA) |
| `/api/inbox/conversations/[id]/summary` | GET | Buscar resumo cacheado |
| `/api/inbox/conversations/[id]/suggest` | POST | Sugerir próxima ação |
| `/api/inbox/conversations/[id]/note` | POST | Adicionar nota interna |
| `/api/inbox/conversations/[id]/tags` | GET/POST | Tags da conversa |
| `/api/inbox/conversations/[id]/funnels-sent` | GET | Funis disparados para este contato |
| `/api/inbox/conversations/[id]/pending-automations` | GET | Automações pendentes |
| `/api/inbox/conversations/[id]/pending-jobs-count` | GET | Jobs pendentes |
| `/api/inbox/conversations/[id]/cancel-followups` | POST | Cancelar follow-ups |
| `/api/inbox/conversations/[id]/charge-pix` | POST | Cobrar PIX diretamente |
| `/api/inbox/conversations/[id]/send-product` | POST | Enviar produto no chat |
| `/api/inbox/conversations/[id]/schedule` | POST | Agendar mensagem |
| `/api/inbox/conversations/[id]/pin` | POST | Fixar conversa |
| `/api/inbox/conversations/[id]/favorite` | POST | Favoritar |
| `/api/inbox/conversations/[id]/mark-read` | POST | Marcar como lido |
| `/api/inbox/conversations/[id]/mark-unread` | POST | Marcar como não lido |
| `/api/inbox/conversations/[id]/mute` | POST | Silenciar |
| `/api/inbox/conversations/[id]/block` | POST | Bloquear contato |
| `/api/inbox/conversations/[id]/clear` | POST | Limpar histórico |
| `/api/inbox/conversations/[id]/delete` | DELETE | Deletar conversa |
| `/api/inbox/conversations/[id]/typing` | POST | Indicar digitação |
| `/api/inbox/conversations/[id]/presence` | POST | Atualizar presença |
| `/api/inbox/conversations/[id]/avatar` | GET | Avatar do contato |
| `/api/inbox/conversations/[id]/message-statuses` | GET | Status de entrega |
| `/api/inbox/send` | POST | Envio rápido |
| `/api/inbox/messages` | GET | Buscar mensagens |
| `/api/inbox/tags` | GET/POST | Tags do inbox |
| `/api/inbox/quick-replies` | GET/POST | Respostas rápidas |
| `/api/inbox/intent` | POST | Detectar intenção |
| `/api/inbox/last-payment` | GET | Último pagamento do contato |
| `/api/inbox/alerts` | GET | Alertas do inbox |
| `/api/inbox/churn-alerts` | GET | Alertas de churn |
| `/api/inbox/global-block` | POST | Bloquear globalmente |
| `/api/inbox/typing` | POST | Typing global |
| `/api/sse/inbox` | GET | SSE (Server-Sent Events) do inbox |

---

## Contatos

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/contacts` | GET/POST | Listar/criar contatos |
| `/api/contacts/[id]` | GET/PATCH/DELETE | Contato específico |
| `/api/contacts/[id]/tags` | GET/POST | Tags do contato |
| `/api/contacts/[id]/notes` | GET/POST | Notas do contato |
| `/api/contacts/[id]/notes/[noteId]` | PATCH/DELETE | Nota específica |
| `/api/contacts/[id]/plan` | GET/PATCH | Plano IPTV do contato |
| `/api/contacts/[id]/payment-history` | GET | Histórico de pagamentos |
| `/api/contacts/[id]/reseller` | GET | Revendedor do contato |
| `/api/contacts/import` | POST | Importar CSV |
| `/api/contacts/export` | GET | Exportar |
| `/api/contacts/tags` | GET/POST | Tags |
| `/api/contacts/tags/[id]` | PATCH/DELETE | Tag específica |
| `/api/contacts/tags/hot-lead-tag` | GET | Tag hot lead |
| `/api/contacts/tags/pipeline` | GET | Tags de pipeline |
| `/api/contacts/tags/sync-from-conversations` | POST | Sincronizar tags |
| `/api/contacts/auto-tags` | GET/POST | Tags automáticas |
| `/api/contacts/counts` | GET | Contagem por status |
| `/api/contacts/monthly` | GET | Contatos mensais |
| `/api/contacts/monthly/send-renewal` | POST | Enviar renovação |
| `/api/contacts/health-score` | GET | Score de saúde |
| `/api/contacts/tested` | GET | Contatos com teste IPTV |

---

## Instâncias WhatsApp

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/instances` | GET/POST | Listar/criar instâncias |
| `/api/instances/[id]` | GET/PATCH/DELETE | Instância específica |
| `/api/instances/[id]/connect` | POST | Conectar (gerar QR) |
| `/api/instances/[id]/health` | GET | Saúde da instância |
| `/api/instances/[id]/sync` | POST | Sincronizar geral |
| `/api/instances/[id]/sync-contacts` | POST | Sincronizar contatos |
| `/api/instances/[id]/sync-profile` | POST | Sincronizar perfil |
| `/api/instances/[id]/pause` | POST | Pausar |
| `/api/instances/[id]/resume` | POST | Retomar |
| `/api/instances/[id]/webhook` | GET/POST | Configurar webhook |
| `/api/instances/[id]/tag-color` | PATCH | Cor da tag |
| `/api/instances/[id]/test-send` | POST | Envio de teste |
| `/api/instances/[id]/import-history` | POST | Importar histórico |
| `/api/instances/[id]/payment-confirmation` | POST | Confirmar pagamento |
| `/api/instances/health` | GET | Saúde de todas |
| `/api/instances/status` | GET | Status agregado |
| `/api/instances/sync-evolution` | POST | Sync com Evolution API |
| `/api/rotation/instances` | GET | Pool de rotação |
| `/api/rotation/next` | GET | Próxima instância disponível |
| `/api/rotation/status` | GET | Status do pool |
| `/api/rotation/stats` | GET | Estatísticas de rotação |
| `/api/whatsapp/instances/[id]/logout` | POST | Desconectar instância |
| `/api/whatsapp/instances/[id]/reconnect` | POST | Reconectar |

---

## IPTV

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/iptv/trials` | GET/POST | Listar/criar trials |
| `/api/iptv/trials/[id]` | GET/PATCH/DELETE | Trial específico |
| `/api/iptv/trials/[id]/activate` | POST | Ativar trial |
| `/api/iptv/trials/[id]/temporary` | POST | Trial temporário |
| `/api/iptv/trials/[id]/check-user` | GET | Verificar usuário |
| `/api/iptv/trials/stats` | GET | Estatísticas |
| `/api/iptv/trials/analytics` | GET | Analytics de trials |
| `/api/iptv/trials/cleanup` | POST | Limpeza de expirados |
| `/api/iptv/servers` | GET/POST | Servidores IPTV |
| `/api/iptv/servers-with-bots` | GET | Servidores com bots |
| `/api/iptv/bots` | GET/POST | Bots IPTV |
| `/api/iptv/app-configs` | GET/POST | Configs de apps |
| `/api/iptv/app-configs/[id]` | PATCH/DELETE | Config específica |
| `/api/iptv/app-favorites` | GET/POST | Apps favoritos |
| `/api/iptv/favorites` | GET/POST | Favoritos gerais |
| `/api/iptv/renewals` | GET/POST | Renovações |
| `/api/iptv/payments` | GET/POST | Pagamentos IPTV |
| `/api/iptv/generate-and-send` | POST | Gerar e enviar test |
| `/api/iptv/link-username` | POST | Vincular usuário |
| `/api/iptv/link-username/verify` | POST | Verificar vínculo |
| `/api/iptv/unlink-username` | POST | Desvincular |
| `/api/iptv/message-templates` | GET/POST | Templates de mensagem |
| `/api/iptv/extra-screen` | POST | Tela extra |
| `/api/iptv/sigma-activate` | POST | Ativar Sigma |
| `/api/iptv/sync-pagante-tags` | POST | Sincronizar tags de pagantes |
| `/api/iptv/chargebacks` | GET/POST | Chargebacks |
| `/api/iptv/chargebacks/block` | POST | Bloquear chargeback |
| `/api/sigma/servers` | GET/POST | Servidores Sigma |
| `/api/sigma/servers/[id]` | PATCH | Servidor específico |
| `/api/sigma/servers/[id]/mappings` | GET/POST | Mapeamentos |
| `/api/sigma/mappings/[id]` | PATCH/DELETE | Mapeamento específico |

---

## Checkout / Pagamentos

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/checkout/products` | GET/POST | Produtos do checkout |
| `/api/checkout/products/[id]` | GET/PATCH/DELETE | Produto específico |
| `/api/checkout/products/[id]/checkout` | POST | Iniciar checkout |
| `/api/checkout/orders` | GET/POST | Pedidos |
| `/api/checkout/orders/[id]` | GET/PATCH | Pedido específico |
| `/api/checkout/orders/[id]/cancel` | POST | Cancelar pedido |
| `/api/checkout/plans` | GET/POST | Planos de checkout |
| `/api/checkout/create-pix` | POST | Gerar PIX |
| `/api/checkout/config` | GET/PATCH | Configuração do checkout |
| `/api/checkout/stats` | GET | Estatísticas |
| `/api/checkout/status/[id]` | GET | Status do pagamento |
| `/api/checkout/upload` | POST | Upload de imagem |
| `/api/checkout/generate-testimonials` | POST | Gerar depoimentos com IA |
| `/api/payments/amplopay-webhook` | POST | Webhook atual Amplo Pay |
| `/api/payments/webhook` | POST | Webhook legado (DEPRECADO) |
| `/api/payments/register` | POST | Registrar pagamento manual |
| `/api/payments/stats` | GET | Estatísticas de pagamentos |
| `/api/payments/send-receipt` | POST | Enviar recibo |
| `/api/payments/chargeback` | POST | Registrar chargeback |
| `/api/payments/hourly` | GET | Pagamentos por hora |
| `/api/pix/checkout-plans` | GET | Planos PIX |
| `/api/pix/plans` | GET | Planos disponíveis |
| `/api/pix/pending` | GET | PIX pendentes |
| `/api/lowticket/create-pix` | POST | Criar PIX low-ticket |
| `/api/lowticket/orders/[id]/status` | GET | Status do pedido |
| `/api/lowticket/events` | POST | Eventos de low-ticket |
| `/api/lowticket/webhook` | POST | Webhook low-ticket |
| `/api/orders` | GET | Pedidos (atalho) |
| `/api/orders/[id]` | GET | Pedido específico |
| `/api/orders/apply-tag` | POST | Aplicar tag a pedido |
| `/api/pedidos/[id]/recibo` | GET | Recibo do pedido |

---

## Automações / Funis

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/automations` | GET/POST | Listar/criar automações |
| `/api/automations/[id]` | GET/PATCH/DELETE | Automação específica |
| `/api/automations/[id]/steps` | GET/POST | Passos da automação |
| `/api/automations/[id]/logs` | GET | Logs de execução |
| `/api/automations/[id]/stats` | GET | Estatísticas |
| `/api/automations/triggers` | GET/POST | Triggers |
| `/api/automations/triggers/[id]` | PATCH/DELETE | Trigger específico |
| `/api/automations/triggers/[id]/fire` | POST | Disparar manualmente |
| `/api/automations/triggers/cancel-funnel` | POST | Cancelar funil |
| `/api/automations/funis` | GET/POST | Funis |
| `/api/automations/funis/[id]` | GET/PATCH/DELETE | Funil específico |
| `/api/automations/funis/stages/[stageId]` | GET | Estágio do funil |
| `/api/automations/funis/enroll` | POST | Enrolar contato |
| `/api/automations/funis/analytics` | GET | Analytics de funis |
| `/api/automations/quick-triggers` | GET/POST | Triggers rápidos |
| `/api/automations/text-triggers` | GET/POST | Triggers por texto |
| `/api/automations/folders` | GET/POST | Pastas de automação |
| `/api/automations/logs/[log_id]/steps` | GET | Steps de um log |
| `/api/automations/media-library` | GET | Biblioteca de mídia |
| `/api/automations/media/[type]` | GET | Mídia por tipo |
| `/api/automations/midias` | GET/POST | Mídias |
| `/api/automations/midias/[id]` | PATCH/DELETE | Mídia específica |
| `/api/automations/audios` | GET/POST | Áudios |
| `/api/automations/audios/[id]` | DELETE | Áudio específico |
| `/api/automations/documentos` | GET/POST | Documentos |
| `/api/automations/documentos/[id]` | DELETE | Documento específico |
| `/api/automations/generate-audio` | POST | Gerar áudio (ElevenLabs) |
| `/api/automations/upload` | POST | Upload de arquivo |
| `/api/automations/schedule-delete-audio` | POST | Agendar exclusão |
| `/api/automations/trial-followup-stats` | GET | Stats follow-up trials |
| `/api/guided-funnels` | GET/POST | Funis guiados |
| `/api/guided-funnels/[id]` | GET/PATCH/DELETE | Funil guiado |
| `/api/guided-funnels/[id]/steps` | GET/POST | Passos |
| `/api/guided-funnels/[id]/steps/[stepId]` | PATCH/DELETE | Passo específico |
| `/api/guided-funnels/[id]/positions` | PATCH | Posições (xyflow) |
| `/api/guided-funnels/[id]/simulate` | POST | Simular funil |
| `/api/guided-funnels/[id]/export` | GET | Exportar funil |
| `/api/guided-funnels/generate-ai` | POST | Gerar funil com IA |
| `/api/guided-funnels/import` | POST | Importar |
| `/api/guided-funnels/templates` | GET | Templates |
| `/api/guided-funnels/templates/install` | POST | Instalar template |
| `/api/followup/campaigns` | GET/POST | Campanhas de follow-up |
| `/api/followup/campaigns/[id]` | PATCH/DELETE | Campanha |
| `/api/followup/logs` | GET | Logs |
| `/api/followup/dashboard` | GET | Dashboard |
| `/api/followup/funnel` | GET | Funil de follow-up |
| `/api/followup/monitor` | GET | Monitor |
| `/api/followup/upcoming` | GET | Próximos disparos |
| `/api/followup/pause` | POST | Pausar |
| `/api/followup/cancel` | POST | Cancelar |
| `/api/followup/blacklist` | GET/POST | Blacklist |
| `/api/followup/blacklist/[phone]` | DELETE | Remover da blacklist |
| `/api/followup/preview-data` | GET | Preview de dados |
| `/api/followups` | GET/POST | Follow-ups |
| `/api/followups/[id]` | GET/PATCH/DELETE | Follow-up específico |
| `/api/followups/queue` | GET | Fila |
| `/api/followups/queue/[id]` | DELETE | Item da fila |
| `/api/followups/[id]/queue` | GET | Fila do follow-up |
| `/api/followups/history` | GET | Histórico |
| `/api/followups/stats` | GET | Estatísticas |

---

## Campanhas (Marketing)

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/campaigns` | GET/POST | Campanhas |
| `/api/campaigns/[id]` | GET/PATCH/DELETE | Campanha específica |
| `/api/campaigns/[id]/send` | POST | Enviar campanha |
| `/api/campaigns/[id]/recipients` | GET | Destinatários |
| `/api/campaigns/segments` | GET/POST | Segmentos |
| `/api/campaigns/segments/[id]` | PATCH/DELETE | Segmento |
| `/api/campaigns/segments/[id]/count` | GET | Contagem do segmento |
| `/api/campaigns/blacklist` | GET/POST | Blacklist |
| `/api/campaigns/blacklist/import` | POST | Importar blacklist |
| `/api/campaigns/drip` | GET/POST | Drip campaigns |
| `/api/campaigns/drip/[id]` | PATCH/DELETE | Drip específica |
| `/api/campaigns/drip/[id]/enroll` | POST | Enrolar |
| `/api/campaigns/preview-count` | GET | Preview de contagem |
| `/api/ad-campaigns` | GET/POST | Campanhas de ads |
| `/api/ad-campaigns/[id]` | PATCH/DELETE | Campanha de ad |
| `/api/ad-campaigns/[id]/resync` | POST | Ressincronizar |
| `/api/reengagement` | GET/POST | Reengajamento |
| `/api/reengagement/eligible` | GET | Elegíveis |
| `/api/reengagement/[id]/run` | POST | Executar |

---

## IA

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/ai/agents` | GET/POST | Agentes IA |
| `/api/ai/agent-chat` | POST | Chat com agente |
| `/api/ai/agent-app-flow` | POST | Flow de app do agente |
| `/api/ai/agent-contexts` | GET/POST | Contextos do agente |
| `/api/ai/agent-contexts/[id]` | PATCH/DELETE | Contexto específico |
| `/api/ai/agent-medias` | GET/POST | Mídias do agente |
| `/api/ai/agent-medias/[id]` | DELETE | Mídia específica |
| `/api/ai/agent-knowledge-map` | GET | Mapa de conhecimento |
| `/api/ai/assistant` | POST | Assistente IA |
| `/api/ai/chat` | POST | Chat genérico |
| `/api/ai/credits/balance` | GET | Saldo de créditos IA |
| `/api/ai/dashboard` | GET | Dashboard IA |
| `/api/ai/usage` | GET | Uso de IA |
| `/api/ai/plan` | GET | Plano IA |
| `/api/ai/generate-agent-prompt` | POST | Gerar prompt do agente |
| `/api/ai/generate-followup` | POST | Gerar follow-up |
| `/api/ai/knowledge` | GET | Conhecimento |
| `/api/ai/suggest` | POST | Sugestão |
| `/api/ai/preview` | POST | Preview |
| `/api/ai/process-conversations` | POST | Processar conversas |
| `/api/ai/transcribe` | POST | Transcrever áudio |
| `/api/ai/vision/analyze` | POST | Analisar imagem (Vision) |
| `/api/ai/shared-key-preference` | GET/PATCH | Preferência de chave compartilhada |
| `/api/ai-studio/agents` | GET/POST | Agentes AI Studio |
| `/api/ai-studio/chat` | POST | Chat do studio |
| `/api/ai-studio/conversations` | GET/POST | Conversas do studio |
| `/api/ai-studio/conversations/[id]` | GET/DELETE | Conversa específica |
| `/api/sales-brain/overview` | GET | Visão geral Sales Brain |
| `/api/sales-brain/insights` | GET | Insights |
| `/api/sales-brain/opportunities` | GET | Oportunidades |
| `/api/sales-brain/journeys` | GET | Jornadas do cliente |
| `/api/sales-brain/live-feed` | GET | Feed ao vivo |
| `/api/sales-brain/funnel` | GET | Funil de vendas |
| `/api/sales-brain/graph` | GET | Gráfico |
| `/api/sales-brain/timeline` | GET | Timeline |
| `/api/sales-brain/process` | POST | Processar |
| `/api/sales-brain/dashboard` | GET | Dashboard |
| `/api/sales-brain/churn-risk` | GET | Risco de churn |
| `/api/sales-brain/problems` | GET | Problemas identificados |
| `/api/sales-brain/credentials` | GET | Credenciais extraídas |
| `/api/sales-brain/extract-credentials` | POST | Extrair credenciais |
| `/api/knowledge/items` | GET/POST | Itens de conhecimento |
| `/api/knowledge/items/[id]` | PATCH/DELETE | Item específico |
| `/api/knowledge/items/bulk` | POST | Bulk insert |
| `/api/knowledge/categories` | GET/POST | Categorias |
| `/api/knowledge/categories/[id]` | PATCH/DELETE | Categoria |
| `/api/knowledge/bases` | GET/POST | Bases de conhecimento |
| `/api/knowledge/documents` | GET/POST | Documentos |
| `/api/knowledge/documents/[id]/index` | POST | Indexar (RAG) |
| `/api/knowledge/search` | POST | Busca semântica |
| `/api/knowledge/rag-search` | POST | RAG search |
| `/api/knowledge/upload` | POST | Upload de documento |
| `/api/knowledge/templates` | GET | Templates |
| `/api/knowledge/templates/install` | POST | Instalar template |
| `/api/marketplace/agents` | GET | Agentes do marketplace |
| `/api/marketplace/agent-data` | GET | Dados do agente |
| `/api/chatbot/engine` | POST | Motor do chatbot |
| `/api/chatbot/flows` | GET/POST | Flows de chatbot |
| `/api/chatbot/flows/[id]` | GET/PATCH/DELETE | Flow específico |
| `/api/chatbot/flows/[id]/publish` | POST | Publicar flow |

---

## Analytics / Dashboard

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/dashboard/overview` | GET | Visão geral |
| `/api/dashboard/stats/orders-today` | GET | Pedidos hoje |
| `/api/dashboard/recent-payments` | GET | Pagamentos recentes |
| `/api/dashboard/instances-stats` | GET | Stats de instâncias |
| `/api/dashboard/analytics-hourly` | GET | Analytics por hora |
| `/api/dashboard/team-activity` | GET | Atividade da equipe |
| `/api/dashboard/config` | GET/PATCH | Configuração do dashboard |
| `/api/dashboard/chargeback-seen` | POST | Marcar chargeback visto |
| `/api/analytics/overview` | GET | Overview geral |
| `/api/analytics/revenue` | GET | Receita |
| `/api/analytics/funnel` | GET | Funil de conversão |
| `/api/analytics/heatmap` | GET | Heatmap de horários |
| `/api/analytics/conversion-heatmap` | GET | Heatmap de conversão |
| `/api/analytics/churn` | GET | Análise de churn |
| `/api/analytics/monthly-comparison` | GET | Comparação mensal |
| `/api/analytics/instances` | GET | Analytics por instância |
| `/api/analytics/instances/[instanceId]/sales` | GET | Vendas da instância |
| `/api/metrics` | GET | Métricas gerais |
| `/api/metrics/instances` | GET | Por instância |
| `/api/metrics/snapshot` | GET | Snapshot atual |
| `/api/metrics/weekly-report` | GET | Relatório semanal |
| `/api/metrics/worker` | GET | Métricas do worker |
| `/api/metrics/webhook-worker` | GET | Métricas webhook-worker |
| `/api/metrics/supabase` | GET | Métricas DB |
| `/api/reports/executive` | GET | Relatório executivo |
| `/api/reports/history` | GET | Histórico de relatórios |

---

## Equipe / Gamificação

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/team/[userId]` | GET/PATCH | Perfil do membro |
| `/api/team/[userId]/metrics` | GET | Métricas do membro |
| `/api/team/[userId]/credits` | GET | Créditos |
| `/api/team/[userId]/financial` | GET | Financeiro |
| `/api/team/[userId]/conversations` | GET | Conversas atribuídas |
| `/api/gamification/leaderboard` | GET | Ranking |
| `/api/gamification/my-stats` | GET | Minhas estatísticas |
| `/api/gamification/config` | GET/PATCH | Configuração |
| `/api/gamification/payroll` | GET | Folha de pagamento |
| `/api/gamification/withdraw` | POST | Solicitar saque |
| `/api/gamification/withdrawals` | GET | Saques |
| `/api/goals` | GET/POST | Metas |
| `/api/credits/balance` | GET | Saldo de créditos |
| `/api/credits/transactions` | GET | Transações |
| `/api/credits/redeem` | POST | Resgatar créditos |
| `/api/credits/spend` | POST | Usar créditos |
| `/api/credits/store` | GET | Loja de créditos |
| `/api/redemptions` | GET | Resgates |

---

## Resellers

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/resellers/me` | GET | Meu perfil de revendedor |
| `/api/resellers/list` | GET | Listar revendedores |
| `/api/resellers/my-sales` | GET | Minhas vendas |
| `/api/resellers/lookup` | GET | Buscar revendedor |
| `/api/resellers/credits/balance` | GET | Saldo de créditos |
| `/api/resellers/credits/purchase` | POST | Comprar créditos |
| `/api/resellers/credits/ledger` | GET | Extrato |
| `/api/resellers/clients` | GET | Clientes do revendedor |
| `/api/resellers/clients/activate` | POST | Ativar cliente |
| `/api/resellers/withdraw` | POST | Sacar comissão |
| `/api/resellers/register` | POST | Registrar como revendedor |
| `/api/resellers/public-signup` | POST | Cadastro público |
| `/api/reseller/dashboard` | GET | Dashboard do revendedor |
| `/api/internal/resellers` | GET | Resellers interno |

---

## Workspace / Configurações

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/workspace/me` | GET | Workspace atual |
| `/api/workspace/plan` | GET | Plano atual |
| `/api/workspace/plan/subscribe` | POST | Assinar plano |
| `/api/workspace/features` | GET | Features habilitadas |
| `/api/workspace/limits` | GET | Limites |
| `/api/workspace/settings` | GET/PATCH | Configurações |
| `/api/workspace/trial-status` | GET | Status do trial |
| `/api/workspace/activate-module` | POST | Ativar módulo |
| `/api/workspace/buy-credits` | POST | Comprar créditos |
| `/api/workspace/buy-agent` | POST | Comprar agente |
| `/api/workspace/configure-niche` | POST | Configurar nicho |
| `/api/workspace/export` | GET | Exportar dados |
| `/api/workspace/report-preview` | GET | Preview de relatório |
| `/api/workspace/profile-picture` | POST | Foto de perfil |
| `/api/workspace/upload-media` | POST | Upload de mídia |
| `/api/workspace/whitelabel` | GET/PATCH | Whitelabel |
| `/api/workspace/whitelabel/logo` | POST | Logo whitelabel |
| `/api/workspace-settings/*` | GET/PATCH | ~15 sub-configurações |
| `/api/settings` | GET/PATCH | Settings gerais |
| `/api/settings/modules` | GET/PATCH | Módulos |
| `/api/settings/export` | GET | Exportar settings |
| `/api/settings/sessions/revoke` | POST | Revogar sessão |
| `/api/settings/test-evolution` | POST | Testar Evolution |
| `/api/settings/test-webhook` | POST | Testar webhook |
| `/api/workspaces` | GET | Listar workspaces |
| `/api/workspaces/active` | GET | Workspace ativa |
| `/api/workspaces/clone` | POST | Clonar workspace |
| `/api/workspaces/members` | GET/POST | Membros |
| `/api/workspaces/members/create` | POST | Criar membro |
| `/api/workspaces/members/instance-permissions` | PATCH | Permissões de instância |
| `/api/workspace-notes` | GET/POST | Notas da workspace |
| `/api/workspace-notes/[id]` | PATCH/DELETE | Nota específica |
| `/api/me/permissions` | GET | Permissões do usuário |
| `/api/me/insights` | GET | Insights pessoais |

---

## Painel Master (Admin)

| Rota | Métodos | Descrição |
|------|---------|-----------|
| `/api/master/overview` | GET | Overview master |
| `/api/master/workspaces` | GET | Todas as workspaces |
| `/api/master/workspace/[id]` | GET/PATCH | Workspace específica |
| `/api/master/workspace/[id]/action` | POST | Ação na workspace |
| `/api/master/workspace/[id]/automation/[autoId]` | GET | Automação da workspace |
| `/api/master/workspace/[id]/copy-automation` | POST | Copiar automação |
| `/api/master/workspaces/[id]/funnel` | GET | Funil da workspace |
| `/api/master/workspaces/copy-settings` | POST | Copiar settings |
| `/api/master/plans` | GET/POST | Planos |
| `/api/master/plans/stats` | GET | Stats de planos |
| `/api/master/features` | GET/PATCH | Features globais |
| `/api/master/settings` | GET/PATCH | Settings master |
| `/api/master/trial-config` | GET/PATCH | Config de trials |
| `/api/master/trials` | GET | Trials |
| `/api/master/trials/stats` | GET | Stats de trials |
| `/api/master/module-trials` | GET/POST | Trials de módulos |
| `/api/master/users` | GET | Todos os usuários |
| `/api/master/users/[id]` | PATCH | Usuário específico |
| `/api/master/pessoas/*` | GET/PATCH | Clientes, funcionários, revendedores |
| `/api/master/resellers` | GET | Revendedores |
| `/api/master/resellers/[id]` | GET/PATCH | Revendedor específico |
| `/api/master/pending-users` | GET | Usuários pendentes |
| `/api/master/financeiro` | GET | Financeiro global |
| `/api/master/financeiro/stats` | GET | Stats financeiro |
| `/api/master/financeiro/resellers/payout` | POST | Pagar revendedores |
| `/api/master/financeiro/global` | GET | Visão global |
| `/api/master/ai-agents` | GET/POST | Agentes IA master |
| `/api/master/ai-agents/[id]` | GET/PATCH/DELETE | Agente específico |
| `/api/master/ai-agents/[id]/app-flow` | GET | Flow do agente |
| `/api/master/ai-agents/[id]/app-flow/chat` | POST | Chat do flow |
| `/api/master/marketplace-agents` | GET/POST | Agentes do marketplace |
| `/api/master/marketplace-agents/[id]` | PATCH/DELETE | Agente específico |
| `/api/master/instances/[id]/move` | POST | Mover instância |
| `/api/master/jobs` | GET | Jobs |
| `/api/master/monitoring` | GET | Monitoramento |
| `/api/master/audit-logs` | GET | Audit logs |
| `/api/master/automation-templates` | GET/POST | Templates de automação |
| `/api/master/global-blacklist` | GET/POST | Blacklist global |
| `/api/master/global-blacklist/[id]` | DELETE | Item da blacklist |
| `/api/master/global-blacklist/stats` | GET | Stats da blacklist |
| `/api/master/gamification` | GET/PATCH | Gamificação master |
| `/api/master/saas-tickets` | GET | Tickets SaaS |
| `/api/master/saas-tickets/[id]` | PATCH | Ticket específico |
| `/api/master/tickets` | GET | Tickets |
| `/api/master/tickets/stats` | GET | Stats |
| `/api/master/topbar-stats` | GET | Stats do topbar |
| `/api/master/elevenlabs-voices` | GET/POST | Vozes ElevenLabs |
| `/api/master/elevenlabs-voices/[id]` | DELETE | Voz específica |
| `/api/admin/workspaces-map` | GET | Mapa de workspaces |
| `/api/admin/workspaces-map/move-instance` | POST | Mover instância no mapa |
| `/api/admin/resellers` | GET | Revendedores (admin) |
| `/api/admin/resellers/[id]` | PATCH | Revendedor |
| `/api/admin/resellers/financial` | GET | Financeiro de revendedores |
| `/api/admin/resellers/withdrawals` | GET | Saques pendentes |
| `/api/admin/resellers/withdrawals/[id]` | PATCH | Aprovar/rejeitar saque |
| `/api/admin/payouts` | GET/POST | Payouts |
| `/api/admin/payouts/commissions` | GET | Comissões |
| `/api/admin/payouts/discount-days` | POST | Descontar dias |
| `/api/admin/payouts/reverse-commissions` | POST | Reverter comissões |
| `/api/admin/redemptions` | GET | Resgates |
| `/api/admin/redemptions/[id]` | PATCH | Resgate específico |
| `/api/admin/pending-users` | GET | Usuários pendentes |
| `/api/admin/financeiro` | GET | Financeiro admin |
| `/api/admin/store-items` | GET/POST | Itens da loja |
| `/api/admin/store-items/[id]` | PATCH/DELETE | Item |
| `/api/admin/ai-plans` | GET/PATCH | Planos de IA |
| `/api/admin/audit` | GET | Audit admin |

---

## Crons (executados pelo supercronic)

| Rota | Frequência | Descrição |
|------|-----------|-----------|
| `/api/cron/follow-up` | frequente | Processar follow-ups |
| `/api/cron/follow-up-leads` | frequente | Follow-up de leads |
| `/api/cron/funnel-processor` | frequente | Processar funis |
| `/api/cron/plan-expiry` | diário | Verificar planos vencidos |
| `/api/cron/recorrencia-sync` | diário | Sincronizar recorrências |
| `/api/cron/renewal-check` | diário | Verificar renovações |
| `/api/cron/pix-followup` | frequente | Follow-up de PIX pendente |
| `/api/cron/pix-pending-tagger` | frequente | Tag de PIX pendente |
| `/api/cron/close-inactive` | diário | Fechar conversas inativas |
| `/api/cron/auto-close-conversations` | diário | Auto-fechar |
| `/api/cron/daily-summary` | diário | Resumo diário |
| `/api/cron/weekly-report` | semanal | Relatório semanal |
| `/api/cron/cleanup-audit-logs` | diário | Limpeza de audit logs |
| `/api/cron/db-retention` | diário | Retenção do banco |
| `/api/cron/purge-jobs` | diário | Limpar jobs antigos |
| `/api/cron/check-instance-health` | frequente | Saúde das instâncias |
| `/api/cron/check-webhook-tokens` | frequente | Tokens de webhook |
| `/api/cron/check-worker-alerts` | frequente | Alertas do worker |
| `/api/cron/metrics-snapshot` | frequente | Snapshot de métricas |
| `/api/cron/promote-expired-trials` | diário | Promover trials expirados |
| `/api/cron/drip-campaigns` | frequente | Processar drip campaigns |
| `/api/cron/drip-event-triggers` | frequente | Triggers de evento |
| `/api/cron/scheduled-messages` | frequente | Mensagens agendadas |
| `/api/cron/monthly-payroll` | mensal | Folha de pagamento |
| `/api/cron/reseller-billing` | diário | Cobrança de revendedores |
| `/api/cron/reseller-levels` | diário | Níveis de revendedores |
| `/api/cron/trial-followup` | frequente | Follow-up de trials |
| `/api/cron/sync-instance-profiles` | diário | Sincronizar perfis |
| `/api/cron/sync-pagante-tags` | diário | Tags de pagantes |
| `/api/cron/sigma-backfill-24h` | diário | Backfill Sigma |
| `/api/cron/cleanup-module-trials` | diário | Limpar module trials |
| `/api/cron/increment-warmup-day` | diário | Incrementar warmup |
| `/api/cron/abandoned-cart` | frequente | Carrinho abandonado |
| `/api/cron/tag-refollow` | diário | Re-follow por tag |
| `/api/cron/process-bulk-send` | frequente | Processar bulk send |

---

## Rotas Públicas (sem auth)

| Rota | Descrição |
|------|-----------|
| `/api/auth/*` | Autenticação |
| `/api/webhook/connection` | Webhook de conexão WhatsApp |
| `/api/webhook` | Webhook Evolution API |
| `/api/payments/amplopay-webhook` | Webhook Amplo Pay |
| `/api/payments/webhook` | Webhook legado (DEPRECADO) |
| `/api/lowticket/webhook` | Webhook low-ticket |
| `/api/portal/[slug]` | Portal público |
| `/api/nps/[workspace_slug]` | Resposta NPS |
| `/api/affiliates/public-signup` | Cadastro de afiliado |
| `/api/resellers/public-signup` | Cadastro de revendedor |
| `/api/health` | Health check |
| `/api/version` | Versão da app |

---

*Veja também: [[01-modulos]] | [[03-banco-de-dados]] | [[04-pendencias]]*
