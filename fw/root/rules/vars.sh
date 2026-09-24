# Variaveis comuns a todos os scripts de regras do firewall (fw)
IPT=iptables

WAN_IF=eth0      # 198.51.100.2/30 -> r0
LAN_IF=eth1      # 10.0.1.1/24
DMZ_IF=eth2      # 10.0.2.1/24
MGMT_IF=eth3     # 10.0.3.1/24

LAN_NET=10.0.1.0/24
DMZ_NET=10.0.2.0/24
MGMT_NET=10.0.3.0/24

WEB=10.0.2.10    # servidor Web da DMZ
DNS=10.0.2.11    # servidor DNS da DMZ

PC1=10.0.1.10
PC2=10.0.1.11
PC2_MAC=00:00:00:00:01:11

# Destino externo proibido pela politica da organizacao (exp. L3-B)
DESTINO_PROIBIDO=203.0.113.66

# Portas tipicamente associadas a BitTorrent (exp. L4)
BT_TCP="6881:6889,51413"
BT_UDP="6881:6889,6969,51413"

# Chains dedicadas aos experimentos por camada.
# Ativar  = preencher a chain;  Desativar = esvaziar a chain (-F).
# Grupo NFLOG usado pelas regras de log (lido por /root/bin/logs.sh)
NFLOG_GROUP=1

LAB_CHAINS="LAB_L2 LAB_L3 LAB_L4"
LAB_SUBCHAINS="LAB_L3_ICMP LAB_L3_DST"
