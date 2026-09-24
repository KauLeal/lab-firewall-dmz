#!/bin/bash
# ETAPA 4 - Defense in Depth: o servidor Web da DMZ foi comprometido.
# O que o atacante consegue fazer a partir do "web"?
. "$(dirname "$0")/lib.sh"; verifica_lab
k fw "/root/rules/10-perimetro.sh" >/dev/null
k fw "/root/rules/98-zera-contadores.sh" >/dev/null

titulo "4.1 Reconhecimento da LAN a partir do servidor comprometido"
espera_bloqueio "web -> pc1 (ICMP)"            web "ping -c2 -W2 10.0.1.10"
espera_bloqueio "web -> pc2 (ICMP)"            web "ping -c2 -W2 10.0.1.11"
espera_bloqueio "web -> pc1:80 (TCP)"          web "nc -z -w3 10.0.1.10 80"
espera_bloqueio "web -> pc1:22 (SSH)"          web "nc -z -w3 10.0.1.10 22"
espera_bloqueio "web -> pc1:445 (SMB)"         web "nc -z -w3 10.0.1.10 445"
espera_bloqueio "web -> pc1:3389 (RDP)"        web "nc -z -w3 10.0.1.10 3389"
espera_bloqueio "web -> rede de gerencia (adm)" web "ping -c2 -W2 10.0.3.10"

titulo "4.2 Saida para a Internet (download de ferramentas / canal de C2)"
espera_bloqueio "web -> HTTP externo"          web "curl -s -m4 -o /dev/null http://203.0.113.1/"
espera_bloqueio "web -> HTTPS externo"         web "nc -z -w3 203.0.113.1 443"
espera_bloqueio "web -> porta alta arbitraria (C2)" web "nc -z -w3 203.0.113.1 4444"

titulo "4.3 O que AINDA funciona (e por que)"
espera_ok "LAN -> web: o servico continua sendo entregue" \
          pc1 "curl -s -m4 -o /dev/null http://10.0.2.10/"
echo "     A LAN acessa o servidor; o servidor nao acessa a LAN. Essa assimetria"
echo "     vem do conntrack: apenas quem INICIOU a conexao recebe as respostas."
espera_ok "web -> dns da DMZ (mesma rede, nao passa pelo firewall)" \
          web "dig +short +time=2 +tries=1 web.lab.local @10.0.2.11"
echo "     Dentro da DMZ nao ha filtragem: o firewall so ve o que ATRAVESSA redes."
echo "     Por isso o dns tambem precisa de proteccao propria (hardening, patches)."

titulo "4.4 Evidencia: as tentativas ficaram registradas"
k fw "/root/bin/logs.sh 12" | sed 's/^/      /'

resumo
