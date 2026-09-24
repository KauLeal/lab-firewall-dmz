#!/bin/bash
# =============================================================================
# EXPERIMENTO L2 (ENLACE) - bloquear um dispositivo pelo endereco MAC
#
# Cenario: pc2 foi identificado como dispositivo comprometido.
# Uso: 20-l2-bloqueia-pc2.sh on | off
#
# O match "-m mac --mac-source" le o cabecalho Ethernet do quadro que CHEGOU
# na interface. So funciona porque o fw esta no MESMO dominio de broadcast
# (mesma LAN) que pc2 -- ou seja, e o primeiro salto.
# =============================================================================
. /root/rules/vars.sh
ACAO="${1:-on}"

$IPT -F LAB_L2 2>/dev/null || { echo "Aplique antes /root/rules/10-perimetro.sh"; exit 1; }

if [ "$ACAO" = "on" ]; then
  $IPT -A LAB_L2 -i $LAN_IF -m mac --mac-source $PC2_MAC \
       -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP L2 MAC pc2 "
  $IPT -A LAB_L2 -i $LAN_IF -m mac --mac-source $PC2_MAC \
       -m comment --comment "L2: pc2 ($PC2_MAC) comprometido - quarentena" -j DROP
  echo "[fw] L2 ON  -> todo quadro com MAC de origem $PC2_MAC (pc2) e descartado."
else
  echo "[fw] L2 OFF -> pc2 liberado."
fi

$IPT -L LAB_L2 -v -n --line-numbers
