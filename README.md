# Freifunk Hattingen Karte (Yanic + Meshviewer)

Dieses Repository erzeugt die Datengrundlage fuer eine Freifunk-Karte:

- Yanic sammelt Respondd-Daten aus dem Mesh (Interface `bat0`)
- Yanic schreibt JSON/GeoJSON-Dateien fuer Meshviewer
- Meshviewer zeigt diese Dateien als Karte und Knotenliste an

Diese Anleitung fuehrt Schritt fuer Schritt zu einer funktionierenden Installation
inklusive Erzeugung und Konfiguration von `bat0`.

## Zielbild

Am Ende laeuft:

1. ein funktionierendes Batman-adv Interface `bat0`
2. der Yanic-Stack per Docker
3. die Ausgabe unter `docker/data/` (`meshviewer.json`, `nodes.json`, `graph.json`, `nodelist.json`, `nodes.geojson`)

## 1) Voraussetzungen installieren (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install -y git curl jq docker.io docker-compose-plugin batctl kmod
sudo systemctl enable --now docker
```

Optional (bequemer ohne `sudo`):

```bash
sudo usermod -aG docker "$USER"
```

Danach einmal ab- und wieder anmelden.

## 2) Repository klonen

```bash
git clone https://github.com/gigamaz/freifunk-ffhat.git
cd freifunk-ffhat
```

## 3) Batman-adv Kernelmodul laden

```bash
sudo modprobe batman-adv
lsmod | grep batman_adv
```

Falls keine Zeile erscheint, ist das Modul im Kernel nicht verfuegbar.

## 4) `bat0` erzeugen

```bash
sudo ip link add name bat0 type batadv
sudo ip link set bat0 up
ip -br link show bat0
```

Wenn `bat0` bereits existiert, ist das normal. Dann nur sicherstellen, dass es `UP` ist:

```bash
sudo ip link set bat0 up
```

## 5) Tunneldigger-Client einrichten (erzeugt meist `l2tpeth0`)

Wenn du noch kein Mesh-Uplink-Interface hast, richte zuerst Tunneldigger ein.
Du brauchst dafuer von der Freifunk-Community:

- Broker-Hostname oder IP
- Broker-Port (oft `8942`)
- optionalen Pre-Shared Key

Pakete installieren:

```bash
sudo apt install -y python3-venv python3-pip git
```

Tunneldigger-Client lokal installieren:

```bash
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/wlanslovenija/tunneldigger.git
cd tunneldigger/client
sudo python3 -m venv /opt/tunneldigger/venv
sudo /opt/tunneldigger/venv/bin/pip install --upgrade pip
sudo /opt/tunneldigger/venv/bin/pip install -r requirements.txt
```

Teststart (Werte ersetzen):

```bash
sudo /opt/tunneldigger/venv/bin/python /opt/tunneldigger/client/l2tp_client.py \
  -b <BROKER_HOSTNAME_ODER_IP>:<BROKER_PORT> \
  -i l2tp0 \
  -a ffhat-collector \
  -u 1472
```

Danach pruefen, ob `l2tpeth0` (oder ein anderes `l2tp*`) erscheint:

```bash
ip -br link | grep l2tp
```

Falls dein Setup einen Key braucht, den Startbefehl um `-k <DEIN_KEY>` ergaenzen.

## 6) Mesh-Transportinterface an `bat0` anbinden

Du brauchst ein Layer-2 Interface, das ins Freifunk-Mesh zeigt (haeufig `l2tpeth0`,
manchmal auch `mesh-vpn0` oder ein VLAN-Interface wie `eth0.42`).

Vorhandene Interfaces anzeigen:

```bash
ip -br link
```

Beispiel mit `l2tpeth0`:

```bash
sudo ip link set l2tpeth0 up
sudo batctl meshif bat0 if add l2tpeth0
sudo batctl meshif bat0 if
```

Die letzte Ausgabe muss `l2tpeth0: active` zeigen.

## 7) Multicast fuer Respondd auf `bat0` pruefen

Yanic fragt Respondd ueber IPv6-Multicast ab. Pruefen:

```bash
ip -6 maddr show dev bat0
```

Wenn noch keine Gruppen sichtbar sind, ist das vor dem Yanic-Start nicht automatisch ein Fehler.
Nach Start des `mcast-join` Containers sollten die relevanten Gruppen gesetzt werden.

## 8) Yanic-Konfiguration kontrollieren

Datei: `docker/yanic.toml`

Wichtige Punkte:

- `[[respondd.interfaces]]` nutzt `ifname = "bat0"`
- Outputs zeigen auf `/data/...`
- optionales InfluxDB-Ziel ist `http://localhost:8086`

Wenn du ein anderes Batman-Interface verwenden willst, passe `ifname` an.

## 9) Stack starten

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps
```

## 10) Logs und Funktion pruefen

```bash
docker logs yanic --tail 100
docker logs mcast-join --tail 100
ls -lah docker/data
```

Funktioniert die Installation, dann werden unter `docker/data/` die JSON/GeoJSON-Dateien geschrieben.

## 11) Autostart fuer `bat0` und Mesh-Interface einrichten (systemd)

Wenn du Tunneldigger nutzt, zuerst den Client als Service einrichten, damit
das Uplink-Interface vor `batman-setup.service` vorhanden ist.

```bash
sudo tee /etc/systemd/system/tunneldigger-client.service >/dev/null <<'EOF'
[Unit]
Description=Tunneldigger L2TP client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/tunneldigger/venv/bin/python /opt/tunneldigger/client/l2tp_client.py -b <BROKER_HOSTNAME_ODER_IP>:<BROKER_PORT> -i l2tp0 -a ffhat-collector -u 1472
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Service aktivieren:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tunneldigger-client.service
sudo systemctl status tunneldigger-client.service
```

Wenn ein Key noetig ist, in `ExecStart` um `-k <DEIN_KEY>` erweitern.

Damit `bat0` nach Reboot automatisch wiederhergestellt wird, Service-Datei anlegen:

```bash
sudo tee /etc/systemd/system/batman-setup.service >/dev/null <<'EOF'
[Unit]
Description=Setup batman-adv mesh interface
After=network-online.target
Wants=network-online.target
After=tunneldigger-client.service
Wants=tunneldigger-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/modprobe batman-adv
ExecStart=/sbin/ip link add name bat0 type batadv
ExecStart=/sbin/ip link set bat0 up
ExecStart=/sbin/ip link set l2tpeth0 up
ExecStart=/usr/sbin/batctl meshif bat0 if add l2tpeth0
ExecStop=/usr/sbin/batctl meshif bat0 if del l2tpeth0
ExecStop=/sbin/ip link del bat0

[Install]
WantedBy=multi-user.target
EOF
```

Service aktivieren:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now batman-setup.service
sudo systemctl status batman-setup.service
```

Wichtig: Wenn dein Uplink-Interface nicht `l2tpeth0` heisst, in der Unit-Datei ersetzen.

## 12) Optional: Monitoring mit Grafana

```bash
export GF_ADMIN_PASSWORD='BitteEinSicheresPasswortWaehlen'
docker compose -f docker/docker-compose.stats.yml up -d
```

Grafana: `http://<server-ip>:3000`

## 13) Betrieb im Alltag

Update:

```bash
git pull
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

Stop:

```bash
docker compose -f docker/docker-compose.yml down
```

Schnellcheck:

```bash
ip -br link show bat0
sudo batctl meshif bat0 if
docker compose -f docker/docker-compose.yml ps
```

## Fehlerbehebung

- `bat0` fehlt nach Reboot -> `batman-setup.service` Status pruefen.
- `batctl ... if` zeigt kein `active` -> falsches/Down-Uplink-Interface.
- `docker/data/` bleibt leer -> keine Respondd-Antworten im Mesh oder Multicast blockiert.
- `mcast-join` startet nicht -> Container-Logs pruefen (`docker logs mcast-join`).
- Grafana startet nicht -> `GF_ADMIN_PASSWORD` fehlt.

## Weitere Dokumente

- `YANICMAP_DOKUMENTATION.md` (Architektur und Betrieb)
- `DATEIANALYSE.md` (Dateiueberblick)
