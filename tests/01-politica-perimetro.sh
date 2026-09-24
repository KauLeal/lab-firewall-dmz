#!/bin/bash
# ETAPA 2 - Validacao da politica de perimetro (default deny + stateful)
. "$(dirname "$0")/lib.sh"; verifica_lab

echo "Aplicando a politica de perimetro no fw..."
k fw "/root/rules/10-perimetro.sh"
k fw "/root/rules/98-zera-contadores.sh"

titulo "2.1 O que a politica PERMITE"
espera_ok "LAN -> Internet (HTTP)"        pc1 "curl -s -m4 -o /dev/null http://203.0.113.1/"
espera_ok "LAN -> web da DMZ (HTTP)"      pc1 "curl -s -m4 -o /dev/null http://10.0.2.10/"
espera_ok "LAN -> web da DMZ (HTTPS)"     pc1 "curl -sk -m4 -o /dev/null https://10.0.2.10/"
espera_ok "LAN -> dns da DMZ (UDP 53)"    pc1 "dig +short +time=2 +tries=1 web.lab.local @10.0.2.11 | grep -q 10.0.2.10"
espera_ok "Internet -> web da DMZ (servico publicado)" \
                                          internet "curl -s -m4 http://203.0.113.254/ | grep -q DMZ"
espera_ok "MGMT -> qualquer rede (adm -> web)" adm "curl -s -m4 -o /dev/null http://10.0.2.10/"

titulo "2.2 O que a politica BLOQUEIA"
espera_bloqueio "Internet -> LAN (ping em pc1)"       internet "ping -c2 -W2 10.0.1.10"
espera_bloqueio "Internet -> LAN (TCP em pc1)"        internet "nc -z -w3 10.0.1.10 22"
espera_bloqueio "DMZ -> LAN (web inicia conexao p/ pc1)" web "ping -c2 -W2 10.0.1.10"
espera_bloqueio "DMZ -> LAN (TCP novo do web p/ pc1)" web "nc -z -w3 10.0.1.10 80"
espera_bloqueio "LAN -> DMZ em porta nao publicada (22)" pc1 "nc -z -w3 10.0.2.10 22"
espera_bloqueio "DMZ -> Internet fora do permitido (web navegando)" web "curl -s -m4 -o /dev/null http://203.0.113.1/"

titulo "2.3 Filtragem STATEFUL (respostas de conexoes permitidas)"
echo "     A resposta do servidor externo volta porque o conntrack a associa"
echo "     a uma conexao que a LAN iniciou - nao existe regra 'Internet -> LAN' aberta."
espera_ok "resposta HTTP da Internet chega em pc1" \
          pc1 "curl -s -m4 http://203.0.113.1/ | grep -q 'ok.ext.lab'"
echo "     Conexoes no conntrack do fw:"
k fw "(conntrack -L 2>/dev/null || cat /proc/net/nf_conntrack) | head -5" | sed 's/^/      /'

titulo "2.4 Evidencia: contadores e logs de DROP"
k fw "iptables -L FORWARD -v -n --line-numbers | grep -E 'Chain|DROP|ACCEPT' | head -25" | sed 's/^/      /'
echo "     Logs:"
k fw "/root/bin/logs.sh | tail -6" | sed 's/^/      /'

resumo
