#!/bin/bash
# =============================================================================
# EXPERIMENTO L3-B (REDE) - bloquear o acesso da LAN a um destino IP proibido
#
# 203.0.113.66 = "bad.ext.lab", destino que a organizacao decidiu proibir.
# Repare que o MESMO conteudo continua disponivel em 203.0.113.67 (segundo
# registro A do mesmo dominio) -- e exatamente essa a limitacao do controle
# por endereco IP.
#
# Uso: 31-l3b-bloqueia-destino.sh on | off
# =============================================================================
. /root/rules/vars.sh
ACAO="${1:-on}"

$IPT -F LAB_L3_DST 2>/dev/null || $IPT -N LAB_L3_DST 2>/dev/null
$IPT -C LAB_L3 -j LAB_L3_DST 2>/dev/null || $IPT -A LAB_L3 -j LAB_L3_DST

if [ "$ACAO" = "on" ]; then
  $IPT -A LAB_L3_DST -s $LAN_NET -d $DESTINO_PROIBIDO \
       -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP destino proibido "
  # REJECT (em vez de DROP) da retorno imediato ao usuario - melhor UX interna
  $IPT -A LAB_L3_DST -s $LAN_NET -d $DESTINO_PROIBIDO \
       -m comment --comment "L3-B: destino proibido pela politica" \
       -j REJECT --reject-with icmp-admin-prohibited
  echo "[fw] L3-B ON  -> LAN bloqueada para $DESTINO_PROIBIDO."
  echo "     Teste tambem 203.0.113.67 (mesmo site, outro IP): continua acessivel!"
else
  echo "[fw] L3-B OFF -> destino $DESTINO_PROIBIDO liberado."
fi

$IPT -L LAB_L3_DST -v -n --line-numbers
