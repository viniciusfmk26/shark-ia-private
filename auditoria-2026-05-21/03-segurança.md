---
title: Segurança — Auditoria 2026-05-21
date: 2026-05-21
---

# 03 — Segurança

## 🔴 Portas expostas em `0.0.0.0`

| Porta | Serviço | Risco |
|------:|---------|-------|
| **5433** | Postgres (`wp_zapflix-db`) | 🔴 CRÍTICO — acesso direto ao banco |
| **6379** | Redis (`wp-zapflix-redis`) | 🔴 CRÍTICO — sem auth padrão |
| **9000** | MinIO | 🔴 CRÍTICO — bucket público potencial |
| **33060** | MySQL X protocol (checkout-db) | 🔴 CRÍTICO |
| **3000** | Next.js (`wp_zapflix-web`) | 🟠 normal estar atrás de Traefik, mas o bind 0.0.0.0:3000 fora dele permite by-pass |
| 80, 443 | Traefik | ✅ esperado |

### Como confirmar

```bash
ss -tlnp | grep -E "5433|6379|9000|33060|3000"
```

Saída atual mostra todos com `0.0.0.0:*` e `[::]:*` (IPv4 + IPv6). Senha do Postgres ainda é a do `.env` (não rotacionada após figurar em scripts).

### Mitigações (em ordem de aplicação)

1. **UFW/iptables** no host:
   ```bash
   ufw deny in on eth0 to any port 5433
   ufw deny in on eth0 to any port 6379
   ufw deny in on eth0 to any port 9000
   ufw deny in on eth0 to any port 33060
   ufw deny in on eth0 to any port 3000
   ```
2. **EasyPanel** — alterar bind no `compose` para `127.0.0.1:5433:5432` (e equivalentes) e remover o publish público.
3. **Rotacionar credenciais** do Postgres, MinIO e MySQL após (1) — qualquer scan na internet já pode ter capturado banner / tentativa de login.

## 🟡 Endpoints administrativos sensíveis

- `app/api/debug/` — **3 rotas**:
  - `test-download/route.ts` — fetch de URL arbitrária (com `requireSuperAdmin` ✅)
  - `media-check/route.ts`
  - `failed-jobs/route.ts`
- `app/api/migrate/` — **72 rotas**! Cada uma é um script utilitário (clear-dead-jobs, fix-phone-e164-format, cleanup-zapvoice, …).

### Estado da proteção

Amostras inspecionadas (`fix-phone-e164-format`, `check-automations`, `check-pix-settings`, `debug/test-download`) **todas** usam `requireSuperAdmin()` no topo. ✅

### 🟠 Mas — secrets hardcoded como segunda camada

Algumas rotas exigem um header/body `secret` literal:

| Rota | Secret literal |
|------|----------------|
| `fix-phone-e164-format` | `'zapflix-diag-secret'` |
| `check-pix-settings` | `'zapflix-check-inst'` |

Se algum dia o RBAC tiver bug, esses literais são a única defesa — e estão no git em texto plano. Defesa em profundidade quebrada. Substituir por `process.env.MIGRATION_SECRET`.

## ✅ Coisas que NÃO são problema

- **`CRON_SECRET`** — não encontrado em `lib/`; provavelmente vive em rotas específicas ou env. Verificar separadamente.
- **`Math.random`** em `lib/` — nenhuma ocorrência. Bom (nada de PRNG para tokens em libs compartilhadas).

## Itens de ação

- [ ] 🔴 **P0** Firewall nas portas 5433, 6379, 9000, 33060, 3000 (priorizar; pode ser feito em < 10 min)
- [ ] 🔴 **P0** Rotacionar senha Postgres + chaves MinIO após firewall (o `f9734f...` deste relatório vaza nas memórias)
- [ ] 🟠 **P1** Mover secrets literais de `/api/migrate/*` para `process.env.MIGRATION_SECRET`
- [ ] 🟡 **P2** Auditar todas as 72 rotas `/api/migrate/*` — quais ainda são necessárias? Marcar candidatas a remoção
- [ ] 🟡 **P2** Verificar `CRON_SECRET` em uso real (busca em todo o repo, não só `lib/`)
