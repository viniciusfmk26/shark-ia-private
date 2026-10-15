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

## Feature Meta Ads — 15/10/2026

- A Central de Anúncios oferece **Campanha inteligente**: orçamento diário em BRL, leitura dos 30 dias completos, seleção de campanhas ativas de Leads ou WhatsApp por custo por lead/conversa, preservação da estrutura ABO/CBO, categoria especial e segmentação avançada pela cópia da Meta, prévia com BM/conta e nomes exatos dos objetos novos, criação pausada ou ativação explícita. A revisão final dos anúncios é da Meta.
- A tabela `meta_smart_campaigns` guarda workspace, conexão, usuário, `request_id` único, plano, estado e IDs remotos para impedir duplicação e permitir reconciliação. Migration `20261015_meta_smart_campaigns.sql`. Veja [[feature-campanha-inteligente-meta]].
