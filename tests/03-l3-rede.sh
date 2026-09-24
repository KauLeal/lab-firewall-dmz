#!/bin/bash
# EXPERIMENTO L3 (Rede) - A: ICMP entre redes | B: destino IP proibido
. "$(dirname "$0")/lib.sh"; verifica_lab
k fw "/root/rules/10-perimetro.sh" >/dev/null

# --------------------------------------------------------------- A) ICMP ----
titulo "L3-A.1 ANTES - ICMP entre LAN e DMZ funciona"
espera_ok "pc1 -> web da DMZ (ping)" pc1 "ping -c2 -W2 10.0.2.10"

titulo "L3-A.2 OBSERVAR - echo request/reply no fw (interface da DMZ)"
k fw "timeout 6 tcpdump -i eth2 -n -c 4 icmp > /tmp/l3a-antes.txt 2>/dev/null &"
k pc1 "ping -c3 -W1 10.0.2.10 >/dev/null 2>&1"; sleep 6
k fw "cat /tmp/l3a-antes.txt" | sed 's/^/      /'

titulo "L3-A.3 APLICAR a regra de bloqueio de ICMP"
k fw "/root/rules/30-l3a-bloqueia-icmp.sh on" | sed 's/^/      /'

titulo "L3-A.4 DEPOIS"
espera_bloqueio "pc1 -> web da DMZ (ping)"            pc1 "ping -c2 -W2 10.0.2.10"
espera_ok       "pc1 -> web da DMZ (HTTP continua!)"  pc1 "curl -s -m4 -o /dev/null http://10.0.2.10/"
espera_ok       "pc1 -> Internet (ping nao afetado)"  pc1 "ping -c2 -W2 203.0.113.1"
echo "     tcpdump em fw:eth2 durante o ping bloqueado (nada deve sair para a DMZ):"
k fw "timeout 6 tcpdump -i eth2 -n -c 3 icmp > /tmp/l3a-depois.txt 2>/dev/null &"
k pc1 "ping -c3 -W1 10.0.2.10 >/dev/null 2>&1"; sleep 6
k fw "cat /tmp/l3a-depois.txt" | sed 's/^/      /'
echo "     (o pacote e descartado na entrada do fw: nao chega a ser encaminhado a DMZ)"
k fw "/root/rules/30-l3a-bloqueia-icmp.sh off" >/dev/null

# ------------------------------------------------------ B) destino IP -------
titulo "L3-B.1 ANTES - a LAN acessa o destino proibido"
espera_ok "pc1 -> http://203.0.113.66/ (bad.ext.lab)" pc1 "curl -s -m4 http://203.0.113.66/ | grep -q 'bad.ext.lab'"
echo "     O dominio bad.ext.lab resolve para:"
k pc1 "dig +short bad.ext.lab @10.0.2.11" | sed 's/^/      /'

titulo "L3-B.2 APLICAR o bloqueio do destino"
k fw "/root/rules/31-l3b-bloqueia-destino.sh on" | sed 's/^/      /'

titulo "L3-B.3 DEPOIS"
espera_bloqueio "pc1 -> 203.0.113.66 (IP bloqueado)"   pc1 "curl -s -m4 -o /dev/null http://203.0.113.66/"
espera_ok       "pc1 -> 203.0.113.1 (outro destino)"   pc1 "curl -s -m4 -o /dev/null http://203.0.113.1/"

titulo "L3-B.4 A LIMITACAO DO CONTROLE POR IP"
espera_ok "MESMO site continua acessivel por 203.0.113.67" \
          pc1 "curl -s -m4 http://203.0.113.67/ | grep -q 'bad.ext.lab'"
echo "     O dominio tem 2 registros A; bloqueamos so um deles."
echo "     Em um CDN real seriam dezenas de IPs, mudando o tempo todo -"
echo "     e um mesmo IP pode hospedar centenas de sites legitimos (bloqueio excessivo)."
k fw "/root/rules/31-l3b-bloqueia-destino.sh off" >/dev/null

resumo
