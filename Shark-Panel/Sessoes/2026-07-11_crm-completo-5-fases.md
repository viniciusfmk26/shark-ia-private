# Sessão 2026-07-11 — CRM Completo (5 Fases) + Chatbot + Meta Ads + Compliance

## Resumo executivo
Sessão longa que entregou o **replanejamento completo do CRM em 5 fases (todas no ar)**, além de correções de chatbot no flow ativo, o destravamento da integração Meta Ads com ciclo de atribuição completo, e correções de compliance Meta. ~30 commits (`0b2280df..be668d29`), 5 migrations manuais (674-678), múltiplos deploys web + worker validados same-day.

## 1. Chatbot (flow ativo 31c76a1f)
- **"Outra coisa" (ramo vencido)** repontado p/ menu de categorias `sup-cat-menu`; cadeia captura+IA (8 nodes) removida (`chatbot_vencido_outra_coisa_fix`).
- **plan_status granular** no `check_active_plan`: active/expired/never_had_plan/error + ramo novo `sup-newlead-msg` (`3d08234e`); texto de vencido reescrito.
- **Gate "Verificar minha assinatura"**: suporte não afirma plano de cara; botão roda check e mostra dado real (`d440021a` expõe plan_type/expiração).
- **Aviso de inatividade configurável** (timeout + antecedência): cron chatbot-timeout no web, `session_timeout_warning_minutes` (`fae36eb6`, `d89e2bff`).
- Fixes de cascata de botões por `awaitKey` (`0c316845`, `c47fc28b`); Streamdeck/enter-flow/ADS_RETURN/DEVICE_TEST apontados ao clone 31c76a1f (`be5586c2`, `0ef9db66`).

## 2. Meta Ads destravado
- Escopo OAuth `+business_management` (`72c35a19`); fix refresh da UI de vinculação.
- Sync popula orçamento/gasto reais (fix centavos→reais), importa só ativas por padrão + "Importar todas" (`e1cb76b1`).
- **Ciclo de atribuição completo**: CRON_TOKEN no worker, normalização de telefone, webhook marca converted, matcher `instance_ids[]` (`a6ca4957`); leads CTWA vinculados à campanha via mapa anúncio→campanha (`ad7eaff2`); janela de conversão corrigida — conversões/receita pela **data do PAGAMENTO** (`cad1d407`).

## 3. CRM — 5 fases (o grande entregável)
| Fase | Entrega | Commits |
|---|---|---|
| 1 | View `client_360` (plan_status por datas, LTV, churn_risk) + ficha `/clientes/[id]` | `1e2a3eec` |
| 2 | Lista `/clientes` (busca digits-only, filtros, contadores, `GET /api/clientes`) | `482b6078`+`6ee57037` |
| 3 | Kanban `/crm` VIVO: projeção do Sales Brain (sync 10min no worker, `crm_deals.opportunity_id`, dedup 2 camadas, stale-out 30d, write-back won/lost, seed multi-workspace); backfill 298 deals; flag crm ligada | `0a50ddd7` |
| 4 | `/atendimento` (fila honesta, produtividade por agente s/ ...0001, CSAT exibido, team-activity) + higiene (abandoned_at no cron 1h, msgs IA `source='ai_agent'`, assigned_to unificado — 4 leitores da legada corrigidos) + claim explícito (409 no duplo) + recuperação de abandonados (flag OFF, controle na UI c/ travas Meta fixas) | `c4f34156`..`a7226652` |
| 5 | `/ciclo-de-vida` (buckets, **ROI da régua: 934 lembretes/257 conversões=28%; D-3 35% > D0 20%**, ranking LTV, fila winback manual c/ claim+desfecho) + renewal-check conectado à client_360 (`?dry=1`) + gates de compliance em mídia automática | `d69c4bc1`..`be668d29` |

Migrations manuais (runner travado na 131): 674 meta_ad_map, 675 crm_deals.opportunity_id, 676 conversations.abandoned_at/close_reason, 677 claimed_at/abandoned_followup_at/csat.agent_user_id, 678 winback_outcomes.

## 4. Bugs reais corrigidos
1. **Régua não re-armava**: webhooks de pagamento nunca resetavam `renewal_notified_days` → cliente só recebia lembretes no 1º ciclo. Corrigido nos 2 webhooks.
2. **Atribuição de venda na coluna legada**: seller do checkout (`shared.ts`), gate da IA, eco do webhook e ai.ts liam `assigned_user_id` — perdiam 4.854 conversas atribuídas só em `assigned_to`. Todos migrados.
3. **~584 zumbis** de campanha/subscriptions reclassificados (data do pagamento vs data do lead, `cad1d407`).
4. Conta `...0001` (Vinicius real) tratada como automação: envio manual dele caía no throttle de bot; comparações removidas + corte temporal 09/07 no painel.
5. Cloud API: silent-skip → defer (`0b2280df`), bypass critical só no throttle (`e3999753`).

## 5. Compliance Meta (estudo aplicado)
Janela 24h, quality rating, frequency cap, opt-out estudados; travas aplicadas: recuperação de abandonados só dentro da janela + 1x por conversa + skip se voltou (fixas no código, UI só informa); mídia automática (pix/trial) agora passa pela janela+throttle; `send_followup_trial` ganhou throttle; `proactive:true` marcado nos producers atrás de `strict_proactive_window` (OFF).

## 6. Pendências (Vinicius)
- **Responder Luizmonte** (5511969233243, reclamação c/ ameaça, conv `178fd318`).
- **Ligar recuperação de abandonados** (toggle em /atendimento; delay 4h e msg custom já salvos).
- **Fila de winback**: 239 recuperáveis + 364 churned por LTV esperando o 1º "Trabalhar" em /ciclo-de-vida.
- **Decisões de compliance**: (a) reroute de abandoned-cart/process-bulk-send/reengagement-run pelo gate; (b) ligar `strict_proactive_window`.
- Dívidas: vocabulário de stages do Sales Brain (3 vocabulários), winback automático via template utility Meta, migração da /contacts p/ client_360, template p/ abandonados >24h.
