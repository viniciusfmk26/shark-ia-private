# Auditoria Noturna — BLOCO 3.4.7

**Data:** 2026-04-29 (madrugada)
**Status:** Aguardando validação manual de Vinicius

## Descobertas técnicas (fechadas)

### Bug 1 — Parser DD/MM/YYYY (RESOLVIDO ✅)
- Causa: Sigma retorna `expiresAt` em formato BR
- Postgres TIMESTAMPTZ rejeita
- Fix: parseSigmaDate() em provision.ts
- Validação: subscription 644352438 tem iptv_expires_at=2026-05-30 ✅

### Bug 2 — INSERT subscription engolia erros (RESOLVIDO ✅)
- Causa: try/catch com console.warn
- Fix: agora retorna 500 com creds no payload
- Validação: comportamento agora é fail-loud

### Bug 3 — Reseller incoerente entre painéis (INVESTIGAR)
- Cliente Zapflix → reseller "super-sharkstreaming"
- Cliente "real" mostrado por Vinicius → reseller "adm-shark"
- Hipótese: Vinicius logado em painel diferente do token
- Resolução depende de qual conta ele realmente tem

## Estado atual sistema

- Saldo: 0 ✓ (debitou último crédito no teste 644352438)
- 3 clientes ativos no Sigma (228766687, 369145659, 644352438)
- 3 subscriptions gravadas no banco
- Build/deploy/health OK

## Bugs separados catalogados

### B-009 (config) — Anual/Semestral apontam pro pacote errado
- annual.sigma_package_id = RYAWRk1jlx (pacote de 3 meses)
- semiannual.sigma_package_id = RYAWRk1jlx (pacote de 3 meses)
- Esperado: ID de pacotes de 12m e 6m respectivamente
- Vinicius precisa achar IDs corretos no painel Sigma

### B-AMPLOPAY-001 — Webhook AmploPay não popula iptv credentials
- Todas subscriptions com source=amplopay têm:
  iptv_username=NULL, iptv_password=NULL
- Significa que clientes Fase 2 nunca tiveram credenciais 
  gravadas no banco Shark Panel
- Mas eles existem no Sigma (Vinicius confirma)
- Bug de tracking, não de provisão

## Próximos passos

1. Vinicius confirma qual conta admin usa em sharks10.top
2. Se "super-sharkstreaming" mas não vê clientes:
   → Cache/filtro/UI do Sigma
   → Talvez listagem agrupa por origem (manual vs webhook)
3. Se "adm-shark":
   → Token em sigma_servers aponta pra sub-conta errada
   → Atualizar sigma_servers com token de adm-shark
4. Refund 1 crédito do teste ghost 644352438
5. Commit BLOCO 3.5 com fixes
6. Documentar tudo no Obsidian
