#!/bin/bash
# Bateria de testes de conectividade executada de dentro de uma estacao
ok(){ echo "  [ OK   ] $1"; }; falha(){ echo "  [ FALHA] $1"; }
t(){ if eval "$1" >/dev/null 2>&1; then ok "$2"; else falha "$2"; fi; }

echo "== $(hostname) ($(ip -4 -o addr show dev eth0 | awk '{print $4}')) =="
t "ping -c1 -W2 10.0.1.1"                      "gateway/firewall (10.0.1.1)"
t "ping -c1 -W2 10.0.2.10"                     "ICMP -> web da DMZ (10.0.2.10)"
t "ping -c1 -W2 203.0.113.1"                   "ICMP -> Internet (203.0.113.1)"
t "curl -s -m3 -o /dev/null http://10.0.2.10/" "HTTP -> web da DMZ"
t "curl -s -m3 -o /dev/null http://203.0.113.1/" "HTTP -> site externo permitido"
t "curl -s -m3 -o /dev/null http://203.0.113.66/" "HTTP -> destino proibido (203.0.113.66)"
t "curl -s -m3 -o /dev/null http://203.0.113.67/" "HTTP -> mesmo site, IP alternativo (.67)"
t "dig +short +time=2 +tries=1 web.lab.local @10.0.2.11" "DNS -> dns da DMZ"
t "nc -z -w3 203.0.113.10 6881"                "P2P TCP 6881 (BitTorrent)"
t "nc -z -w3 203.0.113.1 80"                   "TCP 80 para a Internet"
