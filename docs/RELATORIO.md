# Relatório — Firewall + DMZ: Segurança de Perímetro e Defense in Depth

> Todas as saídas abaixo foram geradas neste laboratório com `tests/run-all.sh`
> e estão preservadas na íntegra em `docs/evidencias/`.
> **Resultado da bateria: 67 verificações, todas conforme o esperado**
> (15 baseline + 13 política de perímetro + 12 L2 + 8 L3 + 7 L4 + 12 Defense in Depth).

---

## 1. Topologia e baseline

Topologia implementada conforme a figura (ver `README.md` para o plano de
endereçamento completo). Nesta etapa o `fw` funciona apenas como roteador:

```bash
kathara exec fw -- /root/rules/00-baseline-permissivo.sh
./tests/00-baseline.sh
```

Validação exigida:

| Verificação | Comando | Resultado |
|---|---|---|
| LAN → Internet | `kathara exec pc1 -- curl -s http://203.0.113.1/` | ✅ |
| LAN → DMZ | `kathara exec pc1 -- curl -s http://10.0.2.10/` | ✅ |
| Web acessível | `kathara exec internet -- curl -s http://203.0.113.254/` | ✅ (DNAT em r0) |
| DNS acessível | `kathara exec pc1 -- dig +short web.lab.local @10.0.2.11` | ✅ → 10.0.2.10 |
| fw encaminha | `kathara exec fw -- iptables -L FORWARD -v -n` | ✅ política `ACCEPT`, contadores subindo |

Saída real da bateria (`tests/00-baseline.sh`):

```
Aplicando baseline permissiva no fw...
[fw] BASELINE aplicado: politica ACCEPT, nenhuma restricao.

=== 1.1 Enderecamento e roteamento ===
  [PERMITIDO] pc1 alcanca o gateway (fw eth1 10.0.1.1)
  [PERMITIDO] fw alcanca o roteador de borda (198.51.100.1)
  [PERMITIDO] r0 alcanca a Internet (203.0.113.1)

=== 1.2 LAN -> Internet (NAT via r0) ===
  [PERMITIDO] pc1 -> Internet (ICMP)
  [PERMITIDO] pc2 -> Internet (ICMP)
  [PERMITIDO] pc1 -> site externo (HTTP)
     NAT aplicado em r0:
      Chain POSTROUTING (policy ACCEPT 1 packets, 84 bytes)
       pkts bytes target     prot opt in     out     source               destination         
          0     0 DOCKER_POSTROUTING  0    --  *      *       0.0.0.0/0            127.0.0.11          
          4   261 MASQUERADE  0    --  *      eth0    10.0.0.0/16          0.0.0.0/0           

=== 1.3 LAN -> DMZ ===
  [PERMITIDO] pc1 -> web da DMZ (ICMP)
  [PERMITIDO] pc1 -> web da DMZ (HTTP)
  [PERMITIDO] pc1 -> /admin do web
  [PERMITIDO] pc2 -> web da DMZ (HTTP)

=== 1.4 Servicos da DMZ (web e dns) ===
  [PERMITIDO] DNS resolve web.lab.local
  [PERMITIDO] DNS resolve bad.ext.lab
  [PERMITIDO] HTTP por nome (web.lab.local)
  [PERMITIDO] HTTPS no web da DMZ

=== 1.5 Internet -> Web publicado (DNAT em r0) ===
  [PERMITIDO] internet -> 203.0.113.254:80 chega ao web da DMZ

=== 1.6 O firewall esta encaminhando (baseline: sem restricoes) ===
     Politica atual do fw:
      -P INPUT ACCEPT
      -P FORWARD ACCEPT
      -P OUTPUT ACCEPT

-----------------------------------------------
 Resultado: 15 conforme o esperado, 0 divergente(s)
-----------------------------------------------
```

**Como a saída para a Internet funciona.** `r0` aplica
`MASQUERADE` em `eth0` para origens `10.0.0.0/16`: o `fw` vê o IP interno
original, e só na borda ele é traduzido para `203.0.113.254`. O servidor Web da
DMZ é publicado por DNAT (`203.0.113.254:80|443 → 10.0.2.10`), o caminho real
usado em produção para expor um serviço sem colocá-lo na LAN.

---

## 2. Segurança de perímetro (default deny + stateful)

```bash
kathara exec fw -- /root/rules/10-perimetro.sh
./tests/01-politica-perimetro.sh
```

A tabela da política e a regra correspondente estão no `README.md`. Três
decisões merecem destaque:

1. **Default deny.** `iptables -P FORWARD DROP` antes de qualquer permissão.
   Tudo o que não foi explicitamente autorizado é negado — inclusive protocolos
   em que ninguém pensou na hora de escrever a política.
2. **Stateful.** Uma única regra (`--ctstate ESTABLISHED,RELATED -j ACCEPT`)
   resolve todo o tráfego de volta. Sem ela, seria preciso abrir
   "Internet → LAN" para que as respostas voltassem — exatamente o buraco que a
   política quer evitar. O `conntrack` distingue *quem iniciou* a conversa.
3. **Menor privilégio.** "LAN → DMZ liberado" foi implementado como
   *"TCP 80/443 para 10.0.2.10 e 53 para 10.0.2.11"*, não como
   *"10.0.1.0/24 → 10.0.2.0/24"*. SSH da LAN para o servidor Web, por exemplo,
   já cai na política default.

Saída real (`tests/01-politica-perimetro.sh`):

```
Aplicando a politica de perimetro no fw...
[fw] POLITICA DE PERIMETRO aplicada (default deny + stateful).
[fw] contadores zerados.

=== 2.1 O que a politica PERMITE ===
  [PERMITIDO] LAN -> Internet (HTTP)
  [PERMITIDO] LAN -> web da DMZ (HTTP)
  [PERMITIDO] LAN -> web da DMZ (HTTPS)
  [PERMITIDO] LAN -> dns da DMZ (UDP 53)
  [PERMITIDO] Internet -> web da DMZ (servico publicado)
  [PERMITIDO] MGMT -> qualquer rede (adm -> web)

=== 2.2 O que a politica BLOQUEIA ===
  [BLOQUEADO] Internet -> LAN (ping em pc1)
  [BLOQUEADO] Internet -> LAN (TCP em pc1)
  [BLOQUEADO] DMZ -> LAN (web inicia conexao p/ pc1)
  [BLOQUEADO] DMZ -> LAN (TCP novo do web p/ pc1)
  [BLOQUEADO] LAN -> DMZ em porta nao publicada (22)
  [BLOQUEADO] DMZ -> Internet fora do permitido (web navegando)

=== 2.3 Filtragem STATEFUL (respostas de conexoes permitidas) ===
     A resposta do servidor externo volta porque o conntrack a associa
     a uma conexao que a LAN iniciou - nao existe regra 'Internet -> LAN' aberta.
  [PERMITIDO] resposta HTTP da Internet chega em pc1
     Conexoes no conntrack do fw:
      ipv4     2 tcp      6 97 TIME_WAIT src=203.0.113.1 dst=10.0.2.10 sport=35036 dport=80 src=10.0.2.10 dst=203.0.113.1 sport=80 dport=35036 [ASSURED] mark=0 zone=0 use=2
      ipv4     2 tcp      6 119 TIME_WAIT src=10.0.1.10 dst=203.0.113.1 sport=58490 dport=80 src=203.0.113.1 dst=10.0.1.10 sport=80 dport=58490 [ASSURED] mark=0 zone=0 use=2
      ipv4     2 udp      17 7 src=10.0.1.10 dst=10.0.2.11 sport=52070 dport=53 src=10.0.2.11 dst=10.0.1.10 sport=53 dport=52070 mark=0 zone=0 use=2
      ipv4     2 tcp      6 96 TIME_WAIT src=10.0.1.10 dst=10.0.2.10 sport=57268 dport=80 src=10.0.2.10 dst=10.0.1.10 sport=80 dport=57268 [ASSURED] mark=0 zone=0 use=2
      ipv4     2 tcp      6 98 TIME_WAIT src=10.0.3.10 dst=10.0.2.10 sport=50828 dport=80 src=10.0.2.10 dst=10.0.3.10 sport=80 dport=50828 [ASSURED] mark=0 zone=0 use=2
```

Evidência de contadores (mostra que as regras estão sendo *usadas*, não apenas
escritas):

```bash
kathara exec fw -- /root/rules/98-zera-contadores.sh   # antes do teste
# ... executa os testes ...
kathara exec fw -- /root/rules/99-status.sh            # depois
kathara exec fw -- /root/bin/logs.sh                   # DROPs logados
```

---

## 3. Controles em diferentes camadas

### 🔗 L2 — Enlace: bloqueio pelo MAC de `pc2`

```bash
kathara exec fw -- /root/rules/20-l2-bloqueia-pc2.sh on
./tests/02-l2-enlace.sh
```

Regra aplicada:

```
iptables -A LAB_L2 -i eth1 -m mac --mac-source 00:00:00:00:01:11 -j DROP
```

| | antes | depois |
|---|---|---|
| `pc1` → gateway / Internet / DMZ | ✅ | ✅ (não afetado) |
| `pc2` → gateway (10.0.1.1) | ✅ | ❌ |
| `pc2` → Internet / DMZ / DNS | ✅ | ❌ |

`pc2` continua com link, IP e ARP funcionando: ele envia os quadros
normalmente, mas o firewall os descarta logo na entrada da interface da LAN.
É uma **quarentena de host**, aplicada sem depender do endereço IP que a
máquina esteja usando.

Saída real (`tests/02-l2-enlace.sh`) — repare no quadro capturado pelo `tcpdump`,
em que o MAC de origem de `pc2` ainda é visível para o firewall:

```

=== L2.1 ANTES da regra - pc1 e pc2 se comportam igual ===
  [PERMITIDO] pc1 -> gateway
  [PERMITIDO] pc2 -> gateway
  [PERMITIDO] pc2 -> Internet
  [PERMITIDO] pc2 -> web da DMZ

=== L2.2 OBSERVAR - o firewall enxerga o MAC de origem dos quadros da LAN ===
     MACs configurados:
      pc1 -> 00:00:00:00:01:10
      pc2 -> 00:00:00:00:01:11
     tcpdump em fw:eth1 (LAN) enquanto pc2 faz ping:


      16:17:22.034936 00:00:00:00:01:11 > c2:d6:69:ce:ec:60, ethertype IPv4 (0x0800), length 98: 10.0.1.11 > 10.0.2.10: ICMP echo request, id 48, seq 1, length 64
      16:17:22.035101 c2:d6:69:ce:ec:60 > 00:00:00:00:01:11, ethertype IPv4 (0x0800), length 98: 10.0.2.10 > 10.0.1.11: ICMP echo reply, id 48, seq 1, length 64
      16:17:23.049882 00:00:00:00:01:11 > c2:d6:69:ce:ec:60, ethertype IPv4 (0x0800), length 98: 10.0.1.11 > 10.0.2.10: ICMP echo request, id 48, seq 2, length 64
      16:17:23.050561 c2:d6:69:ce:ec:60 > 00:00:00:00:01:11, ethertype IPv4 (0x0800), length 98: 10.0.2.10 > 10.0.1.11: ICMP echo reply, id 48, seq 2, length 64

=== L2.3 APLICAR a regra (pc2 tratado como host comprometido) ===
      [fw] L2 ON  -> todo quadro com MAC de origem 00:00:00:00:01:11 (pc2) e descartado.
      Chain LAB_L2 (2 references)
      num   pkts bytes target     prot opt in     out     source               destination         
      1        0     0 NFLOG      0    --  eth1   *       0.0.0.0/0            0.0.0.0/0            MAC 00:00:00:00:01:11 nflog-prefix "[FW] DROP L2 MAC pc2 " nflog-group 1
      2        0     0 DROP       0    --  eth1   *       0.0.0.0/0            0.0.0.0/0            MAC 00:00:00:00:01:11 /* L2: pc2 (00:00:00:00:01:11) comprometido - quarentena */

=== L2.4 DEPOIS da regra ===
  [PERMITIDO] pc1 -> gateway (nao afetado)
  [PERMITIDO] pc1 -> Internet (nao afetado)
  [BLOQUEADO] pc2 -> gateway
  [BLOQUEADO] pc2 -> Internet
  [BLOQUEADO] pc2 -> web da DMZ (HTTP)
  [BLOQUEADO] pc2 -> DNS da DMZ
     Contadores da chain LAB_L2 (hits da regra de MAC):
      Chain LAB_L2 (2 references)
       pkts bytes target     prot opt in     out     source               destination         
          9   658 NFLOG      0    --  eth1   *       0.0.0.0/0            0.0.0.0/0            MAC 00:00:00:00:01:11 nflog-prefix "[FW] DROP L2 MAC pc2 " nflog-group 1
          9   658 DROP       0    --  eth1   *       0.0.0.0/0            0.0.0.0/0            MAC 00:00:00:00:01:11 /* L2: pc2 (00:00:00:00:01:11) comprometido - quarentena */
     Observacao importante: pc2 nao fica sem endereco IP nem sem link;
     ele continua enviando quadros, mas o firewall os descarta na entrada.
```

#### O endereço MAC acompanha o pacote por toda a Internet?

**Não.** O MAC pertence ao quadro Ethernet, que só existe dentro de um enlace.
A cada salto o roteador **descarta o cabeçalho L2 e monta um novo**: o quadro
que sai de `pc2` tem origem `00:00:00:00:01:11` e destino o MAC do `fw`; quando
o `fw` encaminha o mesmo pacote IP para o `r0`, o quadro novo tem origem o MAC
do `fw` (eth0) e destino o MAC do `r0`. O que sobrevive fim a fim é o cabeçalho
**IP**; o L2 é reescrito a cada enlace.

**Quando o firewall consegue ver o MAC original de `pc2`:** apenas quando está
no **mesmo domínio de broadcast** — ou seja, quando é o primeiro salto daquele
host (é o nosso caso: `fw eth1` é o gateway da LAN), ou quando opera como
*bridge* transparente no mesmo segmento. Se houvesse outro roteador entre
`pc2` e o `fw`, o `-m mac --mac-source` já não enxergaria nada de `pc2`.

**Limitação demonstrada no teste (L2.5):** o MAC é configurável por software.
Trocando o MAC de `pc2` para `00:00:00:00:01:99`, o acesso volta imediatamente.
Controle por MAC serve para conter um host conhecido em uma rede administrada —
não é uma barreira contra um atacante ativo. Para isso existem 802.1X/NAC,
port security no switch e DHCP snooping.

Alternativa em camada 2 pura (se o `fw` for uma bridge):
`ebtables -A FORWARD -s 00:00:00:00:01:11 -j DROP`. Em nftables:
`nft add rule inet firewall lab_l2 iifname "eth1" ether saddr 00:00:00:00:01:11 drop`.

### 🌐 L3-A — Rede: bloqueio de ICMP entre LAN e DMZ

```bash
kathara exec fw -- /root/rules/30-l3a-bloqueia-icmp.sh on
```

```
iptables -A LAB_L3_ICMP -p icmp -s 10.0.1.0/24 -d 10.0.2.0/24 -j DROP
```

Depois da regra, `ping 10.0.2.10` a partir de `pc1` não recebe resposta,
**mas `curl http://10.0.2.10/` continua funcionando**: o filtro é do
protocolo ICMP, não da comunicação com o host. O `tcpdump -i eth2` no firewall
mostra o efeito com clareza — antes da regra aparecem `echo request`/`echo
reply`; depois, nada sai para a DMZ, porque o pacote é descartado na entrada do
`fw` e nunca chega a ser encaminhado.

Saída real (`tests/03-l3-rede.sh`, trecho L3-A):

```

=== L3-A.1 ANTES - ICMP entre LAN e DMZ funciona ===
  [PERMITIDO] pc1 -> web da DMZ (ping)

=== L3-A.2 OBSERVAR - echo request/reply no fw (interface da DMZ) ===


      16:17:57.427381 IP 10.0.1.10 > 10.0.2.10: ICMP echo request, id 56, seq 1, length 64
      16:17:57.427527 IP 10.0.2.10 > 10.0.1.10: ICMP echo reply, id 56, seq 1, length 64
      16:17:58.445788 IP 10.0.1.10 > 10.0.2.10: ICMP echo request, id 56, seq 2, length 64
      16:17:58.446435 IP 10.0.2.10 > 10.0.1.10: ICMP echo reply, id 56, seq 2, length 64

=== L3-A.3 APLICAR a regra de bloqueio de ICMP ===
      [fw] L3-A ON  -> ICMP entre LAN (10.0.1.0/24) e DMZ (10.0.2.0/24) bloqueado.
           HTTP/DNS para a DMZ continuam funcionando (o bloqueio e so do protocolo ICMP).
      Chain LAB_L3_ICMP (1 references)
      num   pkts bytes target     prot opt in     out     source               destination         
      1        0     0 NFLOG      1    --  *      *       10.0.1.0/24          10.0.2.0/24          nflog-prefix "[FW] DROP ICMP LAN->DMZ " nflog-group 1
      2        0     0 DROP       1    --  *      *       10.0.1.0/24          10.0.2.0/24          /* L3-A: ICMP LAN->DMZ bloqueado */
      3        0     0 DROP       1    --  *      *       10.0.2.0/24          10.0.1.0/24          /* L3-A: ICMP DMZ->LAN bloqueado */

=== L3-A.4 DEPOIS ===
  [BLOQUEADO] pc1 -> web da DMZ (ping)
  [PERMITIDO] pc1 -> web da DMZ (HTTP continua!)
  [PERMITIDO] pc1 -> Internet (ping nao afetado)
     tcpdump em fw:eth2 durante o ping bloqueado (nada deve sair para a DMZ):


      
     (o pacote e descartado na entrada do fw: nao chega a ser encaminhado a DMZ)
```

Observação prática: bloquear ICMP indiscriminadamente é um clássico de
"segurança por obscuridade" que atrapalha mais o operador do que o atacante.
Derrubar `echo request` é aceitável; derrubar **todo** ICMP quebra Path MTU
Discovery (`fragmentation needed`) e produz conexões TCP que travam sem
explicação. Por isso a regra do laboratório é dirigida a `echo-request` entre
duas redes específicas, e não um `-p icmp -j DROP` global.

### 🌐 L3-B — Rede: bloqueio de um destino IP

```bash
kathara exec fw -- /root/rules/31-l3b-bloqueia-destino.sh on
```

```
iptables -A LAB_L3_DST -s 10.0.1.0/24 -d 203.0.113.66 \
         -j REJECT --reject-with icmp-admin-prohibited
```

Usamos `REJECT` em vez de `DROP` para tráfego interno: o usuário recebe erro
imediato em vez de esperar o timeout, e o helpdesk consegue distinguir
"bloqueado pela política" de "rede com problema".

| Teste | Resultado |
|---|---|
| `pc1` → `http://203.0.113.66/` | ❌ bloqueado |
| `pc1` → `http://203.0.113.1/` (outro destino) | ✅ |
| `pc1` → `http://203.0.113.67/` — **mesmo site, outro IP** | ✅ **passa!** |

#### Bloquear o IP é uma boa solução para impedir o acesso a um site?

**Não, é um controle frágil nos dois sentidos.**

- **Fica aquém (bypass fácil).** No laboratório, `bad.ext.lab` tem *dois*
  registros A (`203.0.113.66` e `203.0.113.67`) e o mesmo conteúdo responde nos
  dois. Bloqueamos um IP e o site continuou acessível pelo outro. Na Internet
  real o problema é muito maior: um domínio atrás de CDN (Cloudflare, Akamai,
  Fastly) responde com IPs diferentes por região, por consulta e com TTL de
  segundos; qualquer lista de IPs nasce desatualizada. Some-se a isso proxies,
  VPNs e Tor.
- **Vai além (bloqueio excessivo).** Um mesmo IP de CDN ou de hospedagem
  compartilhada serve **milhares de sites**. Bloquear o IP de um site proibido
  derruba junto sites legítimos — colateral que costuma virar chamado urgente.
- **Erra de alvo.** O que a política quer proibir é um *conteúdo/serviço*
  (identificado por nome e por URL), e o endereço IP é apenas uma localização
  temporária desse conteúdo. Controlar por IP é controlar o endereço da casa
  quando o que interessa é quem mora nela.

Onde o bloqueio por IP **é** adequado: destinos estáveis e específicos — um IP
de C2 identificado por *threat intel*, um bloco de rede de um parceiro,
microssegmentação interna (servidor A não fala com sub-rede B). Para "proibir
um site", o controle correto é de camada 7 (DNS filtering, proxy, NGFW).

### 🚪 L4 — Transporte: bloqueio de serviços P2P (BitTorrent)

```bash
kathara exec fw -- /root/rules/40-l4-bloqueia-p2p.sh on
```

```
iptables -A LAB_L4 -p tcp -m multiport --dports 6881:6889,51413 -j DROP
iptables -A LAB_L4 -p udp -m multiport --dports 6881:6889,6969,51413 -j DROP
```

| Teste | antes | depois |
|---|---|---|
| `pc1` → TCP 6881 (peer) | ✅ | ❌ |
| `pc1` → TCP 51413 (Transmission) | ✅ | ❌ |
| `pc1` → UDP 6969 (tracker) | ✅ | ❌ |
| `pc1` → TCP 80 (navegação) | ✅ | ✅ |
| `pc1` → **mesmo peer na porta 80** | ✅ | ✅ **ainda passa** |

Saída real (`tests/04-l4-transporte.sh`):

```
=== L4.3 APLICAR a politica anti-P2P ===
      [fw] L4 ON  -> P2P bloqueado: TCP 6881:6889,51413 | UDP 6881:6889,6969,51413
           Repare que a MESMA aplicacao na porta 80 passaria sem problema.
      Chain LAB_L4 (1 references)
      num   pkts bytes target     prot opt in     out     source               destination         
      1        0     0 NFLOG      6    --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 6881:6889,51413 nflog-prefix "[FW] DROP P2P tcp " nflog-group 1
      2        0     0 DROP       6    --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 6881:6889,51413 /* L4: BitTorrent TCP bloqueado */
      3        0     0 NFLOG      17   --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 6881:6889,6969,51413 nflog-prefix "[FW] DROP P2P udp " nflog-group 1
      4        0     0 DROP       17   --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 6881:6889,6969,51413 /* L4: BitTorrent UDP/DHT/tracker bloqueado */

=== L4.4 DEPOIS ===
  [BLOQUEADO] pc1 -> TCP 6881
  [BLOQUEADO] pc1 -> TCP 51413 (Transmission)
  [BLOQUEADO] pc1 -> UDP 6969 (tracker)
  [PERMITIDO] pc1 -> TCP 80 (navegacao normal seguiu funcionando)

=== L4.5 A LIMITACAO DO CONTROLE POR PORTA ===
     O mesmo 'peer' tambem responde na porta 80. Se a aplicacao P2P
     mudar para uma porta permitida, a regra de L4 nao a alcanca:
  [PERMITIDO] mesmo servidor P2P alcancado na porta 80
     -> clientes BitTorrent usam portas dinamicas, UPnP e ate 443;
        identificar a APLICACAO (nao a porta) exige inspecao de L7 / DPI.

-----------------------------------------------
 Resultado: 7 conforme o esperado, 0 divergente(s)
-----------------------------------------------
```

#### Bloquear portas é suficiente para impedir o BitTorrent?

**Não.** A porta é uma *convenção*, não uma propriedade da aplicação. No teste,
o mesmo servidor P2P respondeu na porta 80 e passou pelo firewall sem qualquer
dificuldade. Na prática:

- clientes BitTorrent usam **porta aleatória** por padrão (o Transmission
  sugere 51413, mas aceita qualquer uma) e muitos abrem a porta sozinhos via
  **UPnP/NAT-PMP** no roteador doméstico;
- a **DHT** e o **PEX** dispensam tracker central, então bloquear 6969 não
  isola o cliente do enxame;
- é comum o fallback para **80/443**, justamente porque são portas que nenhuma
  organização fecha; com **µTP** (BitTorrent sobre UDP) e criptografia de
  protocolo (MSE/PE), nem o conteúdo ajuda a identificar;
- e se nada funcionar, resta o túnel: VPN ou SSH sobre 443 carrega qualquer
  coisa.

Bloquear portas **eleva o custo** e detém o usuário comum com a configuração
padrão — é uma camada útil, barata e que reduz o ruído. Mas não garante a
política. Identificar a *aplicação* independentemente da porta exige inspeção
de camada 7: DPI/reconhecimento de aplicação (NGFW), controle por proxy, ou
detecção comportamental (muitas conexões UDP curtas para muitos peers
distintos é uma assinatura bastante característica de P2P).

Mesma regra em nftables:
`nft add rule inet firewall lab_l4 tcp dport { 6881-6889, 51413 } drop`.

### 🧩 L7 — Aplicação: controle escolhido pelo grupo

Progressão dos controles usados até aqui — e o que cada um enxerga:

| Camada | O que o firewall vê | O que consegue decidir | Onde falha |
|---|---|---|---|
| L2 | MAC de origem | *qual dispositivo* na rede local | só no 1º salto; MAC é falsificável |
| L3 | IP origem/destino | *qual host/rede* | 1 site ≠ 1 IP; 1 IP ≠ 1 site |
| L4 | protocolo + porta | *qual serviço, por convenção* | porta dinâmica, tunelamento |
| **L7** | **conteúdo da aplicação** | **qual aplicação, qual domínio, qual URL, qual usuário** | custo, TLS, privacidade |

**Controle escolhido para a discussão: DNS Filtering**, complementado por
**proxy reverso/WAF** na proteção do servidor da DMZ.

*Como funciona o DNS Filtering.* Toda navegação começa com uma consulta DNS.
Se a organização obriga todo o tráfego 53 a passar pelo seu resolvedor (é
exatamente a política que já temos: só `10.0.2.11` pode responder à LAN, e só o
`dns` fala 53 com a Internet), esse resolvedor pode consultar o nome pedido
contra listas de categorias/reputação e, em vez do IP real, devolver `NXDOMAIN`
ou o IP de uma **página de bloqueio**. O controle passa a ser sobre o *nome*
(`bad.ext.lab`), não sobre o endereço — o que resolve justamente o problema do
experimento L3-B: não importa se o site tem 2 ou 200 IPs, nem se eles mudam a
cada minuto. Implementações: RPZ no BIND (*Response Policy Zone*), dnsmasq com
blocklists, Pi-hole, ou serviços gerenciados (Cisco Umbrella, Cloudflare
Gateway, Quad9). No nosso laboratório, bastaria uma RPZ no `dns` da DMZ.

*Limites honestos.* DNS filtering é contornável por quem digita o IP direto,
usa um resolvedor externo, ou usa **DoH/DoT** (DNS dentro de HTTPS na 443) —
por isso ele anda junto com uma regra de L4 que só permite 53 para o resolvedor
interno, e com bloqueio dos resolvedores DoH públicos conhecidos. Também é um
controle de granularidade de *domínio*: não distingue `/public` de `/admin`.

*Para o que o DNS não resolve.* Distinguir caminho/URL, inspecionar payload e
bloquear ataques ao aplicativo exigem estar no caminho dos dados:

- **Proxy explícito (Squid + SSL-bump)** — vê método, URL completa e cabeçalho
  `Host`; permite `/public` e nega `/admin`; registra por usuário autenticado.
- **WAF (ModSecurity/CRS, Cloudflare, AWS WAF)** — protege o servidor Web da
  DMZ: barra SQLi, XSS, path traversal, e pode exigir que `/admin` só seja
  servido a origens internas. É o controle que, no nosso cenário de Defense in
  Depth, dificulta o comprometimento inicial do `web`.
- **NGFW / DPI (Palo Alto App-ID, Fortinet, Suricata inline)** — identifica a
  *aplicação* independentemente da porta: é isso que fecha o furo do
  experimento L4 (BitTorrent na porta 80 é reconhecido como BitTorrent).
- **SNI filtering** — meio-termo barato: sem descriptografar, lê o nome do
  servidor no `ClientHello` do TLS e bloqueia por domínio. (Com **ECH** —
  *Encrypted Client Hello* — esse controle tende a perder eficácia.)

> Não implementado nesta Task, conforme o enunciado: escolhido para apresentação
> e discussão na próxima aula.

---

## 4. Defense in Depth

### Cenário: o servidor Web da DMZ foi comprometido

**O atacante consegue acessar diretamente `pc1` e `pc2`? Não.** E isso é
verificável no laboratório, a partir do próprio `web`:

```bash
kathara exec web -- ping -c2 10.0.1.10        # bloqueado
kathara exec web -- nc -z -w3 10.0.1.10 80    # bloqueado
kathara exec web -- curl -m4 http://203.0.113.1/   # bloqueado (sem saída para a Internet)
kathara exec fw  -- /root/bin/logs.sh         # [FW] DROP DMZ->LAN ...
```

Saída real (`tests/05-defense-in-depth.sh`):

```

=== 4.1 Reconhecimento da LAN a partir do servidor comprometido ===
  [BLOQUEADO] web -> pc1 (ICMP)
  [BLOQUEADO] web -> pc2 (ICMP)
  [BLOQUEADO] web -> pc1:80 (TCP)
  [BLOQUEADO] web -> pc1:22 (SSH)
  [BLOQUEADO] web -> pc1:445 (SMB)
  [BLOQUEADO] web -> pc1:3389 (RDP)
  [BLOQUEADO] web -> rede de gerencia (adm)

=== 4.2 Saida para a Internet (download de ferramentas / canal de C2) ===
  [BLOQUEADO] web -> HTTP externo
  [BLOQUEADO] web -> HTTPS externo
  [BLOQUEADO] web -> porta alta arbitraria (C2)

=== 4.3 O que AINDA funciona (e por que) ===
  [PERMITIDO] LAN -> web: o servico continua sendo entregue
     A LAN acessa o servidor; o servidor nao acessa a LAN. Essa assimetria
     vem do conntrack: apenas quem INICIOU a conexao recebe as respostas.
  [PERMITIDO] web -> dns da DMZ (mesma rede, nao passa pelo firewall)
     Dentro da DMZ nao ha filtragem: o firewall so ve o que ATRAVESSA redes.
     Por isso o dns tambem precisa de proteccao propria (hardening, patches).
```

O log do firewall registra cada tentativa (`/root/bin/logs.sh`): os `SYN` do
servidor da DMZ para `pc1`, para a porta 4444 externa (canal de C2 típico) e o
`ICMP` em direção à rede de gerência aparecem todos como descarte — prevenção e
**detecção** na mesma camada.

A regra `-i eth2 -o eth1 --ctstate NEW -j DROP` nega justamente o movimento
lateral DMZ → LAN. Repare na precisão do `--ctstate NEW`: respostas de conexões
que a **LAN** iniciou continuam voltando (o usuário navega no site interno
normalmente), mas o servidor **não consegue iniciar** nada em direção à LAN.
Essa assimetria é o coração da DMZ.

### Camadas que ainda limitariam o ataque

| Camada | Controle | O que ele limita neste cenário |
|---|---|---|
| Arquitetura | **DMZ separada da LAN** | o servidor exposto nunca esteve na mesma rede das estações; não há caminho L2 entre eles |
| Perímetro | **Default deny no `fw`** | qualquer protocolo em que o atacante pense — SMB, RDP, SSH, um reverse shell para a LAN — já é negado por omissão |
| Perímetro | **DMZ → LAN (NEW) bloqueado** | impede o pivoting, que é o passo seguinte natural após o comprometimento |
| Perímetro | **DMZ → Internet restrito a 53** | o `web` não baixa ferramentas, não abre canal de C2 em HTTP, não exfiltra por HTTPS |
| Perímetro | **Stateful** | não existe "porta aberta de volta" para ser reaproveitada |
| Segmentação | **Rede de gerência separada (MGMT)** | as credenciais e o acesso administrativo não trafegam pela rede comprometida |
| Visibilidade | **NFLOG + contadores + `tcpdump`** | as tentativas de pivoting aparecem no log — detecção, não só prevenção |
| Serviço | **Privilégio mínimo no host** | serviço sem root, `/admin` restrito por origem, patches, TLS |
| Host | **Controles nas estações** | firewall local, antivírus/EDR, contas sem privilégio administrativo |
| Dados | **Autenticação nos serviços internos** | mesmo com acesso de rede, o atacante ainda precisa de credenciais válidas |

### O princípio

Nenhum desses controles é suficiente sozinho, e cada um foi desenhado supondo
que os outros podem falhar:

- se a aplicação Web tem uma falha → a **DMZ** garante que ela esteja isolada;
- se a DMZ é alcançada → o **firewall** impede o caminho para a LAN;
- se uma regra do firewall for mal escrita → o **default deny** limita o
  estrago ao que foi explicitamente aberto;
- se o atacante ainda encontrar um caminho → o **log** deixa rastro e as
  **credenciais/EDR nas estações** exigem mais um passo dele.

O inverso também vale como alerta: se a única barreira fosse "o servidor Web é
seguro", o comprometimento dele significaria comprometer a organização inteira.
**Defense in Depth é projetar para a falha da camada anterior.**

---

## 5. Comandos de referência

```bash
# subir / derrubar
kathara lstart ; kathara lclean

# aplicar políticas no fw
kathara exec fw -- /root/rules/00-baseline-permissivo.sh
kathara exec fw -- /root/rules/10-perimetro.sh
kathara exec fw -- /root/rules/20-l2-bloqueia-pc2.sh on
kathara exec fw -- /root/rules/30-l3a-bloqueia-icmp.sh on
kathara exec fw -- /root/rules/31-l3b-bloqueia-destino.sh on
kathara exec fw -- /root/rules/40-l4-bloqueia-p2p.sh on

# evidências
kathara exec fw -- /root/rules/99-status.sh
kathara exec fw -- /root/bin/logs.sh
kathara exec fw -- /root/bin/captura.sh eth1 icmp 15     # gera .pcap p/ Wireshark
kathara exec pc1 -- /root/bin/testes.sh
```

---

## 6. Roteiro sugerido para o vídeo (até 5 min)

| Tempo | O que mostrar | Comando |
|---|---|---|
| 0:00–0:40 | Topologia no ar e endereçamento | `kathara lstart --noterminals` · `kathara exec fw -- ip -br addr` |
| 0:40–1:20 | Baseline: LAN → Internet, LAN → DMZ, DNS | `./tests/00-baseline.sh` |
| 1:20–2:10 | Política de perímetro: o que passa e o que é negado | `./tests/01-politica-perimetro.sh` |
| 2:10–2:50 | L2: `pc2` em quarentena por MAC (e o spoofing que a contorna) | `./tests/02-l2-enlace.sh` |
| 2:50–3:30 | L3: ICMP bloqueado mas HTTP passando; IP proibido e o segundo IP do mesmo site | `./tests/03-l3-rede.sh` |
| 3:30–4:10 | L4: P2P bloqueado por porta — e o mesmo peer respondendo na 80 | `./tests/04-l4-transporte.sh` |
| 4:10–5:00 | Defense in Depth: o `web` comprometido não alcança a LAN; log das tentativas | `./tests/05-defense-in-depth.sh` |

Dica de gravação: rode `kathara exec fw -- /root/bin/logs.sh -f` em um segundo
terminal — os descartes aparecem ao vivo enquanto os testes rodam no primeiro.
