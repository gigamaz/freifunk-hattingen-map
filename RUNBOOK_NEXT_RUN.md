# Nächster Lauf / Betriebsnotizen

## Aktueller Stand (2026-07-15)

**Problem:** Meshviewer zeigte 0 Online-Knoten
**Ursache:** Nach Neustart automatisch behoben
**Status:** ✅ Gelöst - 152/164 Knoten online

### Details nach Incident-Session 15.07.2026

- **ffcollector Host (192.168.1.129)**:
  - ✅ Batman-Interface `bat0` aktiv
  - ✅ L2TP-Tunnel `l2tp-hat` aktiv (1 Batman-Nachbar sichtbar)
  - ✅ Yanic-Container lädt Daten korrekt
  - ✅ 152 von 164 Knoten online (92,6%)
  - ✅ Alle JSON/GeoJSON-Dateien werden aktualisiert
  - ✅ FTPS-Upload läuft alle 5 Minuten (alle OK)

- **Website (www.freifunk-hattingen.de)**:
  - ✅ meshviewer.json unter `/json/meshviewer.json` erreichbar
  - ✅ Zeigt korrekt 152 Online-Knoten
  - ✅ Konfiguration lädt Daten von `https://www.freifunk-hattingen.de/json/`
  - ✅ Frontend-SPA lädt korrekt

- Der reguläre Cronjob bleibt aktiv (`*/5 * * * * /home/marcus/ffmap/docker/upload.sh`).

## Was geändert wurde

- Healthcheck alarmiert jetzt schon beim **ersten** BAD-Lauf.
- `FAIL_THRESHOLD` steht auf `1`:
  - `docker/healthcheck_ffcollector.sh`
  - `docker/healthcheck.env.example`
- README-Doku zum Healthcheck wurde angepasst.
- Auf `ffcollector` wurde die laufende `healthcheck.env` ebenfalls auf `FAIL_THRESHOLD=1` gesetzt.

## Ursache des Mesh-Ausfalls

- `nodes.json` zeigte zeitweise **0 Online-Nodes**.
- Ursache war nicht die Yanic-Konfiguration, sondern das Mesh auf dem Server:
  - `freifunk-batman.service` war **failed**
  - `batman-l2tp.service` war **inactive**
  - `l2tp-hat` war **down**

## Wiederherstellung

- Diese Services neu starten:
  - `batman-l2tp.service`
  - `freifunk-batman.service`
- Danach prüfen:
  - `bat0` und `l2tp-hat` sind `UP`
  - `nodes.json` enthält wieder Online-Nodes

## Schnell-Diagnose-Anleitung (bei "0 Online-Knoten")

### Phase 1: ffcollector-Host prüfen (SSH-Zugang erforderlich)

Anmeldedaten:
- Host: `192.168.1.129` (nicht `.local` - DNS-Auflösung funktioniert oft nicht)
- User: `marcus`
- Password: In `.env` (`FFCOLLECTOR_PASSWORD`)

```bash
# Verbindung testen
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 "echo 'OK'"

# Batman-Interfaces prüfen
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 \
  "echo '<PASSWORD>' | sudo -S batctl meshif bat0 if"

# Batman-Nachbarn prüfen
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 \
  "echo '<PASSWORD>' | sudo -S batctl meshif bat0 neighbors"

# Online-Knoten-Anzahl prüfen
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 \
  "jq '.nodes | map(select(.is_online == true)) | length' /home/marcus/ffmap/docker/data/meshviewer.json"

# Docker-Container-Status
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 \
  "cd /home/marcus/ffmap && docker compose -f docker/docker-compose.yml ps"

# Yanic-Logs (letzte 30 Zeilen)
sshpass -p <PASSWORD> ssh -o StrictHostKeyChecking=no marcus@192.168.1.129 \
  "docker logs yanic --tail 30"
```

**Typische Fehlerstellen:**
- ❌ `l2tp-hat` nicht aktiv → Tunneldigger-Service prüfen
- ❌ `bat0` down → Services `batman-l2tp.service` und `freifunk-batman.service` neustarten
- ❌ Yanic zeigt 0 Online-Knoten → Docker-Logs prüfen, ggf. Container neu starten
- ❌ nodes.json hat Online-Knoten, aber Website zeigt 0 → Website/Frontend-Problem

### Phase 2: Website-Daten prüfen

```bash
# Daten von der Website abrufen
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.nodes | map(select(.is_online == true)) | length'

# Daten-Zeitstempel überprüfen (sollte aktuell sein)
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | jq '.timestamp'

# Konfiguration prüfen
curl -s 'https://www.freifunk-hattingen.de/meshviewer/config.json' | jq '.dataPath'
```

**Typische Probleme:**
- ❌ 404 auf `/json/meshviewer.json` → Upload fehlgeschlagen oder falsche URL in Konfiguration
- ❌ Alte Timestamps → Upload-Cronjob läuft nicht
- ❌ Website zeigt 0, aber JSON hat Knoten → Browser-Cache leeren (CTRL+F5) oder JavaScript-Fehler

### Phase 3: Services neustarten (falls nötig)

```bash
# Auf ffcollector via SSH
sshpass -p <PASSWORD> ssh marcus@192.168.1.129 \
  "echo '<PASSWORD>' | sudo -S systemctl restart batman-l2tp.service freifunk-batman.service"

# Oder kompletter Reboot, falls Services hängen
sshpass -p <PASSWORD> ssh marcus@192.168.1.129 \
  "echo '<PASSWORD>' | sudo -S shutdown -r now"
```

## Hinweise

- Keine Secrets in Docs übernehmen - `.env` nur lokal verwenden
- Für produktive SSH-Nutzung: SSH-Keys statt Passwörter einrichten
- `sshpass` nur in automatisierten Scripts verwenden, nicht manuell eingeben
- Browser-Cache ist oft die Ursache für "0 Knoten" auf der Website - immer CTRL+F5 probieren
