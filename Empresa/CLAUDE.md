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
