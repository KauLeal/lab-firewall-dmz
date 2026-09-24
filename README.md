# Firewall + DMZ — Segurança de Perímetro e Defense in Depth (Kathará)

Cyber Range reproduzindo exatamente a topologia e o plano de endereçamento da
figura da Task (`../tipologia.png`).

```
                      ( Internet )  203.0.113.0/24
                            |  203.0.113.1  (ok.ext.lab / bad.ext.lab / peer P2P)
                            |
                     [ r0 ] 203.0.113.254        ← roteador de borda + NAT
                            |  eth1 198.51.100.1/30
                            |            WAN 198.51.100.0/30
                            |  eth0 198.51.100.2/30
                     [ fw ] ─────────────────────── firewall / middlebox
            eth1 10.0.1.1/24 │ eth2 10.0.2.1/24 │ eth3 10.0.3.1/24
           ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
           │ LAN 10.0.1.0/24│ │ DMZ 10.0.2.0/24│ │MGMT 10.0.3.0/24│
           │ pc1 .10 pc2 .11│ │ web .10 dns .11│ │ adm .10        │
           └────────────────┘ └────────────────┘ └────────────────┘
```

## Plano de endereçamento

| Rede | Sub-rede | Uso | Gateway |
|---|---|---|---|
| INET | 203.0.113.0/24 | "Internet" simulada | 203.0.113.1 (nó `internet`) |
| WAN | 198.51.100.0/30 | Link r0 ↔ fw | 198.51.100.1 (r0) |
| LAN | 10.0.1.0/24 | Rede interna | 10.0.1.1 (fw eth1) |
| DMZ | 10.0.2.0/24 | Servidores públicos | 10.0.2.1 (fw eth2) |
| MGMT | 10.0.3.0/24 | Gerência (opcional) | 10.0.3.1 (fw eth3) |

| Nó | Endereços | Papel |
|---|---|---|
| `internet` | 203.0.113.1, .10, .66, .67 | nuvem: site permitido, peer P2P, destino proibido (2 IPs) |
| `r0` | 203.0.113.254, 198.51.100.1 | borda: MASQUERADE de saída + DNAT 80/443 → web |
| `fw` | 198.51.100.2, 10.0.1.1, 10.0.2.1, 10.0.3.1 | firewall de perímetro (iptables) |
| `pc1` | 10.0.1.10 — MAC `00:00:00:00:01:10` | estação LAN |
| `pc2` | 10.0.1.11 — MAC `00:00:00:00:01:11` | estação LAN ("host comprometido" no exp. de L2) |
| `web` | 10.0.2.10 | Apache HTTP/HTTPS, com `/public` e `/admin` |
| `dns` | 10.0.2.11 | BIND9 autoritativo (`lab.local`, `ext.lab`) |
| `adm` | 10.0.3.10 | estação de gerência |

> **Nota sobre a figura.** A tabela da figura traz `198.51.100.2` na coluna
> *Gateway* da WAN, enquanto o diagrama rotula `eth0 WAN 198.51.100.2/30` como
> interface do **fw**. Como o /30 só tem dois endereços utilizáveis, adotamos o
> diagrama: **fw eth0 = 198.51.100.2** e **r0 = 198.51.100.1** (gateway do fw).

## Pré-requisitos

```bash
# Kathará (https://www.kathara.org) + Docker
pip install kathara            # ou: pipx install kathara
docker pull kathara/base       # imagem usada por todos os nós
```

<details>
<summary>Como o Kathará foi instalado nesta máquina (Debian sem <code>pip</code>)</summary>

O Debian 13 desta máquina não tinha `pip`, `pipx` nem `python3-venv`, e o pacote
`kathara` 3.8.3 do PyPI não cria o executável `kathara` (não declara
*entry point*). A instalação ficou assim, sem `sudo` e sem tocar nos pacotes do
sistema:

```bash
python3 -m venv --without-pip ~/.local/share/kathara-venv
curl -sS https://bootstrap.pypa.io/get-pip.py | ~/.local/share/kathara-venv/bin/python
~/.local/share/kathara-venv/bin/pip install kathara

cat > ~/.local/bin/kathara <<'EOF'
#!/bin/bash
V=$HOME/.local/share/kathara-venv
exec "$V/bin/python" "$V/lib/python3.13/site-packages/kathara.py" "$@"
EOF
chmod +x ~/.local/bin/kathara
```

`~/.local/bin` já está no `PATH` via `~/.profile`. Para desinstalar:
`rm -rf ~/.local/share/kathara-venv ~/.local/bin/kathara`.
</details>

## Subindo o laboratório

```bash
cd lab-firewall-dmz
kathara lstart              # sobe os 8 nós e abre um terminal em cada um
kathara linfo               # estado do laboratório
kathara exec fw -- bash     # entrar em um nó específico
kathara lclean              # derrubar tudo
```

Para subir sem abrir 8 janelas de terminal: `kathara lstart --noterminals`.

## Roteiro dos experimentos

Todos os testes ficam em `tests/` e rodam **no host** (usam `kathara exec`).
Cada um segue o ciclo pedido: **gerar tráfego → observar → aplicar a regra →
testar de novo → explicar**.

```bash
./tests/run-all.sh                 # bateria completa, salva logs em docs/evidencias/
./tests/00-baseline.sh             # Etapa 1 — topologia e conectividade (baseline)
./tests/01-politica-perimetro.sh   # Etapa 2 — default deny + stateful
./tests/02-l2-enlace.sh            # L2 — bloqueio por MAC (pc2)
./tests/03-l3-rede.sh              # L3 — ICMP entre redes + destino IP proibido
./tests/04-l4-transporte.sh        # L4 — bloqueio de serviços P2P por porta
./tests/05-defense-in-depth.sh     # Etapa 4 — servidor da DMZ comprometido
```

## Regras do firewall

Ficam em `fw/root/rules/` (dentro do nó `fw`, já com bit de execução):

| Script | O que faz |
|---|---|
| `vars.sh` | variáveis comuns (interfaces, redes, MAC de pc2, portas P2P) |
| `00-baseline-permissivo.sh` | Etapa 1: limpa tudo, política `ACCEPT` |
| `10-perimetro.sh` | Etapa 2: **default deny**, stateful, política da tabela |
| `20-l2-bloqueia-pc2.sh on\|off` | L2: descarta quadros com o MAC de pc2 |
| `30-l3a-bloqueia-icmp.sh on\|off` | L3-A: bloqueia ICMP entre LAN e DMZ |
| `31-l3b-bloqueia-destino.sh on\|off` | L3-B: bloqueia a LAN para `203.0.113.66` |
| `40-l4-bloqueia-p2p.sh on\|off` | L4: bloqueia portas de BitTorrent |
| `98-zera-contadores.sh` / `99-status.sh` | evidências: zera e mostra contadores |
| `nftables/perimetro.nft` | a **mesma política** escrita em nftables |

Os experimentos usam chains dedicadas (`LAB_L2`, `LAB_L3`, `LAB_L4`) avaliadas
no topo de `FORWARD`/`INPUT`. Ligar um experimento = preencher a chain;
desligar = esvaziá-la. A política de perímetro permanece intacta o tempo todo.

Ferramentas de observação dentro do `fw`:

- `/root/bin/captura.sh <iface> [filtro] [segundos]` — tcpdump → `.pcap` em
  `/root/capturas/`, abrível no Wireshark;
- `/root/bin/logs.sh [n]` — pacotes negados (`-f` acompanha ao vivo) mais os
  contadores das regras de bloqueio;
- nas estações, `/root/bin/testes.sh` faz uma varredura rápida de conectividade.

> **Por que NFLOG e não LOG.** As regras registram os descartes com
> `-j NFLOG --nflog-group 1`. Dentro de um container, o alvo `LOG` clássico
> escreve no *ring buffer* do kernel do **host** — invisível de dentro do nó (e
> aqui o host ainda tem `kernel.dmesg_restrict=1`). Com NFLOG, um
> `tcpdump -i nflog:1` iniciado no boot grava tudo em `/var/log/fw-drops.log`,
> e a evidência fica onde o experimento acontece.

## Política de perímetro implementada

| Comunicação | Política | Como está implementada |
|---|---|---|
| LAN → Internet | ✅ | `-i eth1 -o eth0 -s 10.0.1.0/24 --ctstate NEW -j ACCEPT` |
| LAN → Web da DMZ | ✅ | apenas TCP 80/443 para 10.0.2.10 |
| LAN → DNS da DMZ | ✅ | apenas 53/UDP e 53/TCP para 10.0.2.11 |
| Internet → Web da DMZ | ✅ | apenas TCP 80/443 para 10.0.2.10 (publicado por DNAT em r0) |
| Internet → LAN | ❌ | `-i eth0 -o eth1 -j NFLOG` + `DROP` (e política `DROP`) |
| DMZ → LAN (novas conexões) | ❌ | `-i eth2 -o eth1 --ctstate NEW -j NFLOG` + `DROP` |
| Respostas de conexões permitidas | ✅ | `--ctstate ESTABLISHED,RELATED -j ACCEPT` |
| Gerência (MGMT) → tudo | ✅ | `-i eth3 -s 10.0.3.0/24 -j ACCEPT` |
| Qualquer outra coisa | ❌ | `-P FORWARD DROP` (**default deny**) |

Além do exigido, aplicamos **menor privilégio** também na saída da DMZ: só o
servidor `dns` fala com a Internet, e só na porta 53. O servidor `web` não
navega — o que reduz bastante o que um invasor consegue fazer depois de
comprometê-lo (download de ferramentas, canal de C2 em HTTP, exfiltração).

## Resultado da validação

Laboratório executado de ponta a ponta (Kathará 3.8.3 + Docker, imagem
`kathara/base`). `tests/run-all.sh`:

| Etapa | Verificações | Divergências |
|---|---|---|
| 1 — topologia e baseline | 15 | 0 |
| 2 — política de perímetro | 13 | 0 |
| L2 — bloqueio por MAC | 12 | 0 |
| L3 — ICMP e destino IP | 8 | 0 |
| L4 — serviços P2P | 7 | 0 |
| 4 — Defense in Depth | 12 | 0 |
| **Total** | **67** | **0** |

## Controle em L7 — proposta

Como controle adicional na camada de aplicação, propõe-se implementar
filtragem DNS para impedir resolução de domínios classificados como
maliciosos ou inadequados. O DNS da DMZ pode aplicar listas de bloqueio
e registrar consultas, permitindo identificar tentativas de acesso a
domínios proibidos.

Como segunda camada de proteção para o servidor Web, pode ser utilizado
um reverse proxy com WAF. O proxy receberia as requisições HTTP/HTTPS
antes do servidor Web e poderia bloquear padrões de ataque de aplicação,
como tentativas de exploração de SQL injection, XSS e requisições
malformadas.

Esses controles complementam o firewall: enquanto L3/L4 controlam
endereços, protocolos e portas, o controle L7 permite analisar o
conteúdo e o contexto da comunicação.
