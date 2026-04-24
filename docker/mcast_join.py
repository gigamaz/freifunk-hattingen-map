#!/usr/bin/env python3
"""
Hält batman-adv Multicast-Gruppen für respondd aktiv.
Batman-adv 2024.0 sendet Multicasts nur wenn lokale Listener registriert sind.
"""
import socket, struct, select, sys, signal

IFACE = 'bat0'
IFINDEX = socket.if_nametoindex(IFACE)
GROUPS = ['ff05::2:1001', 'ff02::2:1001']

sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('::', 0))

for grp in GROUPS:
    grp_bin = socket.inet_pton(socket.AF_INET6, grp)
    mreq = grp_bin + struct.pack('@I', IFINDEX)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, mreq)
    print(f'Joined {grp} on {IFACE}', flush=True)

def cleanup(sig, frame):
    sock.close()
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

print(f'Multicast-Gruppen aktiv auf {IFACE}. Warte auf Traffic...', flush=True)

while True:
    r, _, _ = select.select([sock], [], [], 30)
    if r:
        data, addr = sock.recvfrom(65535)
        print(f'Paket von {addr[0]}: {len(data)} Bytes', flush=True)
