# Exportação DNS para Hostinger (RFC 1035)

Em Domínios, “Baixar zona DNS (.txt · RFC 1035) para Hostinger” entrega um fragmento BIND da zona cadastrada. O arquivo declara `$ORIGIN` e `$TTL`, usa owner relativo, classe `IN` e TTL de 3600 segundos. Inclui o TXT `_sharkpanel-verify` e, se Site/Webhook foi solicitado, o A do painel. O download tem nome `<domínio>-sharkpanel-rfc1035.txt`, exige acesso autorizado ao workspace e não altera DNS.

Na Hostinger, importar em DNS/Nameservers usando **Append**. O arquivo não contém SOA/NS nem registros de e-mail e não deve substituir a zona completa. SPF/MX/DKIM/DMARC existentes exigem revisão separada. O arquivo de exemplo foi analisado com `named-checkzone` após inclusão de SOA/NS sintéticos apenas para validação. A importação real em hPanel não foi testada sem uma conta do proprietário. Referência oficial: https://www.hostinger.com/support/1583249-how-to-manage-dns-records-at-hostinger/.
