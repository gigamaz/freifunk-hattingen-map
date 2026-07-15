# Dateianalyse (Ordner `/home/openclaw/freifunk`)

Diese Analyse fokussiert auf projektrelevante Dateien für die Knotenkarte (Yanic/Meshviewer) sowie angrenzende Betriebsdateien.

## Kerndateien Yanic/Meshviewer

- `yanicmap/yanic.toml`
  - Vollständige lokale Yanic-Konfiguration.
  - Ausgabeformate für Meshviewer und GeoJSON aktiv.
  - Datenbanksektion ohne aktive Connection (JSON-only Betrieb möglich).

- `docker/yanic.toml`
  - Containerisierte Variante der Yanic-Konfiguration.
  - InfluxDB-Connection ist aktiv konfiguriert (`localhost:8086`, DB `freifunk`).

- `yanicmap/yanic.service`
  - Systemd-User-Service für lokalen Yanic-Start.

- `docker/docker-compose.yml`
  - Definiert `yanic` und `mcast-join` als host-network Container.

- `docker/mcast_join.py` und `yanicmap/mcast_join.py`
  - Workaround für batman-adv Multicast-Listener-Verhalten (Gruppenbeitritt für Respondd-Abfragen).

- `upload_mesh.sh`, `docker/upload.sh`, `yanicmap/upload.cron`
  - Upload der JSON/GeoJSON-Dateien auf externen Webspace.

## Betriebs- und Deployskripte

- `docker/deploy_to_ffcollector.sh`
  - Verteilt Docker-Dateien auf Zielhost und beschreibt Migrationsstart.

- `docker/migrate.sh`
  - Migration von altem systemd-Setup zu Docker inkl. Übernahme vorhandener Daten.

- `yanicmap/deploy_ffcollector.sh`
  - Legacy-/Alternative Deploymentroute für systemd-basierten Betrieb auf ffcollector.

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
    - Risiko: mittelfristig veraltete Quelle, fehlende Aktualität.

4. Projekt-Readme passt nur teilweise
   - `README.md` beschreibt primaer Gluon-Firmware-Build.
   - Der Yanic/Meshviewer-Betrieb ist bislang nicht als eigener Hauptteil dokumentiert.

## Bereits vorhanden und positiv

- Trennung der Betriebsmodi (lokal vs. Docker) ist klar erkennbar.
- Multicast-Kompatibilität für neue und ältere Gluon-Knoten ist berücksichtigt.
- Exportformate decken klassische und moderne Meshviewer-Varianten ab.

## Dokumentationsstand nach dieser Analyse

- Neu hinzugefügt: `YANICMAP_DOKUMENTATION.md` als zentrale Projekt- und Betriebsübersicht.
- Diese Datei (`DATEIANALYSE.md`) dokumentiert den Dateibestand, Risiken und Folgeschritte.

## Update 2026-07-15: Incident-Dokumentation

Nach Session "Meshviewer zeigt 0 Online-Knoten":

### Neue Dateien hinzugefügt:
- `RUNBOOK_NEXT_RUN.md` (aktualisiert)
  - Dokumentiert Status nach Incident
  - Enthält Schnell-Diagnose-Anleitung mit SSH-Commands
  - Phase-basierter Troubleshooting-Prozess
  - Hinweise für zukünftige Sessions

- `TROUBLESHOOTING.md` (NEU)
  - Umfassender Troubleshooting-Guide
  - Symptom → Diagnose → Lösung Schema
  - 5-Schritte-Prozess zur Fehlerbehebung
  - Entscheidungsbaum für Problemlösung
  - Bekannte Probleme und Lösungen
  - Emergency-Kontakt-Informationen

### Erkenntnisse aus dem Incident:

1. **Problem-Symptom**: Meshviewer zeigte 0 Online-Knoten
2. **Root-Cause**: Nach Neustart automatisch behoben (nicht untersucht)
3. **Diagnose-Erkenntnisse**:
   - ffcollector war voll funktionsfähig
   - 152 von 164 Knoten online
   - Yanic sammelte Daten korrekt
   - FTPS-Upload lief regelmäßig
   - Website-JSON hatte korrekte Daten
   - Problem lag nicht auf dem Server, sondern auf der Website/im Frontend

4. **Token-Sparanleitung**:
   - Für zukünftige Incidents: direkt SSH-Kommandos aus `RUNBOOK_NEXT_RUN.md` verwenden
   - `TROUBLESHOOTING.md` gibt genaue Schritte vor ohne ausführliche Erklärungen
   - Reduziert Kontextkontrolle und Bash-Experimente

### SSH-Zugangsdaten im Überblick:
- Quelle: `.env` (lokal)
- Host: `192.168.1.129` (nicht `.local` - DNS oft nicht verfügbar)
- User: `marcus`
- Wichtig: immer IP statt Hostname verwenden
