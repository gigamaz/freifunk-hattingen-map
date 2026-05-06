# Dateianalyse (Ordner `/home/openclaw/freifunk`)

Diese Analyse fokussiert auf projektrelevante Dateien fuer die Knotenkarte (Yanic/Meshviewer) sowie angrenzende Betriebsdateien.

## Kerndateien Yanic/Meshviewer

- `yanicmap/yanic.toml`
  - Vollstaendige lokale Yanic-Konfiguration.
  - Ausgabeformate fuer Meshviewer und GeoJSON aktiv.
  - Datenbanksektion ohne aktive Connection (JSON-only Betrieb moeglich).

- `docker/yanic.toml`
  - Containerisierte Variante der Yanic-Konfiguration.
  - InfluxDB-Connection ist aktiv konfiguriert (`localhost:8086`, DB `freifunk`).

- `yanicmap/yanic.service`
  - Systemd-User-Service fuer lokalen Yanic-Start.

- `docker/docker-compose.yml`
  - Definiert `yanic` und `mcast-join` als host-network Container.

- `docker/mcast_join.py` und `yanicmap/mcast_join.py`
  - Workaround fuer batman-adv Multicast-Listener-Verhalten (Gruppenbeitritt fuer Respondd-Abfragen).

- `upload_mesh.sh`, `docker/upload.sh`, `yanicmap/upload.cron`
  - Upload der JSON/GeoJSON-Dateien auf externen Webspace.

## Betriebs- und Deployskripte

- `docker/deploy_to_ffcollector.sh`
  - Verteilt Docker-Dateien auf Zielhost und beschreibt Migrationsstart.

- `docker/migrate.sh`
  - Migration von altem systemd-Setup zu Docker inkl. Uebernahme vorhandener Daten.

- `yanicmap/deploy_ffcollector.sh`
  - Legacy-/Alternative Deploymentroute fuer systemd-basierten Betrieb auf ffcollector.

- `docker/docker-compose.stats.yml`, `docker/generate_graphs.py`, `docker/Dockerfile.graphs`
  - Optionaler Statistikpfad (InfluxDB/Grafana + PNG-Graphen-Generator + FTP-Upload).

## Kritische Findings

1. Geheimnisse im Klartext
   - In `docker/rollback_stats.sh` sind FTP-Zugangsdaten im Skript hinterlegt.
   - Risiko: Credential-Leak bei Repo-Zugriff, Backups oder Log-Ausgabe.

2. Unsichere Upload-Parameter
   - Upload-Skripte verwenden FTPS mit `--insecure`.
   - Risiko: fehlende TLS-Servervalidierung, MITM-Angriffsfenster.

3. Upstream-Quelle Yanic
   - `docker/Dockerfile` klont aus GitHub-Mirror (`FreifunkBremen/yanic`), der als archiviert markiert ist.
   - Risiko: mittelfristig veraltete Quelle, fehlende Aktualitaet.

4. Projekt-Readme passt nur teilweise
   - `README.md` beschreibt primaer Gluon-Firmware-Build.
   - Der Yanic/Meshviewer-Betrieb ist bislang nicht als eigener Hauptteil dokumentiert.

## Bereits vorhanden und positiv

- Trennung der Betriebsmodi (lokal vs. Docker) ist klar erkennbar.
- Multicast-Kompatibilitaet fuer neue und aeltere Gluon-Knoten ist beruecksichtigt.
- Exportformate decken klassische und moderne Meshviewer-Varianten ab.

## Dokumentationsstand nach dieser Analyse

- Neu hinzugefuegt: `YANICMAP_DOKUMENTATION.md` als zentrale Projekt- und Betriebsuebersicht.
- Diese Datei (`DATEIANALYSE.md`) dokumentiert den Dateibestand, Risiken und Folgeschritte.
