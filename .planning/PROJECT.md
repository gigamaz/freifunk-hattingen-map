# Gluon Firmware für Freifunk Hattingen (ffhat)

## What This Is

Dieses Projekt baut die [Gluon](https://gluon.readthedocs.io/)-Firmware für die Freifunk-Community Hattingen (Ennepe-Ruhr-Kreis). Es umfasst die Integration des Gluon-Projekts als Submodul, die Konfiguration des `site`-Repositorys passend zur bestehenden ffhat-Infrastruktur (Tunneldigger, batman-adv, IPv4/IPv6) und den automatisierten Build-Prozess für die relevanten Router-Targets. Die fertigen Images werden zum Download bereitgestellt.

## Core Value

Router-Besitzer können ein offizielles ffhat-Firmware-Image flashen und sich sofort ins Mesh einwählen — ohne manuelle Konfiguration.

## Requirements

### Validated

- ✓ Tunneldigger-Broker läuft auf `broker1.ff-en.de:8942` — bestehende Infrastruktur
- ✓ Batman-adv Mesh-Interface `bat-hat` aktiv, Domain-Code `ffhat` — aus state.json
- ✓ IPv6-Prefix `2a11:6c6:4000:feed::/64` im Einsatz — aus aktiven Knoten
- ✓ Mesh-Subnet `10.254.0.0/16`, Broker-Bridge `10.254.0.2` — aus bridge_functions.sh
- ✓ Gluon v2023.2.5 ist die aktuelle Netzwerk-Version — aus state.json (Knoten-Firmware)

### Active

- [x] Gluon als Git-Submodul einbinden (v2023.2.5) — Validated in Phase 01: site-repo-gluon-setup
- [x] `site.conf` und `site.mk` für ffhat konfigurieren — Validated in Phase 01: site-repo-gluon-setup
- [ ] Build-Umgebung (Docker oder nativ) aufsetzen
- [ ] Firmware für Primär-Targets bauen: `ath79`, `x86-64`
- [ ] Autoupdater-Manifest und Signier-Workflow einrichten
- [ ] Firmware-Images zum Download bereitstellen (Netcup FTP oder alternatives Hosting)

### Out of Scope

- fastd/WireGuard-VPN — ffhat nutzt ausschließlich Tunneldigger/L2TP
- Mehrere Domains/Sites — nur `ffhat`, kein Multi-Domain-Setup
- CI/CD-Pipeline (automatische Builds bei jedem Commit) — manueller Build-Prozess reicht für v1
- Web-Frontend für Firmware-Auswahl — Link zu Images genügt

## Context

### Bestehende Infrastruktur

Das Repo enthält bereits die vollständige Betriebsinfrastruktur für ffhat:
- **Yanic** (Go): Sammelt Knotendaten via respondd über `bat0`/`bat-hat`, schreibt JSON-Outputs
- **Tunneldigger** (Python/C): L2TP-VPN-Broker — Knoten verbinden sich via `broker1.ff-en.de:8942`
- **batman-adv**: Layer-2-Mesh über Interface `bat-hat` (Domain `ffhat`)
- **Upload-Stack**: cron + curl → FTP auf Netcup (`af991.netcup.net`)
- **Stats-Stack**: InfluxDB + Grafana (Docker, auf ffcollector)

### Netzwerk-Parameter (aus laufenden Knoten extrahiert)

| Parameter | Wert |
|-----------|------|
| Site-Code | `ffhat` |
| Domain-Code | `ffhat` |
| Batman-adv Interface | `bat-hat` |
| IPv4 Mesh | `10.254.0.0/16` |
| IPv4 Broker-Bridge | `10.254.0.2` |
| IPv6 Prefix | `2a11:6c6:4000:feed::/64` |
| IPv6 Gateway | `2a11:6c6:4000:feed:ff::1` |
| VPN | Tunneldigger L2TP |
| Broker | `broker1.ff-en.de:8942` |
| Autoupdater Branch | `stable` |
| Aktuell im Netz | Gluon v2023.2.5 (neu), v2021.1.2 (alt) |

### Gluon-Konventionen

Gluon-Firmware besteht aus zwei Repositories:
1. **gluon** (Upstream): OpenWrt-basiertes Build-System mit Freifunk-Paketen
2. **site** (Community): `site.conf` (Lua), `site.mk` (Make), optionale Patches

Der Build läuft via `make` mit `GLUON_TARGET=ath79-generic` o.ä.

## Constraints

- **Kompatibilität**: Gluon v2023.2.5 — muss zur batman-adv-Version `2023.1-openwrt-11` der laufenden Knoten passen
- **VPN-Typ**: Ausschließlich Tunneldigger/L2TP — keine fastd/WireGuard-Unterstützung nötig
- **Build-Ressourcen**: Build braucht ~20 GB Disk, 8+ GB RAM und mehrere Stunden pro Target
- **Signierung**: Autoupdater-Manifeste müssen mit Community-Key signiert werden (ECDSA)
- **Hosting**: Firmware-Images zu groß für Git — separates Hosting nötig (FTP, S3 o.ä.)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Gluon v2023.2.5 als Build-Basis | Kompatibel mit bestehenden Knoten (v2023.2.5+ im Netz), letzter stabiler Release | — Pending |
| Tunneldigger statt fastd | Bestehende Broker-Infrastruktur auf `broker1.ff-en.de` läuft bereits | ✓ Good |
| `ath79` + `x86-64` als Primär-Targets | TP-Link/Ubiquiti dominieren im ffhat-Netz; x86 für VM-Tests | — Pending |
| Site-Repo im bestehenden freifunk-Repo | Alles an einem Ort, Kontext zu Infrastruktur bleibt erhalten | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-16 — Phase 01 complete (Gluon-Submodul + site.conf/site.mk)*
