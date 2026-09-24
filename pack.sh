#!/bin/bash
# Empacota o laboratorio para entrega
cd "$(dirname "$0")/.."
NOME="firewall-dmz-lab"
tar --exclude='docs/evidencias' --exclude='*.pcap' \
    -czf "${NOME}.tar.gz" lab-firewall-dmz
echo "Pacote gerado: $(pwd)/${NOME}.tar.gz"
