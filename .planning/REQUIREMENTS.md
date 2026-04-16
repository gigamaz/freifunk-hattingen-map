# Requirements: Gluon Firmware ffhat

**Defined:** 2026-04-15
**Core Value:** Router-Besitzer können ein offizielles ffhat-Firmware-Image flashen und sich sofort ins Mesh einwählen — ohne manuelle Konfiguration.

## v1 Requirements

### Gluon Setup

- [x] **GLUON-01**: Gluon v2023.2.5 ist als Git-Submodul eingebunden
- [x] **GLUON-02**: `site.conf` enthält korrekte ffhat-Netzwerkparameter (Tunneldigger-Broker, IPv4/IPv6, batman-adv)
- [x] **GLUON-03**: `site.mk` definiert die zu bauenden Packages (inkl. `gluon-mesh-vpn-l2tp`)
- [x] **GLUON-04**: Build-Umgebung ist dokumentiert und reproduzierbar aufzusetzen

### Build

- [ ] **BUILD-01**: Firmware für Target `ath79-generic` lässt sich erfolgreich bauen
- [ ] **BUILD-02**: Firmware für Target `x86-64` lässt sich erfolgreich bauen
- [ ] **BUILD-03**: Build-Prozess ist über ein Skript oder Makefile steuerbar
- [ ] **BUILD-04**: Images landen in einem definierten Output-Verzeichnis

### Autoupdater

- [x] **UPDATE-01**: Autoupdater-Branch `stable` ist in `site.conf` definiert
- [ ] **UPDATE-02**: Manifest-Signierung ist dokumentiert (ECDSA-Keys)
- [ ] **UPDATE-03**: Manifest-Format und Upload-Pfad sind festgelegt

### Distribution

- [ ] **DIST-01**: Firmware-Images sind per Download erreichbar (FTP oder alternatives Hosting)
- [ ] **DIST-02**: Ein Knoten kann mit dem gebauten Image geflasht werden und verbindet sich mit dem Mesh

## v2 Requirements

### Weitere Targets

- **TARGET-01**: `ramips-mt7621` (TP-Link Archer C6 u.a.)
- **TARGET-02**: `ipq40xx-generic` (Netgear, ASUS)
- **TARGET-03**: `bcm27xx` (Raspberry Pi als Offloader)

### CI/CD

- **CI-01**: Automatischer Build bei Git-Tag (GitHub Actions / Woodpecker)
- **CI-02**: Automatisches Signieren und Upload des Manifests
- **CI-03**: Changelog-Generierung pro Release

### Dokumentation

- **DOC-01**: Anleitung für neue Router-Flasher (ffhat-spezifisch)
- **DOC-02**: Gateway-/Broker-Konfiguration dokumentiert für Onboarding neuer Betreiber

## Out of Scope

| Feature | Reason |
|---------|--------|
| fastd / WireGuard VPN | ffhat nutzt ausschließlich Tunneldigger/L2TP |
| Multi-Domain-Setup | Nur `ffhat`, kein Bedarf für weitere Domains |
| Webinterface für Firmware-Auswahl | Einfacher Download-Link reicht für v1 |
| Automatische Rollouts | Autoupdater-Signierung ist manueller Schritt in v1 |
| Eigenes OpenWrt-Paket-Repository | Gluon bringt alles nötige mit |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GLUON-01 | Phase 1 | Complete |
| GLUON-02 | Phase 1 | Complete |
| GLUON-03 | Phase 1 | Complete |
| GLUON-04 | Phase 1 | Complete |
| BUILD-01 | Phase 2 | Pending |
| BUILD-02 | Phase 2 | Pending |
| BUILD-03 | Phase 2 | Pending |
| BUILD-04 | Phase 2 | Pending |
| UPDATE-01 | Phase 1 | Complete |
| UPDATE-02 | Phase 3 | Pending |
| UPDATE-03 | Phase 3 | Pending |
| DIST-01 | Phase 3 | Pending |
| DIST-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-15*
*Last updated: 2026-04-15 after initial definition*
