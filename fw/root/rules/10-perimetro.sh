#!/bin/bash
# =============================================================================
# ETAPA 2 - FIREWALL DE PERIMETRO (Default Deny + Stateful + Menor Privilegio)
#
#   LAN      -> Internet ............. PERMITIR
#   LAN      -> Web/DNS da DMZ ....... PERMITIR (somente 80/443 e 53)
#   Internet -> Web da DMZ ........... PERMITIR (somente 80/443)
#   Internet -> LAN .................. BLOQUEAR
#   DMZ      -> LAN (novas conexoes) . BLOQUEAR
#   Respostas de conexoes permitidas . PERMITIR (conntrack ESTABLISHED,RELATED)
# =============================================================================
. /root/rules/vars.sh

# ---- 1. Limpa o estado anterior --------------------------------------------
for t in filter mangle; do $IPT -t $t -F; done
for c in $LAB_SUBCHAINS $LAB_CHAINS; do $IPT -F $c 2>/dev/null; $IPT -X $c 2>/dev/null; done

# ---- 2. DEFAULT DENY --------------------------------------------------------
# O que nao for explicitamente permitido e negado.
$IPT -P INPUT   DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT  ACCEPT          # o proprio fw pode falar (gerencia/diagnostico)

# ---- 3. Chains dos experimentos por camada (ficam VAZIAS por enquanto) ------
# Sao avaliadas ANTES do conntrack, para que um bloqueio tenha efeito imediato,
# inclusive sobre conexoes ja estabelecidas.
for c in $LAB_CHAINS; do $IPT -N $c; done
$IPT -A INPUT   -j LAB_L2
$IPT -A FORWARD -j LAB_L2
$IPT -A FORWARD -j LAB_L3
$IPT -A FORWARD -j LAB_L4

# ---- 4. Higiene basica ------------------------------------------------------
$IPT -A INPUT   -i lo -j ACCEPT
$IPT -A INPUT   -m conntrack --ctstate INVALID -j DROP
$IPT -A FORWARD -m conntrack --ctstate INVALID -j DROP

# ---- 5. STATEFUL: respostas de conexoes ja permitidas ----------------------
$IPT -A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED \
     -m comment --comment "respostas de conexoes permitidas" -j ACCEPT
$IPT -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED \
     -m comment --comment "respostas de conexoes permitidas" -j ACCEPT

# ---- 6. Trafego destinado ao PROPRIO firewall (INPUT) ----------------------
# Gerencia (MGMT) tem acesso administrativo completo ao fw
$IPT -A INPUT -i $MGMT_IF -s $MGMT_NET \
     -m comment --comment "MGMT: acesso administrativo ao fw" -j ACCEPT
# Ping ao gateway a partir da LAN/DMZ (diagnostico dos experimentos)
$IPT -A INPUT -i $LAN_IF -s $LAN_NET -p icmp --icmp-type echo-request \
     -m comment --comment "ping ao gateway (LAN)" -j ACCEPT
$IPT -A INPUT -i $DMZ_IF -s $DMZ_NET -p icmp --icmp-type echo-request \
     -m comment --comment "ping ao gateway (DMZ)" -j ACCEPT

# ---- 7. LAN -> Internet  (PERMITIR) ----------------------------------------
$IPT -A FORWARD -i $LAN_IF -o $WAN_IF -s $LAN_NET -m conntrack --ctstate NEW \
     -m comment --comment "LAN -> Internet" -j ACCEPT

# ---- 8. LAN -> DMZ  (PERMITIR apenas os servicos publicados) ---------------
$IPT -A FORWARD -i $LAN_IF -o $DMZ_IF -s $LAN_NET -d $WEB -p tcp \
     -m multiport --dports 80,443 -m conntrack --ctstate NEW \
     -m comment --comment "LAN -> web DMZ (HTTP/HTTPS)" -j ACCEPT
$IPT -A FORWARD -i $LAN_IF -o $DMZ_IF -s $LAN_NET -d $DNS -p udp --dport 53 \
     -m conntrack --ctstate NEW \
     -m comment --comment "LAN -> dns DMZ (UDP)" -j ACCEPT
$IPT -A FORWARD -i $LAN_IF -o $DMZ_IF -s $LAN_NET -d $DNS -p tcp --dport 53 \
     -m conntrack --ctstate NEW \
     -m comment --comment "LAN -> dns DMZ (TCP)" -j ACCEPT
# ICMP LAN -> DMZ liberado para os testes de diagnostico (sera bloqueado no exp. L3-A)
$IPT -A FORWARD -i $LAN_IF -o $DMZ_IF -s $LAN_NET -p icmp --icmp-type echo-request \
     -m comment --comment "LAN -> DMZ (ping de diagnostico)" -j ACCEPT

# ---- 9. Internet -> Web da DMZ  (PERMITIR) ---------------------------------
$IPT -A FORWARD -i $WAN_IF -o $DMZ_IF -d $WEB -p tcp \
     -m multiport --dports 80,443 -m conntrack --ctstate NEW \
     -m comment --comment "Internet -> web DMZ (servico publicado)" -j ACCEPT

# ---- 10. DMZ -> Internet (menor privilegio: so o que o servico precisa) ----
$IPT -A FORWARD -i $DMZ_IF -o $WAN_IF -s $DNS -p udp --dport 53 \
     -m comment --comment "dns DMZ -> Internet (resolucao externa)" -j ACCEPT
$IPT -A FORWARD -i $DMZ_IF -o $WAN_IF -s $DNS -p tcp --dport 53 \
     -m comment --comment "dns DMZ -> Internet (resolucao externa)" -j ACCEPT

# ---- 11. MGMT -> qualquer rede (gerencia) ----------------------------------
$IPT -A FORWARD -i $MGMT_IF -s $MGMT_NET \
     -m comment --comment "MGMT -> todas as redes" -j ACCEPT

# ---- 12. BLOQUEIOS EXPLICITOS (com LOG, para gerar evidencia) --------------
# Internet -> LAN : nenhuma conexao nova vinda de fora entra na rede interna
$IPT -A FORWARD -i $WAN_IF -o $LAN_IF -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP WAN->LAN "
$IPT -A FORWARD -i $WAN_IF -o $LAN_IF \
     -m comment --comment "Internet -> LAN BLOQUEADO" -j DROP
# DMZ -> LAN : servidor da DMZ nao inicia conexao para dentro (anti-pivoting)
$IPT -A FORWARD -i $DMZ_IF -o $LAN_IF -m conntrack --ctstate NEW \
     -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP DMZ->LAN "
$IPT -A FORWARD -i $DMZ_IF -o $LAN_IF -m conntrack --ctstate NEW \
     -m comment --comment "DMZ -> LAN (novas conexoes) BLOQUEADO" -j DROP

# ---- 13. Tudo o mais cai na politica default (DROP), com log ---------------
$IPT -A FORWARD -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP default "
$IPT -A INPUT   -j NFLOG --nflog-group $NFLOG_GROUP --nflog-prefix "[FW] DROP input "

echo "[fw] POLITICA DE PERIMETRO aplicada (default deny + stateful)."
