# Deep Dive — Prospecção (Radar, Operação e Prospecção rápida)

> Última atualização: 17/09/2026 — entregue a tela **Prospecção rápida** (commit `51f0b9fd`, web em produção `51f0b9f`).

## Visão geral do módulo

Três camadas, do descobrir ao enviar:

1. **Radar Digital de Empresas** — descoberta dos leads (`prospect_radar_leads`, `prospect_radar_audits`, `prospect_radar_lists`). Busca via Google Places, score, classificação de oportunidade (site / chatbot / ambos / nenhuma).
2. **Operação de Prospecção** — o disparo: lista de leads + mensagem + canal + número que envia + trilhos anti-spam (`prospect_operations`, `prospect_operation_leads`).
3. **Campanha + worker** — o envio real, em lotes de um dia, com delay aleatório e janela de horário (`campaign_contact_routes`, `lib/campaigns/dispatch.ts`).

O CRM recebe o lead convertido no pipeline dedicado **"Prospecção B2B"** (`lib/crm/prospect-pipeline.ts`).

## Prospecção rápida (17/09/2026)

Tela única que substitui o fluxo de ~10 passos: **buscar → marcar → escrever → disparar**.

- **Página:** `app/(dashboard)/admin/prospect-quick/page.tsx` + `components/prospect-quick/*`.
  Na sidebar: "Prospecção rápida" (`/admin/prospect-quick`); o wizard antigo virou **"Prospecção (modo avançado)"**.
- **Rota de orquestração:** `POST /api/admin/prospect-quick/launch` (`app/api/admin/prospect-quick/launch/route.ts`, contrato em `types/prospect-quick.ts`).
  Faz, numa tacada: import dos places → lista do Radar → criação da Operação → start. Passos 1–3 numa única transação; o start fora dela.
- **Serviços extraídos** (reuso, zero SQL duplicado — as 4 rotas antigas viraram adaptadores finos):
  `lib/prospect-operations/{start,create,lists}.ts` e `lib/prospect-radar/google-import.ts`.
- **Triagem na própria busca:** `lib/prospect-quick/screen.ts` (função pura) enxertada em `GET /api/admin/prospect-radar/google`. Cada resultado volta com `phoneE164`, `alreadyInRadar`, `alreadyContacted`, `suppressed`, `duplicateInPage`, `preselect` e `blockReason`.
  - Lead frio sem opt-in **vem marcado** (`preselect=true`).
  - `alreadyInRadar` sozinho **não** desmarca (é só informativo — pode já estar no Radar e nunca ter sido contatado).
  - Opt-out, blacklist, "já contatado" e telefone repetido na mesma página desmarcam **e não podem ser marcados à mão**.
  - **Fail-closed:** se as checagens falharem, a busca devolve **500** — nunca "pode contatar" sem verificar.
- **Idempotência (duplo clique):** `prospect_operations.client_request_id` + índice único parcial `uq_prospect_operations_client_request` (`migrations/20260921_prospect_quick_launch.sql`). O segundo clique devolve `{ok:true, already_launched:true}` — sem criar uma segunda operação.
- **Falha do start não perde o trabalho:** a rota devolve 200 `{ok:false, operation_id, list_id, advanced_url}`. As empresas ficam salvas e **nenhuma mensagem** foi enviada; o operador segue pelo modo avançado.
- **Auditoria preservada:** override sem opt-in continua gravando `manual_override_no_optin/_user_id/_at` + evento por lead, agora com `source:'quick_launch'` e `acknowledged_checkbox:true`.
- **Site clicável na lista (17/09/2026, commit `75bfee42`):** o selo "tem site" virou link para `websiteUri` (dado que já vinha na busca em `GooglePlacePreview`) abrindo em **aba nova** — na mesma aba o operador perderia a busca e as seleções. Valor tratado por `lib/utils/url.ts` → `safeExternalUrl` (só http/https; `javascript:` / `data:` / `mailto:` caem para texto morto), com teste em `test/url.test.ts`.
  - ⚠️ Produto: muito "site" de empresa local no Google é na verdade **Instagram/Facebook**. Isso muda o argumento da abordagem (rede social = "não tem site de verdade").

### Limites da v1

- Máximo de **40 empresas** por lançamento (`too_many_places`).
- `{{...}}` (variáveis na mensagem) recusado (`variables_not_supported`).
- Canal `cloud_api` exige **template aprovado**.
- Os trilhos **nunca vêm do cliente**: a rota usa sempre `PROSPECT_SAFE_DEFAULTS`, `allow_recontact:false` e `batch_auto_advance:false`.

## Trilhos de segurança (inegociáveis)

- **Prospecção fria sem opt-in liberada PELO DONO**, com trilhos: teto diário, teto por número, delay aleatório 45–120 s, janela 9–18h seg–sex, um lote = um dia.
- **Override sem opt-in ⇒ o lote seguinte é SEMPRE manual** (decisão do dono).
- **Opt-out / blacklist / quality RED / humano assumiu / dedup nunca são contornados** por nenhum caminho (nem pela tela nova).
- **Dedup anti-recontato:** `lib/prospect-operations/contact-history.ts` marca "Já contatado" pelo histórico de `campaign_recipients` de campanhas de prospecção do workspace (janela default 60 dias).
- **O agente nunca parece IA** e **nunca promete chamada de humano** (cria nota interna + fila "Aguardando humano" + sino).
- **Nunca disparar para cliente real** nem iniciar Operação sem decisão do dono.

## Arquivos principais

```
app/(dashboard)/admin/prospect-quick/page.tsx   → tela única
components/prospect-quick/                      → search-form, results-table,
                                                  message-box, channel-picker,
                                                  responder-picker, launch-dialog
app/api/admin/prospect-quick/launch/route.ts    → orquestração (import+lista+operação+start)
types/prospect-quick.ts                         → contrato da rota
lib/prospect-quick/screen.ts                    → triagem pura (preselect/blockReason)
lib/prospect-operations/                        → core, create, lists, start,
                                                  safety-rails, contact-history
lib/prospect-radar/                             → core (score/oportunidade), audit,
                                                  google-import, auth
lib/campaigns/dispatch.ts                       → teto de 24h + janela dentro do dispatch
lib/crm/prospect-pipeline.ts                    → pipeline "Prospecção B2B"
apps/worker/src/lib/lead-context.ts             → injeta "EMPRESA PROSPECTADA" no prompt
```

## Migrations relacionadas

```
20260915_prospect_radar.sql
20260916_prospect_operations.sql
20260916_prospect_radar_lists.sql
20260916_prospect_manual_override.sql
20260916_google_auto_selection.sql
20260916_google_place_details.sql
20260916_google_place_backfill.sql
20260918_radar_lead_place_fields.sql
20260918_lead_opportunity_context.sql
20260919_operation_recontact.sql
20260919_prospect_lead_niche.sql
20260921_prospect_quick_launch.sql   ← client_request_id + índice único (aplicada, id 726)
```

## Pegadinhas conhecidas

- **Dois sistemas de lista:** o módulo legado de Receita Federal usa `prospect_lists`/`prospect_list_items` (`/admin/prospeccao/listas`); o Radar usa `prospect_radar_lists`/`prospect_radar_list_members`. **Não há ponte automática** entre eles.
- **`alreadyInRadar` ≠ "não contatar":** só significa que o lead já está na base do Radar.
- **`dispatch_run_at` não conhece dia da semana** — sábado e domingo contam (pendência conhecida).
- **Auditoria "não medido" ≠ "não tem":** widget de chat ausente/NULL nunca é tratado como ausência confirmada.
- **Env do worker cai no redeploy:** `GROQ_API_KEY*` e `NVIDIA_API_KEY` adicionadas por `docker service update --env-add` são apagadas quando o Easypanel redeploya — precisam estar cadastradas na UI.

## Pendências / próximos

- Variáveis (`{{...}}`) na mensagem da tela rápida.
- Retorno agendado ("me chama depois") — WIP em `apps/worker/src/lib/return-time-parse.ts` + `migrations/20260921_agent_followup_scheduling.sql` (ainda **não** aplicada/commitada).
- `dispatch_run_at` ignorando fim de semana.

Especificação completa do módulo: `docs/PROSPECCAO.md` e `docs/PLANO-FUNIL-SDR-B2B.md` no repositório.
