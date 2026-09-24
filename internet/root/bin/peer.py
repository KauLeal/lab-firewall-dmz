#!/usr/bin/env python3
"""Peer P2P simulado: responde LAB-P2P-PEER-OK em TCP ou UDP.
Uso: peer.py <tcp|udp> <porta> [ip_de_bind]

O IP de bind importa em UDP: se o socket ficar em 0.0.0.0, a resposta sai com o
IP primario da interface (203.0.113.1) e o conntrack do r0 nao a associa a
conexao que o cliente abriu para 203.0.113.10 - a resposta seria descartada."""
import socket, sys

proto = (sys.argv[1] if len(sys.argv) > 1 else "tcp").lower()
port = int(sys.argv[2]) if len(sys.argv) > 2 else 6881
bind_ip = sys.argv[3] if len(sys.argv) > 3 else "203.0.113.10"
MSG = b"LAB-P2P-PEER-OK\n"

if proto == "udp":
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((bind_ip, port))
    print(f"[peer] escutando UDP {bind_ip}:{port}", flush=True)
    while True:
        data, addr = s.recvfrom(4096)
        s.sendto(MSG, addr)
        print(f"[peer] udp <- {addr[0]}", flush=True)
else:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((bind_ip, port)); s.listen(16)
    print(f"[peer] escutando TCP {bind_ip}:{port}", flush=True)
    while True:
        c, addr = s.accept()
        try:
            c.sendall(MSG)
        finally:
            c.close()
        print(f"[peer] tcp <- {addr[0]}", flush=True)
