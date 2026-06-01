---
title: Infraestrutura — Auditoria 2026-05-21
date: 2026-05-21
---

# 01 — Infraestrutura

## Serviços Docker Swarm (21 stacks)

| Stack | Réplicas | Imagem | OK? |
|-------|----------|--------|-----|
| `wp_zapflix-web` | 1/1 | `zapflix-tech:latest` | ⚠️ 4 restarts em 19h |
| `wp_zapflix-worker` | 1/1 | `easypanel/wp/zapflix-worker:latest` | ✅ estável (3 falhas há 32h) |
| `wp_zapflix-cron` | 1/1 | `zapflix-tech:latest` | ✅ |
| `wp_zapflix-db` | 1/1 | `postgres:17` | ✅ |
| `wp-zapflix-redis` | 1/1 | `redis:7-alpine` | ✅ |
| `wp_zapflix-minio` | 1/1 | `minio/minio:latest` | ✅ |
| `wp_zapflix-checkout` | 1/1 | `zapflix-checkout:latest` | ✅ |
| `wp_zapflix-checkout-db` | 1/1 | `mysql:9` | ✅ |
| `wp_zapflix-admin` | 1/1 | `easypanel/wp/zapflix-admin:latest` | ✅ |
| `wp_zapflix-adminer` | 0/1 | `adminer:latest` | ⚪ desligado |
| `wp_zapflix-monitor` | 0/0 | `zapflix-monitor:latest` | ⚪ escalado a 0 |
| `wp_zapflix-postgrest` | 0/0 | `postgrest/postgrest:v12.2.3` | ⚪ escalado a 0 |
| `wp_evolution-api-2` | 1/1 | `evoapicloud/evolution-api:v2.3.7` | ✅ |

> Confirma a memory [[zapflix_worker_image_separate]]: worker usa imagem separada `easypanel/wp/zapflix-worker:latest`, não a do web.

## Histórico de tasks recentes — web

```
ID             IMAGE                 CURRENT STATE           ERROR
t3iric71zwiv   zapflix-tech:latest   Running 9 hours ago     
jyswk7eccx5j   zapflix-tech:latest   Shutdown 9 hours ago    
zrnyeddczvus   zapflix-tech:latest   Shutdown 15 hours ago   
wjfrni94vzij   zapflix-tech:latest   Shutdown 17 hours ago   
6pfmioe3us56   zapflix-tech:latest   Shutdown 19 hours ago   
```

⚠️ **4 shutdowns em 19h** — sem `ERROR` populado, sugere `SIGTERM`/deploy ou OOM silencioso. Vale checar `dmesg | grep -i kill` e o motivo do redeploy.

## Histórico de tasks recentes — worker

```
ID             CURRENT STATE           ERROR
qew0c1beot3t   Running 32 hours ago    
zn3hx3ukxg8w   Complete 32 hours ago   
1gn2h5i7texp   Failed 32 hours ago     "task: non-zero exit (1)"
qrxdyov04ajg   Failed 32 hours ago     "task: non-zero exit (1)"
egdcyjcawb2c   Failed 32 hours ago     "task: non-zero exit (255)"
```

✅ Estável há 32h — falhas anteriores resolvidas.

## Recursos do host

| Métrica | Valor | Status |
|---------|-------|--------|
| Memória total | 15 Gi | — |
| Memória usada | 5,5 Gi | ✅ |
| Memória disponível | 10 Gi | ✅ |
| Swap usado | 1,2 Gi / 4 Gi | ⚠️ swap em uso, mas folgado |
| Disco / | 58 G / 193 G (30 %) | ✅ |
| Uptime | 1 d 7 h | ✅ |
| Load avg | 2,17 / 0,95 / 0,61 | ⚠️ load 1min alto, pode ser pico |

## Top consumidores

| Container | CPU | Mem |
|-----------|-----|-----|
| `wp_zapflix-web` | 18,22 % | 196 MiB |
| `wp_zapflix-db` (postgres) | 9,38 % | 384 MiB |
| `wp_evolution-api-2` | 5,98 % | 243 MiB |
| `wp_zapflix-minio` | 0,38 % | 362 MiB |
| `wp_zapflix-worker` | 1,05 % | 48 MiB |

Web sozinho consome 18 % CPU — não preocupante, mas é o maior consumidor.

## Itens de ação

- [ ] 🟠 Investigar causa dos 4 restarts do `wp_zapflix-web` (logs estruturados / OOM killer)
- [ ] 🟡 Decidir destino de `wp_zapflix-monitor` e `wp_zapflix-postgrest` (escalar de volta ou remover do stack)
- [ ] 🟢 Verificar se swap em uso (1,2 Gi) é sintoma de memory pressure recorrente
