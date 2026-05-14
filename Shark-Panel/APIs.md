# Módulo: IA / Agentes / APIs

## Responsabilidade
Agentes de IA configuráveis, base de conhecimento, RAG, integrações externas.

## Arquivos principais
```
app/api/master/ai-agents/             → CRUD agentes (master)
app/api/knowledge/                    → base de conhecimento
app/api/knowledge/rag-search/         → busca RAG
app/api/elevenlabs/                   → vozes (text-to-speech)
app/api/marketplace/agents/           → marketplace de agentes
lib/rag/chunker.ts                    → chunking de documentos
lib/rag/embeddings.ts                 → geração de embeddings
lib/rag/similarity.ts                 → busca por similaridade
lib/utils/ai-helpers.ts               → helpers de IA
components/ai/                        → UI de agentes
components/ai/AgentFlowCanvas.tsx     → canvas de fluxo do agente
```

## Tabelas principais
- `ai_agents` — configuração dos agentes
- `knowledge_bases` — bases de conhecimento
- `knowledge_items` — itens/documentos
- `knowledge_documents` — documentos indexados

## Módulos de feature
IA é controlada pelos flags:
- `ai_responses` → habilita respostas automáticas
- `knowledge` → habilita base de conhecimento
- `sales_brain` → habilita Sales Brain

## API pública externa
```
GET  /api/v1/contacts
POST /api/v1/messages/send
```
