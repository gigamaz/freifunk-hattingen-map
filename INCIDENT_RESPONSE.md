# 🚨 Incident Response Guide

**Schnelle Navigation bei Problemen mit der Freifunk-Meshviewer-Karte**

---

## ⚡ Problem: "Meshviewer zeigt 0 Online-Knoten"

### Sofort zum richtigen Dokument:

1. **Schnelle Fehlerbehebung (5-10 Min):**
   👉 **[MASSNAHMENPLAN.md](MASSNAHMENPLAN.md)**
   - M1: Browser-Cache leeren
   - M2-M8: Strukturierte Diagnose & Lösungen
   - Checkliste + Entscheidungsbaum

2. **Detaillierte Fehlersuche (tiefergehend):**
   👉 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**
   - 5-Schritte-Prozess
   - Bekannte Probleme
   - Emergency-Kontakt

3. **Betriebliche Hinweise & Hintergrund:**
   👉 **[RUNBOOK_NEXT_RUN.md](RUNBOOK_NEXT_RUN.md)**
   - Aktueller System-Status
   - SSH-Zugangsdaten-Lage
   - Schnell-Diagnose-Anleitung

---

## 📋 Welches Dokument für welches Problem?

| Problem | Dokument | Aktion |
|---------|----------|--------|
| Meshviewer zeigt 0 Knoten | **MASSNAHMENPLAN.md** | Start mit M1 |
| Weiß nicht, wo anfangen | **MASSNAHMENPLAN.md** | Entscheidungsbaum folgen |
| Brauchst detaillierte Fehlersuche | **TROUBLESHOOTING.md** | Schritt 1-5 folgen |
| Brauchst SSH-Commands | **RUNBOOK_NEXT_RUN.md** | Diagnose-Anleitung kopieren |
| Verstehst die Architektur nicht | **YANICMAP_DOKUMENTATION.md** | System-Übersicht lesen |
| Benötigst Hintergrund zu Dateien | **DATEIANALYSE.md** | Dateistruktur prüfen |

---

## 🎯 Schnell-Start (für Ungeduldigsten)

```bash
# 1. Browser-Cache leeren (am häufigsten die Lösung!)
# CTRL+F5 in: https://www.freifunk-hattingen.de/meshviewer

# 2. Falls immer noch 0:
curl -s 'https://www.freifunk-hattingen.de/json/meshviewer.json' | \
  jq '.nodes | map(select(.is_online == true)) | length'

# 3. Wenn curl > 0 zeigt → Browser-Cache war schuld
# 4. Wenn curl 0 zeigt → Öffne MASSNAHMENPLAN.md und folge M3
```

---

## 📊 Übersicht aller Dokumentationen

```
Freifunk Hattingen - Meshviewer System

├── MASSNAHMENPLAN.md ⭐ (START HIER bei Problemen)
│   ├─ M1-M8: Konkrete Maßnahmen
│   ├─ Entscheidungsbaum
│   └─ Checkliste
│
├── TROUBLESHOOTING.md (Detailliert)
│   ├─ 5-Schritte-Prozess
│   ├─ Fehlersuche
│   └─ Bekannte Probleme
│
├── RUNBOOK_NEXT_RUN.md (Operativ)
│   ├─ System-Status
│   ├─ SSH-Commands
│   └─ Schnell-Diagnose
│
├── YANICMAP_DOKUMENTATION.md (Architektur)
│   ├─ System-Übersicht
│   ├─ Ist-Zustand
│   └─ Betrieb
│
├── DATEIANALYSE.md (Dateien)
│   ├─ Datei-Übersicht
│   ├─ Risiken
│   └─ Findings
│
└── README.md (Installation & Setup)
    ├─ Schritt-für-Schritt
    ├─ Voraussetzungen
    └─ Erste Inbetriebnahme
```

---

## 🔑 Wichtige Fakten

### System-Komponenten
- **Server:** ffcollector (192.168.1.129)
- **Anwender:** marcus
- **Mesh-Interface:** bat0 (Batman-adv)
- **Tunnel:** l2tp-hat (Tunneldigger)
- **Datenerfassung:** Yanic (Docker)
- **Website:** www.freifunk-hattingen.de/json/

### Typische Probleme & Häufigkeit
1. **Browser-Cache** (~40%) → M1 löst es
2. **Batman/Tunnel down** (~30%) → M6 löst es
3. **Docker-Problem** (~15%) → M6/M8 löst es
4. **Upload-Fehler** (~10%) → M4/M7 löst es
5. **Frontend-Fehler** (~5%) → M5 löst es

### Zugangsdaten
**Wichtig:** Nur lokal in `.env` speichern, nicht im Git!
```
FFCOLLECTOR_HOSTIP=192.168.1.129
FFCOLLECTOR_USERNAME=marcus
FFCOLLECTOR_PASSWORD=<in .env>
```

---

## 🚀 Workflow bei Incident

```
1. Problem erkannt
   ↓
2. MASSNAHMENPLAN.md öffnen
   ↓
3. M1 (Browser-Cache) versuchen
   ↓
4. Falls nicht gelöst: M2 (curl-Test)
   ↓
5. Ergebnis bestimmt nächste Maßnahme (M3-M8)
   ↓
6. Maßnahme durchführen
   ↓
7. M2 erneut versuchen (Verifikation)
   ↓
8. ✅ Gelöst oder 🔄 Nächste Maßnahme
```

---

## 💾 Daten-Locations

| Was | Wo | Host |
|-----|----|----|
| Yanic-Konfiguration | `/docker/yanic.toml` | lokal |
| JSON-Daten | `/home/marcus/ffmap/docker/data/` | ffcollector |
| Upload-Log | `/home/marcus/ffmap/docker/upload.log` | ffcollector |
| Website-Daten | `https://www.freifunk-hattingen.de/json/` | Webhosting |
| Meshviewer | `https://www.freifunk-hattingen.de/meshviewer/` | Webhosting |

---

## 📞 Kontakt / Eskalation

Wenn Maßnahmen M1-M8 nicht funktionieren:

1. **SSH-Zugang verloren?**
   - Netzwerk-Admin
   - Server-Status überprüfen

2. **Server antwortet nicht?**
   - Hosting-Provider kontaktieren
   - physische Überprüfung anfordern

3. **Upload-Fehler fortbestand?**
   - Webhosting-Support
   - FTP-Credentials überprüfen

4. **Mesh komplett down?**
   - Freifunk-Community kontaktieren
   - Broker/VPN-Server Status prüfen

**Mitbringsel zur Eskalation:**
- Zeitstempel des Incidents
- Durchgeführte Maßnahmen (M1-M8)
- Fehlermeldungen aus Logs
- Ergebnis von M2 (curl-Test)
- Ergebnis von M3 (SSH-Diagnose)

---

## 📚 Weitere Ressourcen

- **Yanic GitHub:** https://github.com/FreifunkBremen/yanic
- **Meshviewer GitHub:** https://github.com/freifunk/meshviewer
- **Gluon Firmware:** https://github.com/freifunk-gluon/gluon
- **Batman-adv:** https://www.open-mesh.org/projects/batman-adv

---

## 🎓 Lernpfad

Falls Sie das System besser verstehen möchten:

1. **Anfänger:** README.md lesen
2. **Nutzer:** MASSNAHMENPLAN.md & RUNBOOK_NEXT_RUN.md
3. **Admin:** YANICMAP_DOKUMENTATION.md & TROUBLESHOOTING.md
4. **Entwickler:** DATEIANALYSE.md & Code-Architektur

---

**Zuletzt aktualisiert:** 2026-07-15 (nach Incident-Session)
**Commits:** ec48ca2, e214bf1
