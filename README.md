# Freifunk Hattingen Karte (Yanic + Meshviewer)

Dieses Repository erzeugt die Datengrundlage für eine Freifunk-Karte:

- Yanic sammelt Respondd-Daten aus dem Mesh (Interface `bat0`)
- Yanic schreibt JSON/GeoJSON-Dateien für Meshviewer
- Meshviewer zeigt diese Dateien als Karte und Knotenliste an

Diese Anleitung führt Schritt für Schritt zu einer funktionierenden Installation
inklusive Erzeugung und Konfiguration von `bat0`.

## Zielbild

Am Ende läuft:

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

Falls keine Zeile erscheint, ist das Modul im Kernel nicht verfügbar.

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
Du brauchst dafür von der Freifunk-Community:

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

Danach prüfen, ob `l2tpeth0` (oder ein anderes `l2tp*`) erscheint:

```bash
ip -br link | grep l2tp
```

Falls dein Setup einen Key braucht, den Startbefehl um `-k <DEIN_KEY>` ergänzen.

## 6) Mesh-Transportinterface an `bat0` anbinden

Du brauchst ein Layer-2 Interface, das ins Freifunk-Mesh zeigt (häufig `l2tpeth0`,
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

## 7) Multicast für Respondd auf `bat0` prüfen

Yanic fragt Respondd über IPv6-Multicast ab. Prüfen:

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

## 10) Logs und Funktion prüfen

```bash
docker logs yanic --tail 100
docker logs mcast-join --tail 100
ls -lah docker/data
```

Funktioniert die Installation, dann werden unter `docker/data/` die JSON/GeoJSON-Dateien geschrieben.

## 11) Produktive systemd-Variante auf `ffcollector`

Die produktive VM nutzt **nicht** `tunneldigger-client.service` und **nicht**
`batman-setup.service`, sondern diese drei Units:

- `tunneldigger.service`
- `batman-l2tp.service`
- `freifunk-batman.service`

Dabei ist das Uplink-Interface `l2tp-hat` (nicht `l2tpeth0`).

`/etc/systemd/system/tunneldigger.service`:

```ini
[Unit]
Description=Tunneldigger Client
After=network.target

[Service]
Type=simple
ExecStart=/home/marcus/tunneldigger/client/build/tunneldigger -f -u 98e6cfee-043b-4071-addb-19d658b83787 -i l2tp-hat -b broker1.ff-en.de:10180
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/batman-l2tp.service`:

```ini
[Unit]
Description=Add l2tp-hat to batman (wait for interface)
After=tunneldigger.service
Requires=tunneldigger.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for i in $(seq 1 20); do if ip link show l2tp-hat >/dev/null 2>&1; then ip link set l2tp-hat up; batctl if add l2tp-hat || true; ip link set bat0 up; exit 0; fi; sleep 1; done; exit 1'

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/freifunk-batman.service`:

```ini
[Unit]
Description=Ensure L2TP and batman interface are active
After=network-online.target
Wants=network-online.target
PartOf=tunneldigger.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set l2tp-hat up
ExecStart=/usr/sbin/batctl if add l2tp-hat
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

Aktivieren/neu laden:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tunneldigger.service batman-l2tp.service freifunk-batman.service
sudo systemctl restart batman-l2tp.service freifunk-batman.service
```

## 12) Betrieb im Alltag

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

Health-Check (alle 5 Minuten, Telegram + Mail):

```bash
cp docker/healthcheck.env.example docker/healthcheck.env
nano docker/healthcheck.env
scp docker/healthcheck_ffcollector.sh marcus@ffcollector:/home/marcus/ffmap/docker/
scp docker/systemd/ffcollector-healthcheck.* marcus@ffcollector:/home/marcus/ffmap/docker/systemd/
ssh marcus@ffcollector "chmod +x /home/marcus/ffmap/docker/healthcheck_ffcollector.sh && sudo cp /home/marcus/ffmap/docker/systemd/ffcollector-healthcheck.* /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now ffcollector-healthcheck.timer"
```

Alarm-Methodik (ohne Secrets):

- Signalquellen im Check:
  - `batctl if` muss `l2tp-hat: active` enthalten.
  - `batctl n` muss mindestens einen Batman-Nachbarn liefern.
  - `data/nodes.json` muss mindestens einen Online-Knoten enthalten.
- Zustandsmodell:
  - `OK`: alle Bedingungen erfuellt.
  - `BAD`: mindestens eine Bedingung verletzt.
  - Status wird in `docker/data/healthcheck_state` gespeichert (`last_status`, `fail_count`).
- Entprellung (Flap-Schutz):
  - Alarm erst nach `FAIL_THRESHOLD` aufeinanderfolgenden BAD-Laeufen.
  - Standard ist `FAIL_THRESHOLD=2`.
- Benachrichtigungslogik:
  - Alert wird einmalig beim Uebergang `OK -> BAD` nach Schwellwert versendet.
  - Recovery wird einmalig beim Uebergang `BAD -> OK` versendet.
  - Keine Dauer-Spam-Nachrichten bei unveraendertem Zustand.
- Kanaele:
  - Telegram via Bot API (`sendMessage`).
  - E-Mail via lokales `mail`/`mailx` (oder alternativ SMTP-Relay).
- Logging:
  - Service-Logs in `journalctl -u ffcollector-healthcheck.service`.
  - Ereigniszeilen enthalten Prefix `FFCOLLECTOR ALERT` bzw. `FFCOLLECTOR OK`.

Manueller Test auf `ffcollector`:

```bash
sudo /home/marcus/ffmap/docker/healthcheck_ffcollector.sh
sudo journalctl -u ffcollector-healthcheck.service -n 50 --no-pager
sudo systemctl list-timers ffcollector-healthcheck.timer
```

Schnellcheck:

```bash
ip -br link show bat0
sudo batctl meshif bat0 if
docker compose -f docker/docker-compose.yml ps
```

## Fehlerbehebung

- `bat0` fehlt nach Reboot -> Status von `tunneldigger.service`, `batman-l2tp.service` und `freifunk-batman.service` prüfen.
- `batctl if` zeigt kein `l2tp-hat: active` -> Tunnel/Uplink down oder Interface nicht an batman gebunden.
- `docker/data/` bleibt leer -> keine Respondd-Antworten im Mesh oder Multicast blockiert.
- `mcast-join` startet nicht -> Container-Logs prüfen (`docker logs mcast-join`).

## Weitere Dokumente

- `YANICMAP_DOKUMENTATION.md` (Architektur und Betrieb)
- `DATEIANALYSE.md` (Dateiüberblick)
