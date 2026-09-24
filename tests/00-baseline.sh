#!/bin/bash
# ETAPA 1 - Validacao da baseline (firewall sem regras restritivas)
. "$(dirname "$0")/lib.sh"; verifica_lab

echo "Aplicando baseline permissiva no fw..."
k fw "/root/rules/00-baseline-permissivo.sh"

titulo "1.1 Enderecamento e roteamento"
espera_ok  "pc1 alcanca o gateway (fw eth1 10.0.1.1)"      pc1 "ping -c2 -W2 10.0.1.1"
espera_ok  "fw alcanca o roteador de borda (198.51.100.1)" fw  "ping -c2 -W2 198.51.100.1"
espera_ok  "r0 alcanca a Internet (203.0.113.1)"           r0  "ping -c2 -W2 203.0.113.1"

titulo "1.2 LAN -> Internet (NAT via r0)"
espera_ok  "pc1 -> Internet (ICMP)"   pc1 "ping -c2 -W2 203.0.113.1"
espera_ok  "pc2 -> Internet (ICMP)"   pc2 "ping -c2 -W2 203.0.113.1"
espera_ok  "pc1 -> site externo (HTTP)" pc1 "curl -s -m4 http://203.0.113.1/ | grep -q 'ok.ext.lab'"
echo "     NAT aplicado em r0:"
k r0 "iptables -t nat -L POSTROUTING -v -n | sed -n '1,4p'" | sed 's/^/      /'

titulo "1.3 LAN -> DMZ"
espera_ok  "pc1 -> web da DMZ (ICMP)"  pc1 "ping -c2 -W2 10.0.2.10"
espera_ok  "pc1 -> web da DMZ (HTTP)"  pc1 "curl -s -m4 http://10.0.2.10/ | grep -q 'DMZ'"
espera_ok  "pc1 -> /admin do web"      pc1 "curl -s -m4 http://10.0.2.10/admin/ | grep -q 'admin'"
espera_ok  "pc2 -> web da DMZ (HTTP)"  pc2 "curl -s -m4 -o /dev/null http://10.0.2.10/"

titulo "1.4 Servicos da DMZ (web e dns)"
espera_ok  "DNS resolve web.lab.local"   pc1 "dig +short +time=2 web.lab.local @10.0.2.11 | grep -q 10.0.2.10"
espera_ok  "DNS resolve bad.ext.lab"     pc1 "dig +short +time=2 bad.ext.lab @10.0.2.11 | grep -q 203.0.113"
espera_ok  "HTTP por nome (web.lab.local)" pc1 "curl -s -m4 -o /dev/null http://web.lab.local/"
espera_ok  "HTTPS no web da DMZ"         pc1 "curl -sk -m4 -o /dev/null https://10.0.2.10/"

titulo "1.5 Internet -> Web publicado (DNAT em r0)"
espera_ok  "internet -> 203.0.113.254:80 chega ao web da DMZ" \
           internet "curl -s -m4 http://203.0.113.254/ | grep -q 'DMZ'"

titulo "1.6 O firewall esta encaminhando (baseline: sem restricoes)"
echo "     Politica atual do fw:"
k fw "iptables -S | head -3" | sed 's/^/      /'

resumo
