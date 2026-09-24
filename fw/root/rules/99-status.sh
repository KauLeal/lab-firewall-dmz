#!/bin/bash
# Mostra a politica ativa com contadores de pacotes (evidencia para o relatorio)
echo "=========== POLITICAS ==========="
iptables -S | head -4
echo
echo "=========== FILTER (com contadores) ==========="
iptables -L -v -n --line-numbers
echo
echo "=========== NAT ==========="
iptables -t nat -L -v -n --line-numbers
echo
echo "=========== CONNTRACK (amostra) ==========="
(conntrack -L 2>/dev/null || cat /proc/net/nf_conntrack 2>/dev/null) | head -20
