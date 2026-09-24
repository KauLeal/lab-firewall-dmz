#!/bin/bash
# Mostra os pacotes NEGADOS pelo firewall.
#
# As regras usam o target NFLOG (grupo 1): dentro de um container o alvo LOG
# classico escreveria no ring buffer do kernel do HOST, invisivel aqui dentro.
# Um coletor (tcpdump -i nflog:1) roda desde o boot gravando /var/log/fw-drops.log.
#
# Uso: logs.sh [n_linhas]        logs.sh -f   (acompanhar ao vivo)
ARQ=/var/log/fw-drops.log

if [ "$1" = "-f" ]; then
  echo "=== pacotes negados (ao vivo, Ctrl+C para sair) ==="
  exec tcpdump -i nflog:1 -n -e
fi

N="${1:-25}"
echo "=== ultimos $N pacotes negados pelo firewall ==="
if [ -s "$ARQ" ]; then tail -n "$N" "$ARQ"
else echo "(nenhum pacote negado ainda)"; fi
echo
echo "=== qual regra negou: contadores das regras de bloqueio ==="
iptables -L -v -n --line-numbers | grep -E "^Chain|DROP|REJECT|NFLOG" | grep -v " 0     0 "
