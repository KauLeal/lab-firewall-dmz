#!/bin/bash
# EXPERIMENTO L4 (Transporte) - bloqueio de servicos P2P por porta
. "$(dirname "$0")/lib.sh"; verifica_lab
k fw "/root/rules/10-perimetro.sh" >/dev/null

titulo "L4.1 ANTES - a LAN alcanca o 'peer' BitTorrent"
espera_ok "pc1 -> TCP 6881 em 203.0.113.10"  pc1 "nc -z -w3 203.0.113.10 6881"
espera_ok "pc1 -> UDP 6969 (tracker)"        pc1 "bash -c 'echo ping | nc -u -w2 203.0.113.10 6969 | grep -q LAB'"

titulo "L4.2 OBSERVAR - o trafego saindo pela WAN"
k fw "timeout 6 tcpdump -i eth0 -n -c 4 'tcp port 6881 or udp port 6969' > /tmp/l4.txt 2>/dev/null &"
k pc1 "nc -z -w2 203.0.113.10 6881 >/dev/null 2>&1"; sleep 6
k fw "cat /tmp/l4.txt" | sed 's/^/      /'

titulo "L4.3 APLICAR a politica anti-P2P"
k fw "/root/rules/40-l4-bloqueia-p2p.sh on" | sed 's/^/      /'

titulo "L4.4 DEPOIS"
espera_bloqueio "pc1 -> TCP 6881"                 pc1 "nc -z -w3 203.0.113.10 6881"
espera_bloqueio "pc1 -> TCP 51413 (Transmission)" pc1 "nc -z -w3 203.0.113.10 51413"
espera_bloqueio "pc1 -> UDP 6969 (tracker)"       pc1 "bash -c 'echo ping | nc -u -w2 203.0.113.10 6969 | grep -q LAB'"
espera_ok       "pc1 -> TCP 80 (navegacao normal seguiu funcionando)" pc1 "curl -s -m4 -o /dev/null http://203.0.113.1/"

titulo "L4.5 A LIMITACAO DO CONTROLE POR PORTA"
echo "     O mesmo 'peer' tambem responde na porta 80. Se a aplicacao P2P"
echo "     mudar para uma porta permitida, a regra de L4 nao a alcanca:"
espera_ok "mesmo servidor P2P alcancado na porta 80" \
          pc1 "curl -s -m4 -o /dev/null http://203.0.113.10/"
echo "     -> clientes BitTorrent usam portas dinamicas, UPnP e ate 443;"
echo "        identificar a APLICACAO (nao a porta) exige inspecao de L7 / DPI."

k fw "/root/rules/40-l4-bloqueia-p2p.sh off" >/dev/null
resumo
