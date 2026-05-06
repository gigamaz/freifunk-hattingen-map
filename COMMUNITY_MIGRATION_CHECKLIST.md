# Community-Migration-Checkliste (Yanic + Meshviewer)

Diese Checkliste hilft dabei, das Projekt von Freifunk Hattingen auf eine andere Community zu übertragen.

## 1) Grunddaten der Ziel-Community erfassen

- Community-Kürzel (z. B. `ffxyz`)
- Ansprechpartner und Betriebsverantwortliche
- Zielhost für Yanic (Servername, SSH-User, Pfade)
- Zielhost/Webspace für Meshviewer-JSON

## 2) Yanic-Konfiguration anpassen

Datei: `docker/yanic.toml` (oder `yanicmap/yanic.toml`)

- `[respondd.sites.ffhat]` auf neue Community ändern (z. B. `[respondd.sites.ffxyz]`)
- `domains = []` auf eure Domänenstruktur abstimmen
- `[[respondd.interfaces]] ifname = "bat0"` auf korrektes Mesh-Interface prüfen
- Multicast-Gruppe für Altgeräte nur behalten, wenn benötigt:
  - `ff02::2:1001`

## 3) Respondd/Multicast-Funktion prüfen

Datei: `docker/mcast_join.py` (oder `yanicmap/mcast_join.py`)

- `IFACE` auf korrektes Interface setzen
- `GROUPS` prüfen (`ff05::2:1001`, optional `ff02::2:1001`)
- Laufend testen, ob Antworten von Knoten eingehen

## 4) Ausgabeformate und Pfade festlegen

In `yanic.toml` sicherstellen:

- `meshviewer.json`
- `nodes.json`
- `graph.json`
- `nodelist.json`
- `nodes.geojson`

Pfade auf eure Betriebsstruktur anpassen (`/data/...` oder lokaler Pfad).

## 5) Upload-Ziel und Verteilung anpassen

Dateien: `upload_mesh.sh`, `docker/upload.sh`

- Host, User, Zielpfad auf eure Infrastruktur ändern
- FTPS mit `--insecure` vermeiden (empfohlen: SFTP oder HTTPS API)
- Zugangsdaten nicht im Repository speichern

Empfehlung:

- `.env` verwenden (z. B. `UPLOAD_HOST`, `UPLOAD_USER`, `UPLOAD_PASS`, `UPLOAD_PATH`)
- Secrets nur als Umgebungsvariablen/Secret-Store bereitstellen

## 6) Meshviewer konfigurieren

Datei außerhalb dieses Repos: Meshviewer-`config.json`

- Daten-URLs auf die neuen JSON-Dateien zeigen lassen
- Community-Name, Kontaktlinks, Branding anpassen
- Startposition (Karte), Zoom und ggf. Kartenlayer konfigurieren

## 7) Deploy-Skripte aktualisieren

Dateien: `docker/deploy_to_ffcollector.sh`, `docker/migrate.sh`, `yanicmap/deploy_ffcollector.sh`

- Hostnamen/SSH-User/Pfade ersetzen
- Alte Projektnamen (`ffmap`, `ffcollector`, `ffhat`) konsequent auf neue Umgebung ändern
- Nicht benötigte Legacy-Pfade entfernen

## 8) Monitoring optional aktivieren

Dateien: `docker/docker-compose.stats.yml`, `docker/generate_graphs.py`

- InfluxDB/Grafana nur aktivieren, wenn benötigt
- DB-Name, Zugriff und Dashboard-Provisioning prüfen
- Graph-Upload-Ziel und Cronjob anpassen

## 9) Abnahmetests (Muss-Kriterien)

- Yanic läuft stabil (Container oder systemd)
- `state.json` wird geschrieben
- Alle JSON/GeoJSON-Dateien werden regelmäßig aktualisiert
- Upload läuft fehlerfrei
- Meshviewer lädt Daten ohne Fehler und zeigt:
  - Knoten
  - Links
  - Offline/Online-Status

## 10) Härtung vor Produktivbetrieb

- Klartext-Credentials aus Skripten entfernen
- TLS-Prüfung aktivieren
- Schreibrechte auf Datenverzeichnisse minimieren
- Logs und Fehlermeldungen zentral sammeln
- Backup/Restore für `state.json` und ggf. InfluxDB definieren

---

## Kurz-Template für neue Community-Werte

```text
COMMUNITY_CODE=ffxyz
RESPONDD_INTERFACE=bat0
RESPONDD_GROUP_PRIMARY=ff05::2:1001
RESPONDD_GROUP_LEGACY=ff02::2:1001

OUTPUT_BASE=/data
UPLOAD_METHOD=sftp
UPLOAD_HOST=example.org
UPLOAD_PATH=/var/www/freifunk/json

YANIC_HOST=collector-ffxyz
YANIC_USER=deploy
```
