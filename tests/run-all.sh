#!/bin/bash
# Executa toda a bateria de testes e guarda a saida em docs/evidencias/
cd "$(dirname "$0")"
DEST="../docs/evidencias"; mkdir -p "$DEST"
STAMP="$(date +%Y%m%d-%H%M%S)"
LIMPA='s/\x1b\[[0-9;]*m//g'
for t in 00-baseline.sh 01-politica-perimetro.sh 02-l2-enlace.sh 03-l3-rede.sh 04-l4-transporte.sh 05-defense-in-depth.sh; do
  echo
  echo "###############################################################"
  echo "# $t"
  echo "###############################################################"
  ./"$t" 2>&1 | tee >(sed -r "$LIMPA" > "$DEST/${STAMP}-${t%.sh}.log")
done
echo
echo "Evidencias salvas em $(cd "$DEST" && pwd)"
