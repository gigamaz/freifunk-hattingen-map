# Maßnahmenplan: Meshviewer zeigt 0 Online-Knoten

**Ziel:** Bei erneutem Ausfall sofort handlungsfähig sein, ohne umfangreiche Recherche

**Geschätzte Bearbeitungszeit:** 5-10 Minuten für komplette Diagnose

---

## 🔴 SOFORT-MASSNAHMEN (vor jeder weiteren Diagnose)

### M1: Browser-Cache leeren

```bash
# Meshviewer im Browser öffnen:
# https://www.freifunk-hattingen.de/meshviewer

# Dann:
# 1. CTRL+F5 drücken (Hard Refresh)
# 2. Warten Sie 5 Sekunden
# 3. Schauen Sie, ob Knoten-Anzahl angezeigt wird
```

**Wenn danach > 0 Knoten sichtbar:**
- ✅ Problem gelöst - fertig
- 📝 Notiz machen: "Browser-Cache war das Problem"

**Falls immer noch 0 Knoten:**
- ➡️ Gehe zu Maßnahme M2

---

## 🟡 DIAGNOSE-PHASE (strukturierte Abfrage)

### M2: Daten-Verfügbarkeit auf Website prüfen

```bash
# Im Terminal ausführen:
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.nodes | map(select(.is_online == true)) | length'
```

**Mögliche Ergebnisse:**

| Ergebnis | Status | Nächste Maßnahme |
|----------|--------|------------------|
| `0` | ❌ Problem auf Server | → M3 |
| `1-50` | ⚠️ Teilweise Problem | → M3 |
| `> 50` | ✅ Server OK | → M5 |
| Fehler/404 | ❌ Upload-Problem | → M4 |

### M3: ffcollector Host Status überprüfen

**Vorbereitung:**
```bash
# Anmeldedaten auslesen
PASS=$(grep FFCOLLECTOR_PASSWORD .env | cut -d= -f2)
HOST=$(grep FFCOLLECTOR_HOSTIP .env | cut -d= -f2)

# Speichern Sie diese Werte für alle nächsten Commands:
echo "PASS=$PASS"
echo "HOST=$HOST"
```

**Diagnose-Sequenz (der Reihe nach):**

#### M3.1: Host erreichbar?
```bash
ping -c 2 "$HOST"
```

| Ergebnis | Maßnahme |
|----------|----------|
| Antwort erhalten | → M3.2 |
| Keine Antwort | 🚨 **NETZWERK-AUSFALL** - Host offline oder netzwerkunerreichbar |

#### M3.2: SSH-Verbindung?
```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo 'SSH OK'"
```

| Ergebnis | Maßnahme |
|----------|----------|
| "SSH OK" angezeigt | → M3.3 |
| Permission denied | 🚨 **CREDENTIALS FALSCH** - .env überprüfen |
| No route to host | 🚨 **FIREWALL/NETZWERK-PROBLEM** |

#### M3.3: Batman-Mesh aktiv?
```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "ip -br link show bat0 l2tp-hat"
```

**Erwartete Ausgabe:**
```
bat0             UP       ...
l2tp-hat         UP       ...
```

| Ergebnis | Maßnahme |
|----------|----------|
| Beide UP | → M3.4 |
| bat0 DOWN | → **M6: Services neustarten** |
| l2tp-hat DOWN | → **M6: Services neustarten** |
| Nicht vorhanden | → **M6: Services neustarten** |

#### M3.4: Yanic sammelt Daten?
```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "jq '.nodes | map(select(.is_online == true)) | length' \
  /home/marcus/ffmap/docker/data/meshviewer.json"
```

| Ergebnis | Maßnahme |
|----------|----------|
| `> 50` | → M3.5 (Upload prüfen) |
| `0-50` | → M3.6 (Docker-Status) |
| Datei nicht vorhanden | → M3.6 (Docker-Status) |

#### M3.5: Upload läuft?
```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "tail -10 /home/marcus/ffmap/docker/upload.log"
```

**Erwartete Ausgabe (letzte Zeile):**
```
2026-07-15 07:15:01  OK  meshviewer.json
```

| Ergebnis | Maßnahme |
|----------|----------|
| OK für meshviewer.json | Daten sollten auf Website sein → **Browser-Cache leer machen (M1 wiederholen)** |
| FEHLER | → **M7: Upload-Fehler beheben** |
| Alte Timestamps | → **M7: Cronjob prüfen** |

#### M3.6: Docker-Status?
```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "cd /home/marcus/ffmap && docker compose -f docker/docker-compose.yml ps"
```

**Sollte zeigen:**
```
yanic        ... Up ...
mcast-join   ... Up ...
grafana      ... Up ...
```

| Ergebnis | Maßnahme |
|----------|----------|
| Alle UP | → **M8: Yanic Logs prüfen** |
| Einer/mehrere nicht UP | → **M6: Docker neu starten** |

---

## 🟢 BEHEBUNGS-MASSNAHMEN

### M4: Upload-Problem beheben

```bash
# Manueller Upload-Test
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "/home/marcus/ffmap/docker/upload.sh"

# Log überprüfen
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "tail -20 /home/marcus/ffmap/docker/upload.log"
```

**Typische Upload-Fehler:**

| Fehler | Ursache | Lösung |
|--------|--------|--------|
| `550 Access Denied` | FTP-Credentials falsch | Check: `docker/upload.sh` Zeile 7-8 |
| `Connection refused` | FTP-Server down | Warten oder Hosting kontaktieren |
| `Timeout` | Netzwerk-Latenz | Warten oder Upload erneut versuchen |
| Keine Ausgabe | Cronjob nicht aktiv | → M7 |

### M5: Frontend-Problem beheben

Falls M2 > 50 zeigt, aber Meshviewer immer noch 0:

```bash
# 1. Browser-Developer-Tools öffnen: F12
# 2. Tab "Console" öffnen
# 3. Nach roten Fehlern suchen:
#    - "failed to fetch data"
#    - "404 Not Found"
#    - "CORS"

# 4. Config prüfen:
curl -s 'https://www.freifunk-hattingen.de/meshviewer/config.json' | \
  jq '.dataPath'
```

**Sollte anzeigen:**
```
["https://www.freifunk-hattingen.de/json/"]
```

**Falls nicht:** Meshviewer-Konfiguration im Webhosting anpassen

### M6: Services neustarten

```bash
# Option A: Nur Batman-Services
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S systemctl restart batman-l2tp.service freifunk-batman.service"

# Option B: Kompletter Reboot (falls A nicht hilft)
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S shutdown -r now"

# Nach Reboot: 2-3 Minuten warten, dann M2 erneut ausführen
```

### M7: Cronjob-Fehler beheben

```bash
# Cronjob Status prüfen
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "crontab -l | grep upload"

# Sollte anzeigen:
# */5 * * * * /home/marcus/ffmap/docker/upload.sh >> ...

# Falls fehlt oder falsch: auf dem Host manuell editieren
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "crontab -e"

# Dann diese Zeile hinzufügen:
# */5 * * * * /home/marcus/ffmap/docker/upload.sh >> /home/marcus/ffmap/docker/upload.log 2>&1
```

### M8: Yanic Logs prüfen

```bash
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "docker logs yanic --tail 100"
```

**Nach diesen Strings suchen:**

| String | Bedeutung |
|--------|-----------|
| `sending multicasts` | Yanic sendet Anfragen ✅ |
| `data.nodes_count=0` | Keine Antworten vom Mesh ❌ |
| `no configuration found` | Yanic-Config fehlt ❌ |
| `loaded NNN nodes` | Daten aus state.json geladen ✅ |
| `ERROR` | Fehler in Yanic |

**Wenn Fehler gefunden:**
```bash
# Docker-Container neu starten
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "cd /home/marcus/ffmap && docker compose -f docker/docker-compose.yml restart yanic"

# Warten 30 Sekunden, dann Logs erneut prüfen
```

---

## 📊 ENTSCHEIDUNGSBAUM (Schnelle Orientierung)

```
START: Meshviewer zeigt 0 Online-Knoten
│
├─→ M1: Browser-Cache leeren
│   ├─ JA, > 0 danach? → ✅ FERTIG
│   └─ NEIN? → M2
│
├─→ M2: curl zeigt Online-Knoten?
│   ├─ 0? → Problem auf Server → M3
│   ├─ > 0? → Problem auf Frontend → M5
│   └─ 404/Fehler? → Upload-Problem → M4
│
├─→ M3: ffcollector diagnostizieren
│   ├─ Nicht erreichbar? → 🚨 Netzwerk-Problem
│   ├─ SSH OK, bat0 DOWN? → M6
│   ├─ Docker nicht UP? → M6
│   ├─ Yanic 0 Knoten? → M8
│   └─ Upload OK? → M1 (Browser-Cache)
│
├─→ M4: Upload-Fehler → siehe Fehler-Tabelle
├─→ M5: Frontend-Fehler → Browser DevTools + config.json prüfen
├─→ M6: Services neu starten → Warten 2-3 Min → M2
├─→ M7: Cronjob aktivieren
├─→ M8: Yanic Logs → Container neu starten → Warten 30s → M2
│
└─→ ✅ Problem sollte nach einer dieser Maßnahmen gelöst sein
```

---

## ⏱️ CHECKLISTE: Schritt für Schritt

```
□ M1: Browser-Cache leeren (CTRL+F5)
  Resultat: ____________

□ M2: curl-Test ausführen
  Resultat: ____________

  Falls 0 → weiter mit M3
  Falls > 0 → weiter mit M5
  Falls 404 → weiter mit M4

□ M3: ffcollector diagnostizieren
  □ M3.1: Ping
  □ M3.2: SSH
  □ M3.3: Batman UP?
  □ M3.4: Yanic Daten?
  □ M3.5: Upload OK?
  □ M3.6: Docker Status?

□ M4/M5/M6/M7/M8: Behebung durchführen
  Gewählte Maßnahme: ____________

□ M2 erneut ausführen zur Verifikation
  Resultat: ____________

□ ✅ Problem gelöst
  Notiz für nächstes Mal: ____________
```

---

## 🆘 WENN NICHTS FUNKTIONIERT

```bash
# Letzte Zuflucht: Vollständiger Reboot
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S shutdown -r now"

# ODER: Alle Services nacheinander neustarten
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no marcus@"$HOST" \
  "echo '$PASS' | sudo -S systemctl restart \
  tunneldigger.service batman-l2tp.service freifunk-batman.service"

# Danach: 2 Minuten warten und M2 nochmal versuchen
```

---

## 📝 NOTIZ-TEMPLATE (für jedes Incident)

```markdown
## Incident vom [DATUM]

**Symptom:** Meshviewer zeigt 0 Online-Knoten

**Zeitstempel erkannt:** [UHRZEIT]

**M1 (Browser-Cache):** [JA/NEIN → gelöst?]

**M2 (curl-Test):** [Ergebnis: ___ Online-Knoten]

**Ursache identifiziert:** [Netzwerk/Server/Frontend/Upload/...]

**Behebte Maßnahme:** [M3/M4/M5/M6/M7/M8]

**Spezifische Fehler:** 
[Fehlermeldungen aus Logs einfügen]

**Lösung:** 
[Was genau hat funktioniert?]

**Dauer:** [Zeit von Symptom bis Lösung]

**Folgemassnahmen:**
- [ ] Ursache-Analyse vertiefen
- [ ] Monitoring erweitern?
- [ ] Automatisierung verbessern?
```

---

## 📞 ESKALATION (nur wenn alles fehlschlägt)

1. **Server-Admin kontaktieren** (falls Netzwerk/Hosting-Problem)
2. **Webhosting-Provider** (falls Upload/Website-Problem)
3. **Freifunk-Community** (falls Mesh-Problem)

Mit Infos:
- Zeitstempel des Incidents
- Durchgeführte Maßnahmen (M1-M8)
- Fehlermeldungen aus den Logs
- Status von M2 und M3

