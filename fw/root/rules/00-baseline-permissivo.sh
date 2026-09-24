#!/bin/bash
# =============================================================================
# ETAPA 1 - BASELINE (firewall SEM regras restritivas)
# O fw funciona apenas como roteador: tudo e encaminhado.
# Use este script para voltar ao ponto de partida a qualquer momento.
# =============================================================================
. /root/rules/vars.sh

for t in filter nat mangle; do
  $IPT -t $t -F
  $IPT -t $t -X 2>/dev/null
done

$IPT -P INPUT   ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT  ACCEPT

echo "[fw] BASELINE aplicado: politica ACCEPT, nenhuma restricao."
