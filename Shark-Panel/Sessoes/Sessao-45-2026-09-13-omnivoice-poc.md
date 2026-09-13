# Sessão 45 — Shark Panel
**Data:** 13/09/2026
**Foco:** POC TTS open source — OmniVoice (k2-fsa) em CPU da própria VPS de produção

---

## Contexto

Avaliação de alternativa open source ao ElevenLabs/Fish Audio para TTS + clonagem de voz. Estado do TTS na ocasião: **Fish Audio (OpenRouter) primário, ElevenLabs fallback** (commit `7df2bf06`).

**Candidato:** [OmniVoice](https://github.com/k2-fsa/OmniVoice) (k2-fsa — time do Daniel Povey) — 13.1k stars, **Apache-2.0**, TTS zero-shot difusão para 600+ idiomas, clonagem com 3-10s de áudio, RTF 0.025 em H100.

## Atrativos pro Shark Panel

- Apache-2.0 → self-host sem custo por caractere
- `create_voice_clone_prompt()` salva `.pt` → substituiria o conceito `voice_id` da tabela `elevenlabs_voices` (encode 1x, reusa)
- `normalize_text=True` (num2words) → tangencia o `normalizeTtsPronunciation()` pt-BR feito à mão no `tts.ts` (Sessão 44)
- Tags inline (`[laughter]`) e voice design por atributos (gênero/idade/pitch, treinado só em zh/en)

## Benchmark na VPS de produção (SEM GPU)

Setup: venv isolado em `/tmp/opencode/omnivoice-poc`, torch 2.8.0 CPU, fp32, 4 threads, textos curtos, ref Fleurs pt-BR (6.7s) com `ref_text` explícito (evita carregar Whisper junto). Produção ilesa (8.4GB livres recuperados ao final).

| Amostra | Modo | Áudio | Geração | RTF (4 cores CPU) |
|---|---|---|---|---|
| 1_auto.wav | Auto voice pt-BR | 4.7s | 83s | **17.8** |
| 2_clone.wav | Clone voz ref pt-BR | 6.0s | 223s | **37.4** |
| 3_numeros.wav | Clone + "R$ 123,45"/"18:30"/% | 10.9s | 291s | **26.7** |

Modelo: ~3.1GB (2.4GB main + 0.8GB audio tokenizer) + Whisper é dependência opcional para auto-transcrição de ref.

## Conclusões

1. **CPU não serve para modo voz do agente (tempo real)** — RTF 17-37 na VPS = 1-5 min por áudio de 6s. Self-host exige GPU dedicada (RTX 3060/4060 estimado RTF <0.5; H100 faz 0.025).
2. **Batch/automations em CPU é tecnicamente viável mas perigoso nesta VPS** — ~7GB RAM + 1 core pesado com swap do host em 75%.
3. **Veredito de qualidade pt-BR pendente** — wavs em `/tmp/opencode/omnivoice-poc/samples/` (removidos depois da avaliação; regeneráveis com o poc.py, env mantido no journal da sessão).
4. Encaixe futuro: mais um provider na cadeia de prioridade de TTS (agent.voice_id → workspace → default), com path de prompt `.pt` no volume.

## Decisão

Se a qualidade agradar → validar latência em GPU alugada (vast.ai/RunPod ~$0.20-0.40/h) antes de qualquer mudança de infra. Se não agradar → Fish Audio segue primário; OmniVoice registrado como opção futura.

## Commits

- Nenhum no projeto (POC isolado em /tmp). Últimos commits de voz: `7df2bf06` Fish primário · `cbd20737` voz por agent · `0e5464c0` pronúncia pt-BR

---

## Adendo — Fix: pagamento manual não gravava plano/vencimento no client_360

**Sintoma:** no Resumo IA do inbox, painel "Dados do cliente" mostrava Plano/App IPTV/Contratado/Vencimento = "—" enquanto Total pago e Último pagamento apareciam (caso: contato "A" 5527999629106, manual R$ 64,90 "tela extra" em 08/07/2026, Sigma `147597785` Servidor 2).

**Causa raiz (3 camadas):**
1. `/api/payments/register` gravava `payments` (por isso LTV/último pagamento apareciam) mas **nunca** criava `subscriptions` nem escrevia `contacts.plan_type/plan_expires_at` — só `custom_fields`.
2. `sigma_expires_at: null` no metadata: o endpoint `webhook/customer/renew` do Sigma NUNCA devolve data (0/3.356 históricos) e o fallback `resolveRealExpiry` (integration API) só ficou efetivo a partir de ~agosto/2026 (jul: 784 renovações 0 com data; set: 20/20 com data). O caso 08/07 caiu na era sem data.
3. "App IPTV" é `subscriptions.iptv_app` que está NULL em 100% das rows — sempre mostra "—" (gap separado, mapeado).

**Impacto maior:** 1.003 contatos com `sigma_username` mas sem plan_type/plan_expires_at; 159 sem subscription alguma. **Decisão do usuário: NÃO fazer backfill** (crons de renovação/recorrência leem esses campos — risco de disparo em massa). Só vale a partir dos novos.

**Fix (deployado em build 13/09 ~17:20, task verificada no container):** em `payments/register`, após provisionamento Sigma bem-sucedido:
- `contacts.plan_type = COALESCE(plan_type, planNormalizado)` (nunca rebaixa) + `plan_expires_at = COALESCE(sigmaExpiresIso, existente)` (só dado real)
- INSERT idempotente em `subscriptions` (`source='manual_payment'`, `next_billing_at = NULL` → invisível pra recorrência/AmploPay; `iptv_expires_at` = validade real; `iptv_app` = display_name do server, ex. UNIFLIX; plan_name = plano cru do body)
- Se já existe subscription ativa SEM recorrência (cliente de checkout renovou manual): só atualiza `iptv_expires_at`
- SQL validado em transação com ROLLBACK antes do deploy; tsc limpo

**Efeitos colaterais esperados (corretos):** novos pagamentos manuais passam a alimentar client_360 (painel resumo IA, CRM, resumo do inbox) e entram no funil de renovação (cron `renewal-check` lê vencimento efetivo da view) quando o vencimento se aproximar.

**Follow-up pendente (não feito):** `app/api/iptv/sigma-activate` (ativação manual pela UI) tem o mesmo gap — não grava plano/vencimento. Avaliar aplicar o mesmo padrão.
