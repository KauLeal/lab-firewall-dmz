#!/bin/bash
# =============================================================================
# Demonstracao guiada do laboratorio (para gravar o video de ate 5 min).
#
#   ./demo.sh          modo apresentacao: pausa em cada capitulo (ENTER segue)
#   ./demo.sh auto     sem pausas, ritmo automatico (bom para gravar direto)
#
# Cada passo mostra o COMANDO antes de executa-lo, para aparecer no video.
# =============================================================================
cd "$(dirname "$0")"
MODO="${1:-manual}"

B="\033[1m"; C="\033[1;36m"; V="\033[32m"; R="\033[31m"; D="\033[0m"

pausa() {
  if [ "$MODO" = auto ]; then sleep "${1:-2}"; else
    echo -e "\n${B}[ENTER para continuar]${D}"; read -r </dev/tty; fi
}

capitulo() {
  clear
  echo -e "${C}==============================================================${D}"
  echo -e "${C} $* ${D}"
  echo -e "${C}==============================================================${D}\n"
}

# roda mostrando o comando
cmd() {
  echo -e "${B}\$ $*${D}"
  eval "$@"
  echo
}

command -v kathara >/dev/null || { echo "kathara nao encontrado no PATH"; exit 1; }

# ---------------------------------------------------------------- 0:00 ------
capitulo "TOPOLOGIA NO AR  -  Firewall + DMZ + Internet"
cat <<'TOPO'
        ( Internet 203.0.113.0/24 )
                  |
               [ r0 ]  NAT / borda          198.51.100.0/30
                  |
               [ fw ]  firewall de perimetro
      LAN 10.0.1.0/24 | DMZ 10.0.2.0/24 | MGMT 10.0.3.0/24
      pc1 .10 pc2 .11 | web .10 dns .11  | adm .10
TOPO
echo
cmd "kathara exec fw -- ip -br addr"
pausa 4

# ---------------------------------------------------------------- 0:40 ------
capitulo "ETAPA 1  -  Baseline: a rede funciona (firewall sem restricoes)"
cmd "./tests/00-baseline.sh"
pausa 5

# ---------------------------------------------------------------- 1:20 ------
capitulo "ETAPA 2  -  Seguranca de perimetro: default deny + stateful"
cmd "kathara exec fw -- iptables -S | head -3"
echo -e "${B}Politica aplicada:${D} LAN->Internet e LAN->DMZ liberados,"
echo "Internet->LAN e DMZ->LAN negados, respostas de conexoes permitidas passam."
pausa 2
cmd "./tests/01-politica-perimetro.sh"
pausa 5

# ---------------------------------------------------------------- 2:10 ------
capitulo "L2 - ENLACE: pc2 comprometido, bloqueio pelo endereco MAC"
cmd "./tests/02-l2-enlace.sh"
echo -e "${R}Repare:${D} o MAC so e visivel porque o fw e o primeiro salto -"
echo "e trocar o MAC (spoofing) contorna o controle."
pausa 5

# ---------------------------------------------------------------- 2:50 ------
capitulo "L3 - REDE: ICMP entre redes e destino IP proibido"
cmd "./tests/03-l3-rede.sh"
echo -e "${R}Repare:${D} ping bloqueado mas HTTP passando; e o mesmo site"
echo "continua acessivel pelo segundo IP (203.0.113.67)."
pausa 5

# ---------------------------------------------------------------- 3:30 ------
capitulo "L4 - TRANSPORTE: bloqueio de P2P (BitTorrent) por porta"
cmd "./tests/04-l4-transporte.sh"
echo -e "${R}Repare:${D} o mesmo peer responde na porta 80 - bloquear portas"
echo "nao identifica a aplicacao."
pausa 5

# ---------------------------------------------------------------- 4:10 ------
capitulo "DEFENSE IN DEPTH: o servidor Web da DMZ foi comprometido"
cmd "./tests/05-defense-in-depth.sh"
pausa 3

capitulo "CONCLUSAO"
cat <<'FIM'
  O atacante no servidor da DMZ NAO alcanca pc1 nem pc2:

    DMZ separada da LAN ....... nao ha caminho de camada 2
    Default deny .............. o que nao foi liberado, nao passa
    DMZ->LAN (NEW) negado ..... impede o movimento lateral
    DMZ->Internet restrito .... sem download de ferramentas nem canal de C2
    Log + contadores .......... cada tentativa fica registrada

  Se uma camada falhar, as outras ainda limitam o ataque.
FIM
echo
cmd "kathara exec fw -- /root/bin/logs.sh 6"
