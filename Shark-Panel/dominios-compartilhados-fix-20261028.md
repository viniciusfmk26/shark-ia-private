# Fix: listagem de landings para superadmin — 28/10/2026

A primeira versão do compartilhamento de domínios passava o retorno de `isSuperAdmin()` diretamente para o parâmetro booleano `$2::boolean` da consulta de domínios. Essa função retorna o ID do usuário quando autorizado, e não `true`. Para o superadmin, PostgreSQL rejeitava o UUID como booleano; a API `/api/iptv/landings` respondia 500 com “Não foi possível completar a operação. Tente novamente.”

Correção: converter explicitamente o resultado para booleano antes da query. O teste de regressão faz `isSuperAdmin()` retornar um UUID e exige o parâmetro `true`. Não houve mudança de banco nem de vínculos existentes.
