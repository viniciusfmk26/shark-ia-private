#!/bin/bash

# ============================================
# Reorganizador do Vault shark-ia-private v2
# Execute na raiz do vault:
# cd /root/shark-ia-private && bash reorganizar-vault-v2.sh
# ============================================

set -e

VAULT_DIR="$(pwd)"
echo "📁 Vault: $VAULT_DIR"
echo ""

# ── 1. Consolidar sessões soltas na raiz → Zapflix/sessoes/ ──
echo "📅 Consolidando sessões da raiz em Zapflix/sessoes/..."
mkdir -p Zapflix/sessoes
for f in sessoes/*.md; do
  [ -f "$f" ] && mv "$f" Zapflix/sessoes/ && echo "  ✓ $f" || true
done
rmdir sessoes 2>/dev/null && echo "  🗑️  pasta sessoes/ removida" || true

# ── 2. Consolidar sessões de Shark-Panel/produto/ → Shark-Panel/sessoes/ ──
echo ""
echo "📅 Consolidando sessões de Shark-Panel/produto/ em Shark-Panel/sessoes/..."
mkdir -p Shark-Panel/sessoes
for f in Shark-Panel/produto/sessao-*.md; do
  [ -f "$f" ] && mv "$f" Shark-Panel/sessoes/ && echo "  ✓ $f" || true
done

# Mover SESSAO_ da raiz de Shark-Panel também
for f in Shark-Panel/SESSAO_*.md; do
  [ -f "$f" ] && mv "$f" Shark-Panel/sessoes/ && echo "  ✓ $f" || true
done

# ── 3. Remover duplicatas de mapas em auditorias/ (já existem em Shark-Panel/mapas/) ──
echo ""
echo "🗺️  Removendo duplicatas de mapas em auditorias/2026-04-29-fase-2.2/..."
for f in \
  "auditorias/2026-04-29-fase-2.2/mapa-banco.md" \
  "auditorias/2026-04-29-fase-2.2/mapa-fluxos.md" \
  "auditorias/2026-04-29-fase-2.2/mapa-integracoes.md" \
  "auditorias/2026-04-29-fase-2.2/mapa-permissoes.md" \
  "auditorias/2026-04-29-fase-2.2/mapa-rotas.md"; do
  if [ -f "$f" ]; then
    rm "$f" && echo "  🗑️  $f (duplicata removida)"
  fi
done

# ── 4. Remover duplicatas de deep-dives em auditorias/ (já existem em Shark-Panel/deep-dives/) ──
echo ""
echo "🔍 Removendo duplicatas de deep-dives em auditorias/2026-04-29-multitenant-bugs/..."
for f in \
  "auditorias/2026-04-29-multitenant-bugs/deep-automations.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-drip.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-followup-scheduled.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-funnels.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-ia.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-knowledge.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-sales-brain.md" \
  "auditorias/2026-04-29-multitenant-bugs/deep-webchat-recorrencia.md"; do
  if [ -f "$f" ]; then
    rm "$f" && echo "  🗑️  $f (duplicata removida)"
  fi
done

# ── 5. Criar/atualizar CLAUDE.md em Empresa/ ──
echo ""
echo "📝 Atualizando Empresa/CLAUDE.md..."
cat > Empresa/CLAUDE.md << 'EOF'
# shark-ia-private — Vault de Documentação Zapflix

Este repositório contém APENAS documentação. Não contém código fonte.

## Repositório de código
- VPS: /root/Zapflix-Tech
- GitHub: github.com/viniciusfmk26/Zapflix-Tech

## Estrutura do vault
```
shark-ia-private/
├── Empresa/          → arquitetura geral, roadmap, decisões, débitos técnicos
├── Shark-Panel/
│   ├── mapas/        → mapas técnicos (banco, rotas, fluxos, permissões)
│   ├── deep-dives/   → análises profundas de módulos
│   ├── sessoes/      → histórico de sessões de trabalho (SESSAO_* e sessao-*)
│   ├── seguranca/    → secrets, vulnerabilidades, política de senha
│   └── auditorias-tecnicas/ → auditorias técnicas datadas
├── Zapflix/
│   ├── sessoes/      → sessões relacionadas ao produto Zapflix
│   └── estrategia/   → decisões estratégicas e refactors
└── auditorias/       → auditorias históricas completas (referência, não editar)
```

## Regras para o Claude Code
- Para DOCUMENTAÇÃO → edite arquivos neste vault (/root/shark-ia-private)
- Para CÓDIGO → vá para /root/Zapflix-Tech
- NUNCA misture código fonte aqui
- Nova sessão → Shark-Panel/sessoes/SESSAO_YYYY-MM-DD.md
- Nova feature → Shark-Panel/ (arquivo feature-nome.md)
- Novo bug → Shark-Panel/bugs.md
- Nova decisão arquitetural → Empresa/decisoes-arquiteturais.md
EOF
echo "  ✓ CLAUDE.md atualizado"

# ── 6. Verificar o que sobrou fora de lugar ──
echo ""
echo "🔍 Arquivos .md na raiz (deveriam ser zero)..."
ORPHANS=$(find . -maxdepth 1 -name "*.md" 2>/dev/null)
if [ -z "$ORPHANS" ]; then
  echo "  ✓ Nenhum arquivo órfão na raiz"
else
  echo "  ⚠️  Arquivos na raiz (mova manualmente):"
  echo "$ORPHANS" | sed 's/^/     /'
fi

# ── 7. Resultado final ──
echo ""
echo "📊 Estrutura final:"
find . -name "*.md" | sort | sed 's/^/  /'

echo ""
echo "✅ Reorganização concluída!"
echo ""
echo "Próximos passos:"
echo "  git add -A"
echo "  git commit -m 'refactor: consolida sessoes, remove duplicatas de mapas e deep-dives'"
echo "  git push"
