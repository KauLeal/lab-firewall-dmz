#!/bin/bash
# Zera os contadores antes de um teste, para que os "hits" sejam so do teste
iptables -Z; iptables -t nat -Z
echo "[fw] contadores zerados."
