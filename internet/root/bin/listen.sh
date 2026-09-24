#!/bin/bash
# Abre um "servico" TCP ou UDP na porta indicada (simula um peer BitTorrent).
# Uso: listen.sh <tcp|udp> <porta> [ip_de_bind]
PROTO="${1:-tcp}"; PORT="${2:-6881}"; BIND="${3:-203.0.113.10}"
MSG="LAB-P2P-PEER-OK"

# python3 e a opcao mais confiavel (atende varias conexoes e responde em UDP)
if command -v python3 >/dev/null 2>&1 && [ -f /root/bin/peer.py ]; then
  exec python3 /root/bin/peer.py "$PROTO" "$PORT" "$BIND"
fi

if command -v socat >/dev/null 2>&1; then
  if [ "$PROTO" = udp ]; then exec socat -u UDP-RECVFROM:$PORT,fork SYSTEM:"echo $MSG"
  else exec socat TCP-LISTEN:$PORT,fork,reuseaddr SYSTEM:"echo $MSG"; fi
fi

# fallback: netcat tradicional em laco
while true; do
  if [ "$PROTO" = udp ]; then echo "$MSG" | nc -u -l -p $PORT -w 5
  else echo "$MSG" | nc -l -p $PORT; fi
  sleep 0.2
done
