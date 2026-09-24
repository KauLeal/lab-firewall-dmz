#!/bin/bash
# =============================================================================
# EXPERIMENTO L3-A (REDE) - bloquear ICMP entre duas redes (LAN <-> DMZ)
# Uso: 30-l3a-bloqueia-icmp.sh on | off
# =============================================================================
. /root/rules/vars.sh
ACAO="${1:-on}"

$IPT -F LAB_L3_ICMP 2>/dev/null || $IPT -N LAB_L3_ICMP 2>/dev/null
$IPT -C LAB_L3 -j LAB_L3_ICMP 2>/dev/null || $IPT -A LAB_L3 -j LAB_L3_ICMP

if [ "$ACAO" = "on" ]; then
  $IPT -A LAB_L3_ICMP -p icmp -s $LAN_NET -d $DMZ_NET \
       -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP ICMP LAN->DMZ "
  $IPT -A LAB_L3_ICMP -p icmp -s $LAN_NET -d $DMZ_NET \
       -m comment --comment "L3-A: ICMP LAN->DMZ bloqueado" -j DROP
  $IPT -A LAB_L3_ICMP -p icmp -s $DMZ_NET -d $LAN_NET \
       -m comment --comment "L3-A: ICMP DMZ->LAN bloqueado" -j DROP
  echo "[fw] L3-A ON  -> ICMP entre LAN (10.0.1.0/24) e DMZ (10.0.2.0/24) bloqueado."
  echo "     HTTP/DNS para a DMZ continuam funcionando (o bloqueio e so do protocolo ICMP)."
else
  echo "[fw] L3-A OFF -> ICMP entre LAN e DMZ liberado."
fi

$IPT -L LAB_L3_ICMP -v -n --line-numbers
