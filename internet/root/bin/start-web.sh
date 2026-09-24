#!/bin/bash
# Sobe os sites externos do laboratorio (Apache com vhosts por IP)
mkdir -p /var/www/ok /var/www/bad
( service apache2 start || /etc/init.d/apache2 start || apachectl start ) >/dev/null 2>&1
sleep 1
ss -lntp 2>/dev/null | grep -q ':80 ' && echo "[internet] apache no ar" || echo "[internet] apache NAO subiu"
