#!/bin/bash
# =============================================================================
# EXPERIMENTO L4 (TRANSPORTE) - bloquear servicos P2P (BitTorrent) por porta
#
#   TCP 6881-6889 .... portas classicas de peers BitTorrent
#   TCP 51413 ........ porta padrao do Transmission
#   UDP 6881-6889 .... DHT
#   UDP 6969 ......... tracker UDP
#
# Uso: 40-l4-bloqueia-p2p.sh on | off
# =============================================================================
. /root/rules/vars.sh
ACAO="${1:-on}"

$IPT -F LAB_L4 2>/dev/null || { echo "Aplique antes /root/rules/10-perimetro.sh"; exit 1; }

if [ "$ACAO" = "on" ]; then
  $IPT -A LAB_L4 -p tcp -m multiport --dports $BT_TCP \
       -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP P2P tcp "
  $IPT -A LAB_L4 -p tcp -m multiport --dports $BT_TCP \
       -m comment --comment "L4: BitTorrent TCP bloqueado" -j DROP
  $IPT -A LAB_L4 -p udp -m multiport --dports $BT_UDP \
       -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP P2P udp "
  $IPT -A LAB_L4 -p udp -m multiport --dports $BT_UDP \
       -m comment --comment "L4: BitTorrent UDP/DHT/tracker bloqueado" -j DROP
  echo "[fw] L4 ON  -> P2P bloqueado: TCP $BT_TCP | UDP $BT_UDP"
  echo "     Repare que a MESMA aplicacao na porta 80 passaria sem problema."
else
  echo "[fw] L4 OFF -> portas P2P liberadas."
fi

$IPT -L LAB_L4 -v -n --line-numbers
