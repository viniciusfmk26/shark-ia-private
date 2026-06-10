# Sessão 26 — WhatsApp Cloud API + Múltiplas Features

Data: Maio/Junho 2026
Commits: f2389e79 to 9f6e23f3

## Renovações
- Reformulação /iptv/renovacoes: previsão receita, score engajamento
- Calendário vencimentos, KPIs MRR, gráfico 30d, churn rate
- Badge renovação no header com dropdown + botão cobrar
- Modo Vendedor: usa instância da venda original
- Variável dias dinâmica nas mensagens
- Worker grava em followup_logs após envio
- SendScheduler: distribui envios 8h-20h BRT com randomização

## Dashboard
- Stats panel com gráfico de área + linha de tendência
- Aba comissão: KPIs, gráfico, ranking revendedores, histórico saques
- Fix valor monetário casas decimais

## Inbox
- Fix: seleciona conversa quando conversation= muda
- Fix crítico: 1969 conversas e 23611 mensagens de instâncias desativadas vazando
- localStorage filtro scoped por workspace
- Banner no chat para contatos com conversas em múltiplas instâncias

## WhatsApp Cloud API
- Migration 126: campos provider/cloud em whatsapp_instances
- Unified send layer: lib/whatsapp/send.ts
- Webhook: /api/webhook/cloud
- Audio PTT via ffmpeg OGG/Opus
- Anti-ban skipa Cloud API
- Mark-as-read via Graph API
- Meta: Phone ID 1147025105164350, WABA 2053050685571211
- Instância: Julia Abreu - Oficial +55 5381077667
- Múltiplas palavras-chave por gatilho (split vírgula)

## Checkout
- CPF determinístico pelos últimos dígitos do WhatsApp
- Config CPF/email padrão no workspace
- Múltiplas contas AmploPay com rotação e conta avulso dedicada
- Fix PIX dialog template: plano substituído corretamente

## Automações
- Unificação: página única /automacoes com drawers
- Histórico disparos: botão chat por linha, filtro ontem

## Workspace
- Fix deleção: lowticket_orders + whatsapp_instances no tablesToClean

## Fixes
- 9f6e23f3: inbox localStorage scoped por workspace
- 64f26acc: workspace delete cleanup
- 555584a2: deploy dual-service, presença online
- e7c57286: payment_method para payment_type em renewal-today
- 8ffcb73a: herdar sold_by_user_id + filtro maior R$40
- 81dcd920: botão Reconectar sempre habilitado
- cce17796: daily_limit sync +30% margem

## Pendências
- 174 checkout_pix sem sold_by_user_id
- MinIO custom domain
- audit_logs retention policy
- Bloquear /api/migrate/* em produção
- pgvector/RAG quebrado
- 153 contatos funnel presos em Oferta + PIX
