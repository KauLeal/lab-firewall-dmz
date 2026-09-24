#!/bin/bash
# EXPERIMENTO L2 (Enlace) - bloqueio por endereco MAC
# Ciclo: gerar trafego -> observar -> aplicar regra -> testar -> explicar
. "$(dirname "$0")/lib.sh"; verifica_lab
k fw "/root/rules/10-perimetro.sh" >/dev/null

titulo "L2.1 ANTES da regra - pc1 e pc2 se comportam igual"
espera_ok "pc1 -> gateway"      pc1 "ping -c2 -W2 10.0.1.1"
espera_ok "pc2 -> gateway"      pc2 "ping -c2 -W2 10.0.1.1"
espera_ok "pc2 -> Internet"     pc2 "ping -c2 -W2 203.0.113.1"
espera_ok "pc2 -> web da DMZ"   pc2 "curl -s -m4 -o /dev/null http://10.0.2.10/"

titulo "L2.2 OBSERVAR - o firewall enxerga o MAC de origem dos quadros da LAN"
echo "     MACs configurados:"
k pc1 "ip -o link show eth0 | awk '{print \"      pc1 -> \"\$(NF-2)}'"
k pc2 "ip -o link show eth0 | awk '{print \"      pc2 -> \"\$(NF-2)}'"
echo "     tcpdump em fw:eth1 (LAN) enquanto pc2 faz ping:"
k fw "timeout 6 tcpdump -i eth1 -n -e -c 4 icmp > /tmp/l2.txt 2>/dev/null &"
k pc2 "ping -c3 -W1 10.0.2.10 >/dev/null 2>&1"
sleep 6
k fw "cat /tmp/l2.txt" | sed 's/^/      /'

titulo "L2.3 APLICAR a regra (pc2 tratado como host comprometido)"
k fw "/root/rules/20-l2-bloqueia-pc2.sh on" | sed 's/^/      /'

titulo "L2.4 DEPOIS da regra"
espera_ok       "pc1 -> gateway (nao afetado)"        pc1 "ping -c2 -W2 10.0.1.1"
espera_ok       "pc1 -> Internet (nao afetado)"       pc1 "ping -c2 -W2 203.0.113.1"
espera_bloqueio "pc2 -> gateway"                      pc2 "ping -c2 -W2 10.0.1.1"
espera_bloqueio "pc2 -> Internet"                     pc2 "ping -c2 -W2 203.0.113.1"
espera_bloqueio "pc2 -> web da DMZ (HTTP)"            pc2 "curl -s -m4 -o /dev/null http://10.0.2.10/"
espera_bloqueio "pc2 -> DNS da DMZ"                   pc2 "dig +short +time=2 +tries=1 web.lab.local @10.0.2.11 | grep -q 10.0.2.10"

echo "     Contadores da chain LAB_L2 (hits da regra de MAC):"
k fw "iptables -L LAB_L2 -v -n" | sed 's/^/      /'
echo "     Observacao importante: pc2 nao fica sem endereco IP nem sem link;"
echo "     ele continua enviando quadros, mas o firewall os descarta na entrada."

titulo "L2.5 Trocar o MAC contorna o controle?"
echo "     Simulando MAC spoofing em pc2..."
k pc2 "ip link set dev eth0 down; ip link set dev eth0 address 00:00:00:00:01:99; ip link set dev eth0 up; ip address add 10.0.1.11/24 dev eth0 2>/dev/null; ip route add default via 10.0.1.1 2>/dev/null"
sleep 2
espera_ok "pc2 com MAC falsificado volta a passar pelo firewall" pc2 "ping -c2 -W3 10.0.1.1"
echo "     -> Controle por MAC e util para quarentena local, mas nao resiste a spoofing."
echo "     Restaurando o MAC original de pc2..."
k pc2 "ip link set dev eth0 down; ip link set dev eth0 address 00:00:00:00:01:11; ip link set dev eth0 up; ip address add 10.0.1.11/24 dev eth0 2>/dev/null; ip route add default via 10.0.1.1 2>/dev/null"

titulo "L2.6 Removendo a regra"
k fw "/root/rules/20-l2-bloqueia-pc2.sh off" | sed 's/^/      /'
sleep 1
espera_ok "pc2 volta a alcancar o gateway" pc2 "ping -c2 -W3 10.0.1.1"

resumo
