# Troubleshooting-Guide: Meshviewer zeigt 0 Online-Knoten

## Symptom: "Meshviewer zeigt 0 online Knoten"

### Schritt 1: Bestätigung des Problems

```bash
# JSON-Datei von der Website abrufen und Online-Knoten zählen
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.nodes | map(select(.is_online == true)) | length'
```

- Wenn `0` zurückkommt → Problem bestätigt
- Wenn Zahl > 0 → Problem ist gelöst oder liegt beim Frontend (Browser-Cache)

---

## Schritt 2: Datenquelle prüfen (ffcollector)

### 2a: SSH-Verbindung testen

```bash
# Stelle sicher, dass .env-Datei vorhanden ist
cat .env

# Extrahiere Anmeldedaten
FFCOLLECTOR_HOSTIP=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)
FFCOLLECTOR_PASSWORD=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)

# Verbindung testen
sshpass -p "$FFCOLLECTOR_PASSWORD" ssh -o StrictHostKeyChecking=no \
  marcus@"$FFCOLLECTOR_HOSTIP" "echo 'Verbindung OK'"
```

**Häufige SSH-Fehler:**
- `Could not resolve hostname ffcollector.local` → IP-Adresse verwenden (siehe `.env`)
- `Permission denied (publickey,password)` → Password falsch oder SSH-Keys nicht konfiguriert
- `No route to host` → Host nicht erreichbar (Netzwerk-Problem)

### 2b: Batman-Mesh überprüfen

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# l2tp-Tunnel und bat0 sollten UP sein
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "ip -br link show l2tp-hat bat0"
```

**Erwartete Ausgabe:**
```
l2tp-hat         UP       ...
bat0             UP       ...
```

**Falls DOWN oder nicht vorhanden:**
- Tunneldigger ist wahrscheinlich nicht laufen
- Batman-Service ist wahrscheinlich nicht laufen
- → Siehe Abschnitt "Services neustarten"

### 2c: Yanic-Datenerfassung überprüfen

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Online-Knoten in meshviewer.json zählen
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "jq '.nodes | map(select(.is_online == true)) | length' \
  /home/marcus/ffmap/docker/data/meshviewer.json"
```

**Mögliche Ergebnisse:**

| Ergebnis | Bedeutung | Nächster Schritt |
|----------|-----------|------------------|
| `0` | Yanic sammelt keine Daten | → 2d Docker-Status prüfen |
| `> 0` | Yanic läuft, Problem liegt beim Upload/Website | → Schritt 3 |

### 2d: Docker-Container und Logs

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Docker-Status
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "cd /home/marcus/ffmap && docker compose -f docker/docker-compose.yml ps"

# Yanic-Logs (letzte 50 Zeilen)
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "docker logs yanic --tail 50"

# Multicast-Join-Status
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "docker logs mcast-join --tail 20"
```

**Typische Fehler in den Logs:**
- `sending multicasts` aber `data.nodes_count=0` → Keine Mesh-Knoten antwortet
- `no configuration found` → Yanic-Konfiguration ist unvollständig
- `unable to start container` → Docker-Problem oder fehlende Abhängigkeiten

---

## Schritt 3: Upload zur Website überprüfen

### 3a: Upload-Log prüfen

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Upload-Log (letzte 50 Zeilen)
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "tail -50 /home/marcus/ffmap/docker/upload.log"
```

**Typische Upload-Ergebnisse:**

| Log-Eintrag | Bedeutung |
|------------|-----------|
| `OK meshviewer.json` | Upload erfolgreich |
| `FEHLER meshviewer.json: ...` | Upload fehlgeschlagen (siehe Fehler-Details) |
| Keine neuen Einträge | Upload-Cronjob läuft nicht |

### 3b: Cronjob überprüfen

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Crontab anzeigen
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "crontab -l | grep upload"
```

**Sollte enthalten:**
```
*/5 * * * * /home/marcus/ffmap/docker/upload.sh >> /home/marcus/ffmap/docker/upload.log 2>&1
```

### 3c: Manuelle Upload-Ausführung

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Upload manuell ausführen
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "/home/marcus/ffmap/docker/upload.sh"
```

---

## Schritt 4: Website-Daten überprüfen

```bash
# Prüfe, ob Dateien auf der Website erreichbar sind
curl -I 'https://www.freifunk-hattingen.de/json/meshviewer.json'

# Abrufe aktuelle Online-Knoten-Anzahl
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.nodes | map(select(.is_online == true)) | length'

# Überprüfe Zeitstempel (sollte aktuell sein)
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.timestamp'
```

**Mögliche Fehler:**

| HTTP-Code | Bedeutung |
|-----------|-----------|
| 200 OK | Datei vorhanden und erreichbar |
| 404 Not Found | Datei existiert nicht oder falsche URL |
| 403 Forbidden | Permissions-Problem auf dem Webserver |

---

## Schritt 5: Frontend überprüfen

Falls ffcollector korrekte Daten liefert und die Website-Dateien abrufbar sind, aber der Meshviewer-Karte immer noch 0 zeigt:

```bash
# Browser-Cache leeren: CTRL+F5 (Hard Refresh)
# oder in Developer Tools: Application > Clear Site Data
```

### 5a: Frontend-Konfiguration prüfen

```bash
# config.json sollte auf /json/ zeigen
curl -s 'https://www.freifunk-hattingen.de/meshviewer/config.json' | \
  jq '.dataPath'

# Sollte ausgeben: ["https://www.freifunk-hattingen.de/json/"]
```

### 5b: JavaScript-Fehler prüfen

1. Website öffnen: https://www.freifunk-hattingen.de/meshviewer
2. Browser DevTools öffnen (F12)
3. "Console" Tab prüfen
4. Auf rote Fehler schauen (besonders Netzwerk-Fehler)

---

## Services neustarten (Falls nötig)

### Option A: Nur Batman neu starten

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S systemctl restart batman-l2tp.service freifunk-batman.service"
```

### Option B: Kompletter Reboot

```bash
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Mit Warnung
echo "⚠️ Fahre ffcollector herunter..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S shutdown -r now"

# Warte auf Neustart (ca. 2-3 Minuten)
sleep 120
echo "✓ Überprüfe Verbindung..."
```

---

## Entscheidungsbaum

```
Problem: "Meshviewer zeigt 0 Online-Knoten"
│
├─→ curl zeigt 0 Online-Knoten?
│   ├─ JA: Problem ist auf ffcollector oder beim Upload
│   │  ├─→ ffcollector erreichbar?
│   │  │  ├─ NEIN: Netzwerk/SSH-Problem
│   │  │  └─ JA: Batman-Mesh aktiv?
│   │  │     ├─ NEIN: Services neustarten oder Reboot
│   │  │     └─ JA: Yanic-Daten vorhanden?
│   │  │        ├─ NEIN: Docker-Logs prüfen
│   │  │        └─ JA: Upload-Log prüfen
│   │  │           ├─ FEHLER: Upload-Credentials prüfen
│   │  │           └─ OK: Website-Daten aktualisieren
│   │
│   └─ NEIN: Problem ist Frontend
│      ├─→ Browser-Cache leeren (CTRL+F5)
│      ├─→ Frontend-Konfiguration prüfen
│      └─→ JavaScript-Fehler in DevTools prüfen
```

---

## Bekannte Probleme und Lösungen

### 1. Nach Reboot: 0 Online-Knoten

**Symptom:** Nach Server-Reboot bleibt Meshviewer bei 0 hängen

**Ursache:** Batman-Services brauchen Zeit zum Starten

**Lösung:** Warten Sie 5-10 Minuten. Falls nicht besser:
```bash
systemctl status tunneldigger.service batman-l2tp.service freifunk-batman.service
```

### 2. Sporadisch 0 Knoten für wenige Minuten

**Symptom:** Meshviewer zeigt kurzzeitig 0 Knoten, dann wieder normal

**Ursache:** Keine Respondd-Antworten von den Mesh-Knoten (z.B. kurze Netzwerk-Störung)

**Lösung:** Normal, kein Handeln erforderlich. Yanic prunt alte Knoten nach 10 Minuten Inaktivität.

### 3. Upload-Fehler: "550 Access Denied"

**Symptom:** `upload.log` zeigt: `FEHLER: 550 Access Denied`

**Ursache:** FTP-Credentials sind falsch oder abgelaufen

**Lösung:** 
1. Überprüfen Sie FTP-Zugangsdaten in `docker/upload.sh`
2. Testen Sie FTP-Zugang manuell: `curl -u user:pass ftp://host/`

### 4. Yanic sammelt Daten, Website zeigt aber 0

**Symptom:** 
- ffcollector hat `meshviewer.json` mit 150+ Knoten
- Website zeigt 0 Knoten

**Ursache:**
- Upload läuft nicht → cronjob-Problem
- Upload schlägt fehl → FTP-Fehler
- Falsche URL in Frontend-Konfiguration

**Lösung:**
1. Überprüfen Sie `upload.log`
2. Führen Sie Upload manuell aus
3. Überprüfen Sie `config.json` auf Website

---

## Emergency-Kontakt

Falls alle Troubleshooting-Schritte fehlschlagen:

1. Überprüfen Sie, ob `ffcollector` erreichbar ist (Ping)
2. Überprüfen Sie Netzwerk-Verbindung des Servers
3. Überprüfen Sie, ob Website-Hosting offline ist
4. Sehen Sie sich die systemd-Logs an:
   ```bash
   sshpass -p $PASS ssh marcus@$HOST \
     "echo '$PASS' | sudo -S journalctl -xe | tail -100"
   ```
