# Roadmap: Gluon Firmware ffhat

## Overview

Vom leeren `gluon/`-Verzeichnis bis zum ersten signierten Firmware-Image, das ein echter ffhat-Knoten per Autoupdater ziehen kann. Phase 1 legt das Site-Repo mit allen ffhat-Netzwerkparametern an. Phase 2 baut die Images für ath79-generic und x86-64. Phase 3 signiert das Autoupdater-Manifest und verteilt die Images per FTP — fertig.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Site Repo & Gluon Setup** - Gluon als Submodul einbinden, site.conf/site.mk für ffhat konfigurieren, Build-Umgebung dokumentieren (completed 2026-04-16)
- [ ] **Phase 2: Build** - Firmware für ath79-generic und x86-64 erfolgreich bauen, Build-Output in definiertes Verzeichnis schreiben
- [ ] **Phase 3: Signing & Distribution** - Autoupdater-Manifest signieren und Firmware-Images per FTP erreichbar machen; einen echten Knoten flashen und Mesh-Verbindung bestätigen

## Phase Details

### Phase 1: Site Repo & Gluon Setup
**Goal**: Die vollständige Build-Grundlage für ffhat existiert — Gluon Upstream eingebunden, site.conf mit allen ffhat-Netzwerkparametern korrekt befüllt, Build-Umgebung reproduzierbar dokumentiert
**Depends on**: Nothing (first phase)
**Requirements**: GLUON-01, GLUON-02, GLUON-03, GLUON-04, UPDATE-01
**Success Criteria** (what must be TRUE):
  1. `git submodule status` zeigt Gluon v2023.2.5 unter `gluon/` ohne dirty marker
  2. `site.conf` enthält Tunneldigger-Broker `broker1.ff-en.de:8942`, IPv4 `10.254.0.0/16`, IPv6 `2a11:6c6:4000:feed::/64`, batman-adv Interface `bat-hat`, Domain `ffhat` und Autoupdater-Branch `stable`
  3. `site.mk` listet `gluon-mesh-vpn-l2tp` und alle weiteren gewünschten Packages
  4. Eine README oder Makefile-Kommentar beschreibt lückenlos, wie die Build-Umgebung frisch aufgesetzt wird (Abhängigkeiten, Disk, RAM)
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Gluon-Submodul v2023.2.5 einbinden, site/-Struktur anlegen, README und .gitignore erstellen
- [x] 01-02-PLAN.md — site.conf und site.mk für ffhat ausschreiben und in einem Git-Commit zusammenfassen

### Phase 2: Build
**Goal**: Firmware-Images für alle Primär-Targets liegen im Output-Verzeichnis und sind via Skript reproduzierbar erzeugbar
**Depends on**: Phase 1
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04
**Success Criteria** (what must be TRUE):
  1. `make GLUON_TARGET=ath79-generic` läuft durch ohne Fehler und erzeugt `.bin`-Images im Output-Verzeichnis
  2. `make GLUON_TARGET=x86-64` läuft durch ohne Fehler und erzeugt bootfähige Images
  3. Ein Build-Skript oder Makefile-Target erlaubt es, beide Targets mit einem Befehl anzustoßen
  4. Images liegen in einem klar definierten Pfad (z.B. `gluon/output/`) und sind nicht im Git-Index
**Plans**: TBD

Plans:
- [ ] 02-01: Build-Umgebung aufsetzen, erstes Target durchbauen (ath79-generic)
- [ ] 02-02: x86-64 bauen, Build-Wrapper-Skript schreiben

### Phase 3: Signing & Distribution
**Goal**: Signiertes Autoupdater-Manifest und Firmware-Images sind per HTTP/FTP erreichbar; ein Knoten kann das Image ziehen und sich mit dem Mesh verbinden
**Depends on**: Phase 2
**Requirements**: UPDATE-02, UPDATE-03, DIST-01, DIST-02
**Success Criteria** (what must be TRUE):
  1. Ein ECDSA-Keypair existiert, der Signiervorgang ist Schritt-für-Schritt dokumentiert
  2. Manifest-Format und Upload-Pfad auf Netcup FTP sind festgelegt und im Repo dokumentiert
  3. Firmware-Images sind unter einer stabilen URL per Download erreichbar
  4. Ein realer Router wird mit dem gebauten Image geflasht und verbindet sich mit Tunneldigger-Broker `broker1.ff-en.de` und erscheint in Yanic-Daten (nodes.json)
**Plans**: TBD

Plans:
- [ ] 03-01: Autoupdater-Manifest-Workflow dokumentieren und signieren
- [ ] 03-02: Images per FTP auf Netcup hochladen, Knoten flashen und Mesh-Verbindung verifizieren

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Site Repo & Gluon Setup | 2/2 | Complete   | 2026-04-16 |
| 2. Build | 0/2 | Not started | - |
| 3. Signing & Distribution | 0/2 | Not started | - |
