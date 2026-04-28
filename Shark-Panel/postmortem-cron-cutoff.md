# Postmortem — Fix 3.6: cutoff de segurança em crons

**Data:** 28/04/2026
**Severidade:** Mitigado antes do impacto — sem incidente em produção
**Janela detectada:** ~25 minutos antes do próximo `pix-followup` disparar
**Autor:** Claude Code + Vinicius

---

## Resumo

Fix 3.6 ligou 15 crons que existiam como rota mas nunca rodavam.
Como vários desses crons disparam mensagens WhatsApp (pix-followup,
abandoned-cart, follow-up, drip-campaigns), ligar sem cuidado faria
o sistema "atacar" todo o backlog histórico — pedidos PIX pendentes
de meses atrás receberiam mensagem de cobrança, conversas dormentes
ressuscitariam, etc.

A solução escolhida foi um **cutoff de segurança via env var
`CRON_CUTOFF_DATE`** que filtra os registros nas queries dos crons,
para que só processem registros criados a partir de 2026-04-28.

Durante a execução, descobriu-se que o plano original colocava a
env var no serviço errado.

---

## O erro do plano

**Plano original:**
```bash
docker service update \
  --env-add CRON_CUTOFF_DATE=2026-04-28T00:00:00Z \
  wp_zapflix-cron
```

**Por que está errado:** o `wp_zapflix-cron` é um container que
roda `supercronic` e dispara `curl` para o `wp_zapflix-web`. Quem
**executa** a lógica das rotas (e portanto **lê**
`process.env.CRON_CUTOFF_DATE`) é o `wp_zapflix-web`. Setar a env
no cron container não tem efeito algum.

Estado real após execução do plano original:
- ✅ Cron container: 27 crons agendados, env setada (sem efeito)
- ❌ Web service: roda código antigo sem o filtro, sem env var
- ⚠️ Próximo `pix-followup` em ~25 min iria disparar para 82+
  pedidos PIX históricos sem nenhum filtro

---

## Como foi detectado

Após aplicar os patches no código (`app/api/cron/*/route.ts`) e
rebuild do cron container, antes de executar o teste manual,
revisão mental: "as rotas patchadas são do Next.js do web, não do
cron — o cron não executa código TypeScript, só dispara HTTP".

A detecção aconteceu **antes** do passo de teste manual (que iria
de fato disparar o `pix-followup` real). Não houve nenhuma
mensagem disparada para clientes no estado intermediário.

---

## Mitigação executada

1. **Pausa imediata:** `docker service scale wp_zapflix-cron=0`
   (interrompe todos os crons enquanto o web é rebuilt)
2. **Add env no serviço correto:** `wp_zapflix-web` e
   `wp_zapflix-worker`
3. **Rebuild do web** com o código que de fato lê a env var
4. **Validação:** query no DB confirmou 4 pedidos pós-cutoff vs
   82 pré-cutoff (bloqueados). Disparo manual de `pix-followup`
   retornou `{processed: 0, sent: 0}` — nenhum cliente impactado
5. **Reativar cron:** `scale=1` + force update

---

## Lição aprendida

> **Env vars precisam estar no serviço que LÊ, não no que AGENDA.**

Em sistemas onde um serviço só dispara HTTP para outro
(cron → web, scheduler → worker, gateway → backend), config das
rotas mora no serviço que **executa a lógica**, não no que envia
o gatilho.

Ao trocar config de rota, sempre verificar:
- Qual processo lê `process.env.X` no momento da execução?
- Esse processo está em qual serviço Docker?
- A env var está nesse serviço (`docker service inspect ... |
  jq '.[0].Spec.TaskTemplate.ContainerSpec.Env'`)?

---

## Mudanças no AGENTS.md

Foi adicionada seção **"Comportamento esperado em planos com risco"**
em `/root/Zapflix-Tech/AGENTS.md` instruindo o Claude Code a:
1. Parar antes de qualquer ação com efeito real
2. Reportar o furo (o que o plano dizia, por que não funciona,
   estado real, janela de risco)
3. Apresentar 2-3 opções com trade-offs
4. Aguardar decisão humana
5. Pausar serviços/crons como medida de proteção sem pedir
   permissão (prevenção de dano > processo)

Este postmortem é a referência do precedente.

---

## Estado final (28/04/2026)

- 27 crons ativos no `wp_zapflix-cron` (12 antigos + 15 novos)
- `CRON_CUTOFF_DATE=2026-04-28T00:00:00Z` em `wp_zapflix-web` e
  `wp_zapflix-worker`
- 5 rotas com filtro condicional `($N IS NULL OR campo >= $N)`:
  - `pix-followup`, `abandoned-cart`, `follow-up`,
    `drip-campaigns`, `close-inactive`
- Validação manual: `pix-followup` rodou e retornou 0/0
- Commit: `f00ae5da` em `Zapflix-Tech` (main)

Ver também: [[FIXES]] §3.6, [[AGENTS]] (raiz do repo).
