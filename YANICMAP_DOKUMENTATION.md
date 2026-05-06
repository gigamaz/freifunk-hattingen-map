# Freifunk Hattingen Knotenkarte (Yanic + Meshviewer)

## Ziel

Dieses Teilprojekt liefert die Datengrundlage für eine visualisierte Karte aller Freifunk-Knoten in Hattingen:

- Yanic sammelt und aggregiert Respondd-Daten aus dem Batman-adv-Mesh.
- Yanic exportiert daraus JSON- und GeoJSON-Dateien.
- Meshviewer visualisiert diese Dateien als Karte, Knotenliste und Link-Graph.

## Ist-Architektur (Stand: Mai 2026)

1. Datenerfassung
   - Yanic fragt Respondd zyklisch per Multicast ab (`ff05::2:1001` und für Altgeräte `ff02::2:1001`).
   - Erfassung läuft über Interface `bat0`.

2. Datenpersistenz und Ausgabe
   - Yanic hält internen Node-Cache in `state.json`.
   - Ausgaben landen in `yanicmap/data/` oder im Docker-Setup in `docker/data/`.
   - Relevante Exporte:
     - `meshviewer.json` (ffrgb/kompatible Frontends)
     - `nodes.json` + `graph.json` (klassisches Meshviewer-Format)
     - `nodelist.json`
     - `nodes.geojson`

3. Visualisierung
    - Meshviewer liest diese Dateien über HTTP vom Webspace.
   - Upload erfolgt aktuell per FTPS-Skript (`upload_mesh.sh` bzw. `docker/upload.sh`) im Cron-Intervall.

## Betriebsmodi im Repository

- Lokal/Systemd-orientiert:
  - Konfiguration: `yanicmap/yanic.toml`
  - Service-Unit: `yanicmap/yanic.service`
  - Upload-Cron: `yanicmap/upload.cron`

- Docker-orientiert (ffcollector):
  - `docker/docker-compose.yml`
  - `docker/yanic.toml`
  - `docker/mcast_join.py`
  - Deployment-/Migrationsskripte unter `docker/`

## Aktuelle Quellenlage (extern)

- Yanic (upstream auf GitHub ist archiviert, aktive Migration zu Codeberg):
  - https://github.com/FreifunkBremen/yanic
  - https://freifunkbremen.codeberg.page/yanic/
- Meshviewer (aktiv gepflegt):
  - https://github.com/freifunk/meshviewer

Wichtige Beobachtung:
- Das Dockerfile baut Yanic weiterhin aus dem GitHub-Mirror. Da das GitHub-Repo als archiviert markiert ist, sollte auf die aktive Codeberg-Quelle umgestellt werden.

## Empfohlene nächste Schritte für die Projektfortführung

1. Upstream-Quelle für Yanic auf Codeberg umstellen.
2. Meshviewer-Deployment explizit versionieren (Release-Tag statt implizit "latest").
3. Secrets-Hygiene verbessern:
   - Keine Klartext-Credentials in Skripten.
   - `.env`-basiertes Secret-Management + Dokumentation.
4. JSON-Auslieferung absichern:
   - Wenn möglich SFTP oder HTTPS API statt FTPS mit `--insecure`.
5. Betriebsdokumentation konsolidieren:
   - Ein gemeinsamer "Single Source of Truth" für Deploy, Betrieb, Monitoring und Rollback.

## Minimaler Betriebsablauf (Docker-Variante)

1. `docker/yanic.toml` validieren (Interface, Pfade, Datenbank, Output-Formate).
2. Container starten:
   - `docker compose -f docker/docker-compose.yml build`
   - `docker compose -f docker/docker-compose.yml up -d`
3. Output prüfen (`docker/data/*.json`, `docker/data/*.geojson`).
4. Upload-Job per Cron ausführen.
5. Meshviewer auf gültige Daten-URLs konfigurieren (`config.json` im Meshviewer-Webroot).

## Abhängigkeiten

- Mesh-Netz: funktionierendes `bat0` mit Respondd-antwortenden Knoten
- Laufzeit: Docker/Compose oder systemd-user
- Optionales Monitoring: InfluxDB + Grafana
- Webhosting: statische Auslieferung der JSON-Dateien für Meshviewer
