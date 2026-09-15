# Motor TTS Local — Chatterbox (Self-Hosted)

> Deploy em 14/09/2026 19:15. Clonagem de voz por referência 100% grátis no servidor (Chatterbox Multilingual V3, Resemble AI, licença MIT).

## Serviço Swarm: `wp_zapflix-tts`

| Item | Valor |
|---|---|
| Imagem | `zapflix-tts:latest` (Dockerfile em `/root/Zapflix-Tech/tts-chatterbox/`) — 6.97GB compactada |
| Stack | Python 3.11 + torch CPU (chatterbox puxou CUDA deps mas roda CPU) + FastAPI + ffmpeg |
| Modelo | ChatterboxMultilingualTTS (0.5B, 23+ idiomas, pt incluído) — pré-baixado no build |
| Limites | `--limit-memory 5g --reserve-memory 4g --limit-cpu 2` (4GB deu OOM 137 no load; 5GB segura, uso idle ~4.7GB) |
| Rede | overlay `easypanel-wp`, **sem porta pública** (só interno) |
| API interna | `GET /health` (`{"status":"ok","model":"loaded"}`), `POST /tts` `{text, language_id, audio_prompt_b64?, exaggeration?, cfg_weight?}` → mp3 64k |
| Startup | Modelo carrega no startup (~2min) — FastAPI só abre a porta depois (connection refused até lá é normal) |
| Performance | CPU 2 threads: frase curta ~90-120s de geração |

## Integração Web

- Env no `wp_zapflix-web`: `CHATTERBOX_URL=http://wp_zapflix-tts:8000` (se ausente, motor fica oculto no Studio)
- `GET/POST /api/studio/local-tts` (`app/api/studio/local-tts/route.ts`): GET = status (ping /health, 5s); POST = proxy com timeout 280s. Referência de voz por `reference_audio_id` (automation_media) → web baixa e envia base64 ao motor. Mesmo shape de resposta do generate-audio (`provider: 'chatterbox'`, save no S3 + automation_media).
- Studio: 3º card "Local (Chatterbox)" no motor de voz, com idioma (pt default) + seletor de voz de referência da Biblioteca. Geração pode levar 1-3min (UI avisa).

## Lições do deploy (14/09/2026)

1. **Disco**: imagem TTS + cache de build encheram o disco (100%) durante builds paralelos — web build falhou com "no space". Sempre: `docker builder prune -af` antes de build grande; NUNCA dois builds pesados simultâneos. Disco ficou em 86-88% — monitorar.
2. **Build demora**: TTS full build ~15min (pip torch + chatterbox + predownload HF ~2GB). Export/unpack de 18.5GB camadas demora minutos com disk I/O alto.
3. **OOM 137 no load**: chatterbox multilingual precisa de ~4.7GB RAM residente. Limit 5g OK. Se mover pra outra máquina, mínimo 6g.
4. **Kill de builds**: `pkill -f "docker build"` mata TODOS os builds (usei e matei 2 de uma vez). Cuidado.
5. **Swarm image resolution**: continuar usando tag versionada em todo `service update` (padrão já documentado).

---

# Sales Brain Insights — automação (14/09/2026 20:00)

**Problema**: `sales_brain_insights` (síntese IA por conversa: sentiment/intent/opportunity/churn_risk/next_action) tinha 0 registros — o único caminho era o botão manual `POST /api/sales-brain/process` (nunca usado).

**Solução**: `autoProcessSalesBrainInsights()` no worker (`apps/worker/src/handlers/background.ts`), agendada em `worker.ts` a cada 30min (offset 120s pós-boot).

Como funciona:
- Mesmo motor do autoProcessConversations: Groq free (`GROQ_CHAT_API_KEY`, gpt-oss-120b) → fallback openai/openrouter de `ai_provider_settings`
- Gate por feature `ai_responses` (`isFeatureEnabled`) — hoje 5 workspaces habilitados de 45
- Seleção: conversas com mensagem HOJE e insight desatualizado (`processed_at < MAX(messages.created_at)`) — reprocessa só quando chega mensagem nova, LIMIT 15/workspace
- Mesmo prompt JSON do botão manual (rota UI intocada, continua funcionando com a key OpenAI/OpenRouter do workspace)
- Upsert ON CONFLICT (conversation_id) + mesmas regras de customer_journey (churn>=70 → 'churned'; buy/renewal → 'closing')
- Throttle 25s/call + backoff 60s em 429 (mesmo regime TPM do SalesBrain principal)

**Verificação em produção** (14/09): função testada direto no container — roda, encontra conversas, chama Groq. Insights não nasceram hoje porque a cota Groq TPD (200k) esgotou antes (199.8k/200k, reset 21:00 BRT). A partir do reset, insights devem nascer nos ciclos de 30min.

**Risco conhecido — disputa de cota**: o SalesBrain principal (autoProcessConversations, 10min, TODOS os 45 workspaces) compete pela mesma cota Groq 200k TPD. Se os insights sumirem por 429 crônico, opções: (a) priorizar insights no horário do reset, (b) reduzir LIMIT do principal, (c) Groq pago.

## Rotação de LLMs free — SalesBrain + Insights (14/09/2026 23:00)

**Problema**: cota Groq única (200k TPD) esgotava antes dos insights rodarem (429).

**Solução implementada** (`background.ts`):
- `groqChatJson()` com cursor round-robin sobre **3 contas Groq**: env `GROQ_CHAT_API_KEY` (atual) + `GROQ_CHAT_API_KEY_2` + `GROQ_CHAT_API_KEY_3` (~600k TPD combinados). 429 numa conta → tenta a próxima automaticamente; cursor gruda na que funcionou.
- Ambos os motores usam: `autoProcessConversations` (análise) e `autoProcessSalesBrainInsights` (insights).
- **Retry 400**: gpt-oss-120b às vezes falha a validação `response_format: json_object` → 1 retry sem response_format com instrução "APENAS JSON puro" no prompt.
- OpenRouter free avaliado: modelos free clássicos (llama-3.3, deepseek, gpt-oss:free) foram DESCONTINUADOS. Restam 19 free (gemma-4, nemotron-3...) — `nvidia/nemotron-3-super-120b-a12b:free` responde mas JSON veio malformado no teste; **fallback OR fica pendente** até validar qualidade. Com 3 contas Groq não é urgente.

**Bugs corrigidos no caminho**:
1. `sales_brain_insights`: índice único PARCIAL (`WHERE conversation_id IS NOT NULL`) não satisfaz `ON CONFLICT (conversation_id)` → trocado por índice FULL (NULLs não conflitam). Corrigido no worker E na rota UI (`/api/sales-brain/process`), e o índice recriado em produção (DROP + CREATE).
2. Sem o fix, TODOS os insights falhavam com "no unique or exclusion constraint matching the ON CONFLICT specification".

**Validação em produção** (14/09 23h): 1º insight gerado e conferido — negative/support, churn_risk 60, opportunity e next_action acionáveis em pt-BR (caso real de cliente sem acesso). Backlog de ~152 conversas elegíveis será consumido nos ciclos de 30min (25s/conversa ≈ 63min o backlog total).

### Cadeia final de rotação (14/09/2026 23:30)

`groqChatJson()` agora resolve nesta ordem:
1. **4 contas Groq** (`GROQ_CHAT_API_KEY` + `_2` + `_3` + `_4`) — cursor round-robin, ~800k TPD combinados
2. **OpenRouter free** (`OPENROUTER_CHAT_API_KEY` do Fabio, modelo `OPENROUTER_CHAT_MODEL=nex-agi/nex-n2.5-pro:free`) — só entra se TODAS as Groq estiverem em 429. Modelo escolhido por teste real com o prompt JSON pt-BR dos insights (único dos 19 free que devolveu JSON válido e correto).

Insights crescendo em produção (0 → 12 na primeira hora). Zero erros de IA nos logs após o deploy.

### Cadeia expandida com chaves da Eluiza (14/09/2026 23:20)

- `GROQ_CHAT_API_KEY_5` (Eluiza) → **5 contas Groq** (~1M TPD combinados)
- OpenRouter com **rotação multi-chave**: `OPENROUTER_CHAT_API_KEY` (Fabio) + `_2` (Eluiza), cursor próprio — **2 contas OR** de fallback
- Insights em produção: 22 e crescendo (~10-15 por ciclo de 30min, throttle 25s)
- Capacidade total estimada: >1.2M tokens/dia antes de esgotar tudo — contenda de cota resolvida

## Voz do agente: seletor, preview, modelo OR + toggle modo voz (14/09/2026 24:00)

Cadeia de voz do agente já existia (agent.voice_id → workspace default → primeira voz de elevenlabs_voices). Melhorias entregues:

1. **Toggle modo voz no Inbox** (`chat-view.tsx` + `PATCH/GET /api/inbox/conversations/[id]/voice-mode`): botão 🔊/🔇 ao lado do seletor de modo IA. Liga/desliga `conversations.voice_mode` por conversa (antes: só comandos do cliente no WhatsApp como "modo voz"). Desabilitado se modo IA off.
2. **Seletor de voz do agente** (`agent-wizard.tsx`): vozes agrupadas com rótulos (👤 Minhas Vozes clonadas / 🎙️ Biblioteca ElevenLabs) + botão "Ouvir amostra" (preview_url da voz selecionada) + voz selecionada destacada no topo.
3. **Modelo por agente via OpenRouter**: wizard ganhou grupo OpenRouter no seletor de modelo (gpt-oss-120b, nex-n2.5-pro:free, gemma-4-31b:free, nemotron-3-super:free). Worker (`ai.ts` nos 2 call sites): se `agent.model` contém `/` (formato provider/modelo) E workspace tem chave OpenRouter → roteia via OR independente do provider padrão; senão mantém comportamento anterior.

Nota: as vozes do agente são SEMPRE ElevenLabs (com fallback Fish quando a EL falha). Vozes Fish/Chatterbox não se aplicam ao modo voz do agente — cadeia TTS do worker é EL→Fish por key, não por voice_id Fish.
