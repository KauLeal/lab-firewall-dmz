#!/bin/bash
# Captura trafego numa interface do firewall e salva em /root/capturas/
# Uso: captura.sh <eth0|eth1|eth2|eth3> [filtro bpf] [segundos]
IFACE="${1:-eth1}"; FILTRO="${2:-}"; SEGS="${3:-15}"
mkdir -p /root/capturas
ARQ="/root/capturas/$(date +%H%M%S)-${IFACE}.pcap"
echo "[fw] capturando ${SEGS}s em ${IFACE} (filtro: ${FILTRO:-nenhum}) -> $ARQ"
timeout "$SEGS" tcpdump -i "$IFACE" -n -e -s0 -w "$ARQ" $FILTRO
echo "[fw] leitura rapida:"
tcpdump -n -e -r "$ARQ" 2>/dev/null | head -20
