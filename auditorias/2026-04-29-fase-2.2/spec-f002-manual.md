# F-002 — Manual de Afiliados (Netflix-style)

## Visão
Aba `/reseller/manual` com cards horizontais por categoria, vídeos YouTube embeddados. Inspirado na navegação da Netflix: rows horizontais scrolláveis por categoria, hover/click abre modal com player.

## Categorias propostas

| Categoria | Vídeos sugeridos | Foco |
|---|---|---|
| **Primeiros passos** | 5 | Como acessar painel, como ativar primeiro cliente, leitura do dashboard |
| **Vendas e pitch** | 4 | Pitch curto, objeções comuns, fechamento, follow-up |
| **WhatsApp e atendimento** | 4 | Tom, copy de boas-vindas, lidar com cliente bravo, pós-venda |
| **Comissões e saques** | 3 | Como ler extrato, como solicitar saque, prazo |
| **Dicas avançadas** | 5 | Anúncios pagos, indicação, retenção, cross-sell, upsell |

Total: ~21 vídeos no MVP.

## Schema

```sql
CREATE TABLE manual_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL,
  category TEXT NOT NULL,                  -- 'primeiros-passos' | 'vendas' | 'whatsapp' | 'comissoes' | 'avancadas'
  title TEXT NOT NULL,
  description TEXT,
  youtube_id TEXT NOT NULL,                -- só o ID do YouTube (ex: 'dQw4w9WgXcQ'), não a URL completa
  duration_seconds INT,                    -- pra mostrar 4:32 no card
  order_in_category INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON manual_videos (workspace_id, category, order_in_category)
  WHERE is_active = true;
```

### Decisão: workspace_id (não global)
Cada workspace pode customizar conteúdo (Uniflix tem treinamento próprio). Se quiser conteúdo padrão pra todos, seedar com `workspace_id = '00000000-0000-0000-0000-000000000001'` (superadmin) e fazer `WHERE workspace_id IN (current, superadmin)` — mas adiciona complexidade. **MVP: por workspace direto, com seed só pra Uniflix.**

## Routes

### Pública (auth de reseller)
- `GET /api/reseller/manual` → retorna vídeos agrupados por categoria, ordenados.

### Admin (auth de owner/admin do workspace)
- `GET    /api/admin/manual`            → lista todos (incluindo inativos)
- `POST   /api/admin/manual`            → cria vídeo
- `PUT    /api/admin/manual/[id]`       → edita
- `DELETE /api/admin/manual/[id]`       → soft delete (`is_active = false`)
- `POST   /api/admin/manual/reorder`    → recebe array `[{id, order_in_category}]` pra drag-and-drop

(MVP pode entregar SÓ a rota pública e fazer admin via SQL/seed direto. Bater os 3-4h previstos exige cortar o admin.)

## Components

```
app/(dashboard)/reseller/manual/
├── page.tsx                           # server component, busca + renderiza
└── ManualClient.tsx                   # state + interações

components/manual/
├── CategoryRow.tsx                    # row horizontal scrollável
├── VideoCard.tsx                      # thumb + título + duração + hover
└── VideoPlayer.tsx                    # modal com YouTube embed
```

### Detalhes UX
- **CategoryRow**: scroll horizontal com botões prev/next (estilo Netflix), snap-x no scroll.
- **VideoCard**: thumb do YouTube (`https://i.ytimg.com/vi/{id}/mqdefault.jpg`), título 2 linhas max, duração no canto. Hover destaca + escala 1.05.
- **VideoPlayer**: modal full-screen com `<iframe src="https://www.youtube.com/embed/{id}?autoplay=1&rel=0">`. Click fora fecha. ESC fecha. Botão X.

## Tempo estimado

| Bloco | Tempo |
|---|---|
| Schema + migration + seed (~21 vídeos placeholder) | 30 min |
| API routes (pública + admin CRUD) | 45 min |
| UI (CategoryRow, VideoCard, VideoPlayer, ManualClient) | 1.5 h |
| Polish (animações, responsividade, edge cases) | 1 h |
| **Total** | **~3-4 h** |

### Versão MVP (corte agressivo, ~2h)
- Sem admin UI (gerenciar via SQL).
- Sem reorder drag-and-drop.
- Sem hover animations (estático).
- Manter player modal.

## Pré-requisitos
- F-001 Fase 2.2 ENTREGUE ✅
- Lista de vídeos do YouTube com IDs (Vinicius gera ou reusa do canal Uniflix)

## Mockup textual da UI

```
┌─────────────────────────────────────────────────────────────┐
│ Manual do Afiliado                                          │
│ Bem-vindo! Aqui está tudo que você precisa pra vender mais. │
│                                                             │
│ Primeiros passos                                          ◀▶│
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐               │
│ │ thumb│ │ thumb│ │ thumb│ │ thumb│ │ thumb│               │
│ │ 4:32 │ │ 6:15 │ │ 3:12 │ │ 8:01 │ │ 5:47 │               │
│ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘               │
│ Como     Ativando  Lendo o  Gerencia  Suporte              │
│ acessar  cliente   dash     créditos  rápido               │
│                                                             │
│ Vendas e pitch                                            ◀▶│
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                        │
│ │ thumb│ │ thumb│ │ thumb│ │ thumb│                        │
│ ...                                                         │
│                                                             │
│ WhatsApp e atendimento                                    ◀▶│
│ ...                                                         │
│                                                             │
│ Comissões e saques                                        ◀▶│
│ ...                                                         │
│                                                             │
│ Dicas avançadas                                           ◀▶│
│ ...                                                         │
└─────────────────────────────────────────────────────────────┘

Ao clicar num card:
┌─────────────────────────────────────────────────────────────┐
│                          [X]                                │
│                                                             │
│         ┌────────────────────────────────────┐              │
│         │                                    │              │
│         │      [YouTube embed autoplay]      │              │
│         │                                    │              │
│         └────────────────────────────────────┘              │
│                                                             │
│         Como acessar o painel pela primeira vez             │
│         4:32 · Primeiros passos                             │
│         Vídeo curto explicando login, recuperação de        │
│         senha e tour pelas seções principais...             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Decisões pendentes pra Vinicius
1. **Conteúdo dos vídeos**: vais reusar canal Uniflix ou gravar específico?
2. **Quem mantém**: admin do workspace ou só superadmin?
3. **Ordenação inicial**: alfabética ou curated?
4. **Tracking**: rastrear visualizações (`manual_video_views` table) pra saber qual vídeo é mais consumido? Fora do MVP, mas vale anotar.

## Risco
**Baixo.** Feature isolada, não toca caminho crítico de pagamento/provisionamento. Pode ser desligada com `is_active=false` sem efeito colateral.
