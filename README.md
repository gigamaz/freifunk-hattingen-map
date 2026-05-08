# Freifunk Hattingen Karte (Yanic + Meshviewer)

Dieses Repository erzeugt die Datengrundlage fuer eine Freifunk-Karte:

- Yanic sammelt Respondd-Daten aus dem Mesh (Interface `bat0`)
- Yanic schreibt JSON/GeoJSON-Dateien fuer Meshviewer
- Meshviewer zeigt diese Dateien als Karte und Knotenliste an

Diese Anleitung ist fuer Einsteiger und fuehrt dich zu einer lauffaehigen Docker-Installation.

## Voraussetzungen

Du brauchst auf dem Zielsystem:

1. Linux mit Zugriff auf das Freifunk-Mesh
2. Ein funktionierendes Interface `bat0`
3. Docker + Docker Compose Plugin
4. Git

Installation der Basis-Tools (Debian/Ubuntu):

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

Optional: Nutzer zur Docker-Gruppe hinzufuegen (danach neu anmelden):

```bash
sudo usermod -aG docker "$USER"
```

## 1) Repository klonen

```bash
git clone https://github.com/gigamaz/freifunk-ffhat.git
cd freifunk-ffhat
```

## 2) Konfiguration pruefen

Die Standard-Konfiguration liegt in `docker/yanic.toml`.

Wichtige Punkte:

- Interface ist `bat0` (`[[respondd.interfaces]]`)
- Ausgabedateien landen unter `docker/data/`
- InfluxDB ist als optionales Ziel eingetragen (`localhost:8086`)

Wenn dein Mesh-Interface anders heisst, passe `docker/yanic.toml` an.

## 3) Yanic starten

Aus dem Projektroot:

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

Status pruefen:

```bash
docker compose -f docker/docker-compose.yml ps
docker logs yanic --tail 50
```

## 4) Ergebnisdateien pruefen

Nach kurzer Laufzeit sollten Dateien unter `docker/data/` entstehen:

- `meshviewer.json`
- `nodes.json`
- `graph.json`
- `nodelist.json`
- `nodes.geojson`

Pruefen:

```bash
ls -lah docker/data
```

Wenn die Dateien existieren und wachsen, ist die Installation funktional.

## 5) Optional: Monitoring (Grafana)

Das Stats-Compose erwartet ein gesetztes Admin-Passwort.

```bash
export GF_ADMIN_PASSWORD='BitteEinSicheresPasswortWaehlen'
docker compose -f docker/docker-compose.stats.yml up -d
```

Grafana ist dann unter `http://<server-ip>:3000` erreichbar.

## 6) Betrieb (wichtig)

- Neustart nach Reboot: `restart: unless-stopped` ist bereits gesetzt.
- Updates einspielen:

```bash
git pull
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

- Stoppen:

```bash
docker compose -f docker/docker-compose.yml down
```

## Haeufige Fehler

- Kein `bat0` vorhanden -> Yanic sammelt keine Knotendaten.
- Container laeuft, aber `docker/data/` bleibt leer -> Multicast/Respondd im Mesh pruefen.
- Grafana startet nicht -> `GF_ADMIN_PASSWORD` nicht gesetzt.

## Weitere Dokumente

- `YANICMAP_DOKUMENTATION.md` (Architektur und Betrieb)
- `DATEIANALYSE.md` (Dateiueberblick)
