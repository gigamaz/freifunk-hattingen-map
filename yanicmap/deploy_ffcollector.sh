#!/bin/bash
# Yanic Setup für ffcollector (marcus@ffcollector)
# Dieses Script auf ffcollector als 'marcus' ausführen

set -e

YANIC_DIR="/home/marcus/ffmap/yanic"
DATA_DIR="$YANIC_DIR/data"
STATE_FILE="$YANIC_DIR/state.json"
BINARY="$YANIC_DIR/yanic"
CONFIG="$YANIC_DIR/yanic.toml"

echo "=== Yanic Setup für ffcollector ==="

# Verzeichnisse anlegen
mkdir -p "$DATA_DIR"

# Prüfen ob Binary vorhanden ist (muss vorher kopiert werden)
if [ ! -f "$BINARY" ]; then
    echo "FEHLER: $BINARY nicht gefunden."
    echo "Kopiere das Binary vom openclaw-Server:"
    echo "  scp openclaw@192.168.1.119:/home/openclaw/freifunk/yanic/yanic $BINARY"
    exit 1
fi
chmod +x "$BINARY"
echo "Binary OK: $BINARY"

# Config schreiben
cat > "$CONFIG" << 'EOF'
# Yanic Konfiguration für Freifunk Hattingen (ffhat)
# ffcollector - /home/marcus/ffmap/yanic/

[respondd]
enable           = true
synchronize      = "1m"
collect_interval = "1m"

[respondd.sites.ffhat]
domains = []

# bat0 = Batman-adv Mesh-Interface (neuere Gluon-Knoten)
[[respondd.interfaces]]
ifname = "bat0"

# Ältere Gluon-Knoten (ff02::2:1001)
[[respondd.interfaces]]
ifname            = "bat0"
multicast_address = "ff02::2:1001"

[webserver]
enable  = false
bind    = "127.0.0.1:8080"
webroot = "/home/marcus/ffmap/yanic/data"

[nodes]
state_path    = "/home/marcus/ffmap/yanic/state.json"
prune_after   = "30d"
save_interval = "30s"
offline_after = "10m"

# meshviewer.json (ffrgb-Format)
[[nodes.output.meshviewer-ffrgb]]
enable = true
path   = "/home/marcus/ffmap/yanic/data/meshviewer.json"

[nodes.output.meshviewer-ffrgb.filter]
no_owner = false

# nodes.json + graph.json (klassisches Format v2)
[[nodes.output.meshviewer]]
enable     = true
version    = 2
nodes_path = "/home/marcus/ffmap/yanic/data/nodes.json"
graph_path = "/home/marcus/ffmap/yanic/data/graph.json"

[nodes.output.meshviewer.filter]
no_owner = false

# nodelist.json
[[nodes.output.nodelist]]
enable = true
path   = "/home/marcus/ffmap/yanic/data/nodelist.json"

[nodes.output.nodelist.filter]
no_owner = false

# nodes.geojson
[[nodes.output.geojson]]
enable = true
path   = "/home/marcus/ffmap/yanic/data/nodes.geojson"

[database]
delete_after    = "30d"
delete_interval = "1h"
EOF
echo "Config OK: $CONFIG"

# Multicast-Keeper-Script schreiben
cat > "/home/marcus/ffmap/yanic/mcast_join.py" << 'PYEOF'
#!/usr/bin/env python3
"""Hält batman-adv Multicast-Gruppen für respondd aktiv (batman-adv 2024.0)."""
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

print(f'Multicast-Gruppen aktiv. Warte auf Traffic...', flush=True)
while True:
    r, _, _ = select.select([sock], [], [], 30)
    if r:
        data, addr = sock.recvfrom(65535)
        print(f'Paket von {addr[0]}: {len(data)} Bytes', flush=True)
PYEOF

# Systemd User-Services anlegen
mkdir -p /home/marcus/.config/systemd/user

cat > /home/marcus/.config/systemd/user/yanic.service << 'EOF'
[Unit]
Description=Yanic - Yet Another Node Info Collector (ffhat)
After=network.target

[Service]
Type=simple
ExecStart=/home/marcus/ffmap/yanic/yanic serve --config /home/marcus/ffmap/yanic/yanic.toml
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=yanic

[Install]
WantedBy=default.target
EOF

cat > /home/marcus/.config/systemd/user/mcast-join.service << 'EOF'
[Unit]
Description=Batman-adv Multicast Group Keeper (respondd)
After=yanic.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /home/marcus/ffmap/yanic/mcast_join.py
Restart=always
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mcast-join

[Install]
WantedBy=default.target
EOF

echo "Systemd-Services OK"

# Services aktivieren und starten
systemctl --user daemon-reload
systemctl --user enable yanic mcast-join
systemctl --user start mcast-join
systemctl --user start yanic

echo ""
echo "=== Fertig! ==="
echo "Status prüfen mit:"
echo "  systemctl --user status yanic"
echo "  journalctl --user -u yanic -f"
