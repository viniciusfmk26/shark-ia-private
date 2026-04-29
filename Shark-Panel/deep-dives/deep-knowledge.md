# 🦈 Deep Dive — Knowledge Bases / RAG

**Escopo:** sistema de Knowledge Base estruturado (FAQ-like com Q/A) e ingestão de documentos com chunks/embeddings. Tabelas: `knowledge_bases`, `knowledge_documents`, `knowledge_chunks`, `knowledge_items`, `knowledge_categories`, `knowledge_templates`.

**TL;DR:**
- 🔴 **pgvector NÃO está instalado.** A coluna `knowledge_chunks.embedding` é tipo `text`, não `vector`. **Não há similarity search vetorial real.** Embeddings, se existissem, seriam strings JSON arrastando em distance functions custom.
- **Adoption ≈ ZERO em prod**: 5 knowledge_bases (todas chamadas "aa" — claramente teste), 0 documents, 0 chunks, 0 items, 0 categories.
- **3 templates pré-configurados** com 46 items totais (IPTV/Streaming, Clínica/Dentista, Loja de Veículos).
- O **único uso REAL** é via `knowledge_items` (FAQ Q/A) consumido por `/api/ai/suggest` e ação `search_knowledge` em guided funnels — busca via ILIKE + array overlap, **sem embeddings, sem RAG vetorial**.
- Sistema de chunks/documents está completamente inerte. UI existe (1.164 linhas) mas ninguém populou.

---

## 1. Schema

### 1.1 `knowledge_bases` — agrupador
```
id, workspace_id (default '0...001' superadmin)
name (text), description, status default 'active'
document_count, chunk_count    -- cache (não atualizado automaticamente)
```

### 1.2 `knowledge_documents` — arquivo upload
```
id, knowledge_base_id (FK CASCADE)
name, type (text|pdf|markdown|...)
content (text)              -- texto cru
file_url, file_size
status default 'pending'    -- pending|processing|done|failed
chunk_count, error
```

### 1.3 `knowledge_chunks` — pedaços para RAG
```
id, document_id (FK CASCADE)
content (text NOT NULL)
embedding (text)            -- 🔴 deveria ser vector(1536), está text
token_count, metadata (jsonb)
```

**Indexes:** apenas btree em document_id. Sem GIN, sem HNSW, sem IVFFlat.

### 1.4 `knowledge_items` — Q/A estruturado (FAQ)
```
id, workspace_id, category_id (FK)
question (text NOT NULL)
answer (text NOT NULL)
keywords text[]              -- array de termos para match exato
images (jsonb)               -- [{url,caption}]
metadata (jsonb)
is_active, sort_order
GIN keywords (idx_knowledge_items_keywords)
```

**Esta é a tabela funcional.** Buscas por ILIKE + array overlap (`keywords && $::text[]`).

### 1.5 `knowledge_categories`
```
id, workspace_id, parent_id (self-FK SET NULL)
name, icon (default 📁), color, sort_order
```
Hierárquica via parent_id.

### 1.6 `knowledge_templates` — niches pré-feitos
```
id, niche_name, niche_icon, niche_color, description
categories (jsonb)    -- array de {name, icon, color}
items (jsonb)         -- array de {category_name, question, answer, keywords, metadata}
```

3 templates em prod:
| niche_name | icon | cats | items |
|------------|------|------|-------|
| IPTV / Streaming | 📺 | 5 | 16 |
| Clínica / Dentista | 🏥 | 4 | 15 |
| Loja de Veículos | 🚗 | 4 | 15 |

---

## 2. Estado em prod

```
knowledge_bases:        5 rows (TODAS com name='aa', 4 com workspace_id órfão)
knowledge_documents:    0 rows
knowledge_chunks:       0 rows  (size: 24 kB — só o overhead da tabela)
knowledge_items:        0 rows  (size: 136 kB)
knowledge_categories:   0 rows
knowledge_templates:    3 rows
```

Por workspace:
| workspace | bases | items | cats |
|-----------|-------|-------|------|
| shark-panel | 1 | 0 | 0 |
| (outros) | 0 | 0 | 0 |
| (4 órfãos sem workspace correspondente) | 4 | 0 | 0 |

**Feature foi construída, UI desenvolvida, mas zero adoption real.**

---

## 3. pgvector — NÃO instalado

```sql
SELECT extname FROM pg_extension WHERE extname='vector';
-- 0 rows
```

Implicação:
- A coluna `knowledge_chunks.embedding text` armazenaria strings JSON (ex: `"[0.001, 0.234, ...]"`).
- Cosine/euclidean similarity precisaria ser feito **na aplicação** após SELECT de TODOS os chunks → custo O(n) e impossível em escala.
- **Search por embeddings é teoricamente possível mas inviável**.

Para ativar pgvector:
```sql
CREATE EXTENSION vector;
ALTER TABLE knowledge_chunks ALTER COLUMN embedding TYPE vector(1536) USING NULL;
CREATE INDEX ON knowledge_chunks USING hnsw (embedding vector_cosine_ops);
```

Mas como nada está populado, é trivial migrar quando for usar de fato.

---

## 4. API Routes (11 rotas)

| Rota | Linhas | Função |
|------|--------|--------|
| `GET/POST /api/knowledge/bases` | 85 | CRUD knowledge_bases |
| `GET/POST/DEL /api/knowledge/items` | 80 | CRUD items |
| `POST /api/knowledge/items/bulk` | n/a | Bulk insert |
| `PUT/DEL /api/knowledge/items/[id]` | n/a | Item CRUD |
| `GET/POST /api/knowledge/categories` | n/a | CRUD categories |
| `PUT/DEL /api/knowledge/categories/[id]` | n/a | Category CRUD |
| `GET /api/knowledge/documents` | n/a | List docs |
| `POST /api/knowledge/upload` | 31 | Upload imagem para anexar a item (max 5MB, jpg/png/webp/gif) |
| `GET /api/knowledge/search` | 37 | **Busca em items via ILIKE + keywords overlap** |
| `GET /api/knowledge/templates` | 21 | List templates |
| `POST /api/knowledge/templates/install` | 71 | Instala template (cria categories + items) |
| `GET /api/ai/knowledge` | 43 | Lê **conversation_knowledge** (não é knowledge_items!) — paginação |

### 4.1 `/api/knowledge/search` (route.ts:6-36)

```sql
SELECT i.*, c.name AS category_name, c.icon
FROM knowledge_items i
LEFT JOIN knowledge_categories c ON c.id = i.category_id
WHERE i.workspace_id = $1
  AND i.is_active = true
  AND (
    i.question ILIKE '%query%'
    OR i.answer ILIKE '%query%'
    OR i.keywords && $words::text[]
  )
ORDER BY 
  CASE WHEN question ILIKE '%query%' THEN 0 ELSE 1 END,  -- prioriza match em pergunta
  sort_order ASC
LIMIT 10
```

**Sem ranking semântico. Sem embeddings.** Match por substring + array overlap.

### 4.2 `/api/knowledge/upload` (route.ts:5-30)
- Apenas imagens (max 5MB).
- Upload S3/MinIO via `lib/s3.ts`.
- Retorna `publicUrl` que é gravado em `knowledge_items.images[]`.

### 4.3 `/api/knowledge/templates/install`
- Lê template (`knowledge_templates`).
- Cria todas categorias do template no workspace.
- Cria todos items mapeando `category_name → category_id`.
- Não cria knowledge_base — items vão soltos no workspace (sem KB pai).

### 4.4 `/api/ai/knowledge` ≠ knowledge_items
**Confusão de nomenclatura:** `/api/ai/knowledge` lista `conversation_knowledge` (resumos de conversas processadas via gpt-4o-mini), não `knowledge_items`. Coexistem dois "conhecimentos":
- **knowledge_items**: FAQ manual (não usado em prod).
- **conversation_knowledge**: RAG histórico processado pelo `/api/ai/process-conversations` (9.190 rows em prod).

---

## 5. Onde knowledge é consumido

### 5.1 `/api/ai/suggest` (inbox suggest)
```sql
SELECT question, answer, images, metadata
FROM knowledge_items
WHERE workspace_id = $1 AND is_active = true
  AND (question ILIKE $2 OR answer ILIKE $2 OR keywords && $3::text[])
LIMIT 5
```
Combina com `conversation_knowledge` full-text PT-BR para construir contexto.

### 5.2 Worker — `search_knowledge` action em guided funnel (worker.ts:2941)
```sql
SELECT question, answer FROM knowledge_items
WHERE workspace_id = $1 AND is_active = true
  AND (question ILIKE $2 OR answer ILIKE $2 OR keywords && $3::text[])
ORDER BY CASE WHEN question ILIKE $2 THEN 0 ELSE 1 END
LIMIT 1
```
Quando usuário clica numa opção do funil com `action='search_knowledge'`, busca um único item (label como searchTerm) e responde com `answer`. Como knowledge_items=0 em prod, sempre retorna fallback "ℹ️ Não encontrei informações específicas".

### 5.3 AI Agent (worker.ts handleAIAgentResponse)
Tem código para incluir knowledge na prompt do agente, mas como agent.status=inactive, nunca executa.

---

## 6. UI

`app/(dashboard)/knowledge/page.tsx` (1164 linhas, monolítica):
- Layout com sidebar de categorias + lista de items.
- Modais para criar/editar item, upload de imagens.
- Botão "Importar template" (instala um dos 3 templates).
- Editor rich-text para answer.

**Não há UI** para:
- Upload de documentos (apesar de `/api/knowledge/documents` existir).
- Visualização de chunks.
- Geração de embeddings.

A feature documents/chunks está **completamente desconectada do frontend**.

---

## 7. Fluxo E2E

### Caso A: Operador busca "instalação android" no inbox
```
1. Frontend chama /api/knowledge/search?q=instalacao+android
2. Endpoint: ILIKE %instalacao android% OR keywords && {instalacao,android}
3. Retorna items[] (em prod: vazio, 0 items)
4. Operador colaria a resposta na conversa manualmente
```

### Caso B: Funil tem action `search_knowledge`
```
1. Cliente envia "1" (opção do menu)
2. Worker pega step.options[matched].action = 'search_knowledge'
3. searchTerm = matched.label (ex: "Como ativar?")
4. Worker faz ILIKE em knowledge_items
5. Em prod: 0 results → envia "ℹ️ Não encontrei..."
6. Re-envia step atual para usuário tentar de novo
```

### Caso C (NÃO funcional): RAG via embeddings
- Endpoint para gerar embeddings: **NÃO EXISTE**.
- Endpoint para indexar PDF: **NÃO EXISTE**.
- Cron de processamento: **NÃO EXISTE**.

---

## 8. Bugs / débitos

### 8.1 🔴 BUG CRÍTICO: pgvector não instalado, embedding column é text
A arquitetura sugere RAG vetorial, mas tipo `text` torna similarity search inviável. **Decisão pendente**: instalar pgvector OU dropar `knowledge_documents` + `knowledge_chunks` se não vão usar.

### 8.2 BUG: 4 knowledge_bases órfãs (workspace_id apontando pra workspace inexistente)
```
SELECT * FROM knowledge_bases WHERE workspace_id NOT IN (SELECT id FROM workspaces);  -- 4 rows
```
Não tem FK constraint para CASCADE. Knowledge_bases pode apontar pra workspace deletada. **Adicionar FK + cleanup.**

### 8.3 BUG: `knowledge_bases.workspace_id` default '0...001' (superadmin)
Mesmo problema que `funnels`. Multi-tenant errado por default.

### 8.4 BUG: 5 KBs todas chamadas "aa"
Limpeza de teste. Nenhuma KB real foi criada.

### 8.5 BUG: `document_count` e `chunk_count` em knowledge_bases não atualizam
Não há trigger nem código que faça `UPDATE knowledge_bases SET chunk_count = ...`. Se docs forem inseridos, contadores ficam desatualizados.

### 8.6 BUG: `/api/knowledge/templates/install` não cria knowledge_base parent
Items vão soltos no workspace. UI provavelmente espera items dentro de uma KB → pode não exibir corretamente.

### 8.7 BUG: `knowledge_items.metadata` jsonb ignorada
Schema permite metadata mas search não usa, suggest não usa. Campo morto.

### 8.8 INCONSISTÊNCIA: dois "knowledge" diferentes
- `knowledge_items` — FAQ manual (não usado em prod).
- `conversation_knowledge` — RAG de conversas processadas (9k rows).

UI/endpoints misturam: `/api/ai/knowledge` lê `conversation_knowledge`, `/api/knowledge/search` lê `knowledge_items`. Operadores ficam confusos.

### 8.9 BUG: Search não aceita acentos
`ILIKE '%instalacao%'` não pega "instalação". Sem `unaccent` extension ou normalização. Português é especialmente sensível.

```sql
-- Fix sugerido:
CREATE EXTENSION unaccent;
WHERE unaccent(question) ILIKE unaccent('%' || $2 || '%')
```

### 8.10 BUG: Sem rate limit no upload
`/api/knowledge/upload` aceita até 5MB sem rate limit por workspace. Atacante autenticado podia entupir storage.

---

## 9. Custos

### Storage
- Hoje: knowledge_chunks 24 kB (vazia), knowledge_items 136 kB (vazia). **<200 kB total.**
- Se ativado com 1.000 items × ~2kB ≈ 2 MB.
- Se ativado com pgvector + 10k chunks × 6kB (1536 floats × 4 bytes) ≈ 60 MB.

### CPU
- Search atual: ILIKE em LIMIT 10 — <1ms com index ausente, mas 0 rows hoje.
- Embedding generation (futuro): ~$0.02/1M tokens (text-embedding-3-small) → 1k items × 500 tokens ≈ $0.01.

### Tokens IA
- Atualmente zero — nenhum embedding sendo gerado.
- Se ativado: chunking + embedding um-shot = $1-5 USD para uma KB de 1.000 docs.

**Custo atual: 0. Custo se ativado em escala média: <$5/mês.**

---

## 10. Resumo executivo

1. **Feature pronta, adoption ZERO.** 5 KBs de teste, 0 items reais, 0 docs.
2. **🔴 RAG vetorial é fake:** pgvector não instalado, embedding text. Refatorar antes de prometer "RAG" pra clientes.
3. **knowledge_items** (FAQ) é o que a IA realmente consulta — ativar templates pré-feitos seria quick-win para operadores.
4. **conversation_knowledge é RAG dos clientes mesmo:** 9.190 conversas processadas + analyzed servem como base de respostas similares (já consumido por suggest).
5. **Decisões pendentes:**
   - Instalar pgvector e popular embeddings, OU
   - Dropar `knowledge_documents` + `knowledge_chunks` (deixar só items + categories).
   - Conectar UI ao caminho de ingestão de PDF.
6. **Cleanup imediato:** deletar 5 KBs "aa" e os 4 órfãos.
