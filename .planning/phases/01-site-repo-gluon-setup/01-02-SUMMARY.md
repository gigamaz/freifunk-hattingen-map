---
phase: 01-site-repo-gluon-setup
plan: "02"
subsystem: infra
tags: [gluon, lua, makefile, tunneldigger, l2tp, batman-adv, autoupdater]

requires:
  - phase: 01-site-repo-gluon-setup/01-01
    provides: Gluon v2023.2.5 Submodul, site/-Verzeichnisstruktur, .gitignore, README.md

provides:
  - site/site.conf — Lua-Konfiguration mit allen ffhat-Netzwerkparametern (Tunneldigger, IPv4/IPv6, batman-adv, Autoupdater)
  - site/site.mk — Paketliste für den Gluon-Build mit gluon-mesh-vpn-l2tp

affects:
  - 02-gluon-build (braucht site.conf/site.mk als einzigen Community-Input)
  - 03-autoupdater-keys (pubkeys-Array in site.conf nach ECDSA-Generierung füllen)

tech-stack:
  added: [Gluon Lua site.conf format, GNU Make site.mk format]
  patterns:
    - "site.conf als Lua-Tabelle (nicht Lua-Skript) — beginnt mit { und endet mit }"
    - "GLUON_SITE_PACKAGES als Make-Variable mit Backslash-Fortsetzung"
    - "domain_seed als Platzhalter mit Kommentar — wird vor erstem signierten Build ersetzt"
    - "pubkeys leer (kommentiert) — Autoupdater inaktiv bis Phase 3"

key-files:
  created:
    - site/site.conf
    - site/site.mk
  modified: []

key-decisions:
  - "gluon-mesh-vpn-l2tp als einziges VPN-Paket — fastd und wireguard bewusst ausgelassen (bestehende Broker-Infrastruktur)"
  - "GLUON_RELEASE 2023.2.5+ffhat1 — semantische Versionierung mit Community-Suffix"
  - "GLUON_PRIORITY 0 — alle Knoten updaten sofort (kein Rollout-Throttling für initiales Deployment)"
  - "pubkeys-Array vorerst leer (kommentiert) — Autoupdater nicht aktiv bis ECDSA-Keypair in Phase 3"
  - "domain_seed als Platzhalter mit explizitem Hinweis auf openssl rand -hex 32"

patterns-established:
  - "Netzwerkparameter stammen ausschliesslich aus PROJECT.md (laufende Knoten als Quelle)"
  - "Kein fastd, kein wireguard — nur L2TP/Tunneldigger im ffhat-Scope"

requirements-completed: [GLUON-02, GLUON-03, UPDATE-01]

duration: 5min
completed: "2026-04-16"
---

# Phase 01 Plan 02: site.conf und site.mk für ffhat Summary

**Gluon site.conf mit Tunneldigger-Broker broker1.ff-en.de:8942, IPv4/IPv6-Prefixen und site.mk mit gluon-mesh-vpn-l2tp-Paketliste fuer ffhat erstellt**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-16T04:35:00Z
- **Completed:** 2026-04-16T04:36:01Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- site/site.conf als Lua-Tabelle mit allen ffhat-Netzwerkparametern: Tunneldigger-Broker `broker1.ff-en.de:8942`, `prefix4 = "10.254.0.0/16"`, `prefix6 = "2a11:6c6:4000:feed::/64"`, Autoupdater-Branch `stable`, Site-Code `ffhat`
- site/site.mk mit `GLUON_SITE_PACKAGES` (18 Pakete), `GLUON_RELEASE := 2023.2.5+ffhat1`, `GLUON_PRIORITY := 0` — kein fastd, kein wireguard
- Beide Dateien sind der einzige Community-spezifische Input fuer den Gluon-Build in Phase 02

## Task Commits

1. **Task 1: site.conf mit allen ffhat-Netzwerkparametern erstellen** - `7c636d5` (feat)
2. **Task 2: site.mk mit Paketliste erstellen** - `9af6122` (feat)

**Plan metadata:** (folgt in diesem Schritt)

## Files Created/Modified

- `site/site.conf` — Lua-Konfiguration: Tunneldigger, IPv4/IPv6-Prefixe, batman-adv, NTP, WiFi, Autoupdater, domain_names, config_mode
- `site/site.mk` — Paketliste: gluon-mesh-vpn-l2tp + 17 weitere Pakete, GLUON_RELEASE/PRIORITY-Definitionen

## Key Parameters (site.conf)

| Parameter | Wert |
|-----------|------|
| broker | broker1.ff-en.de:8942 |
| prefix4 | 10.254.0.0/16 |
| prefix6 | 2a11:6c6:4000:feed::/64 |
| next_node ip4 | 10.254.0.1 |
| next_node ip6 | 2a11:6c6:4000:feed:ff::1 |
| site_code | ffhat |
| autoupdater branch | stable |
| wifi24 channel | 6 |
| wifi5 channel | 44 |

## Decisions Made

- gluon-mesh-vpn-l2tp als einziges VPN-Paket — fastd und wireguard bewusst ausgelassen (bestehende Broker-Infrastruktur)
- GLUON_RELEASE 2023.2.5+ffhat1 — semantische Versionierung mit Community-Suffix
- GLUON_PRIORITY 0 — alle Knoten updaten sofort fuer initiales Deployment
- pubkeys leer und kommentiert — Autoupdater erst nach Phase 3 (ECDSA-Keypair) aktiv

## Deviations from Plan

None - plan executed exactly as written.

Note: The combined commit message from the plan (all Phase-1-files in one commit) was not applied because site.conf was already committed in a prior session (7c636d5). site.mk was committed separately as specified in the execution instructions.

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `domain_seed = "ffhat-seed-placeholder"` | site/site.conf | 10 | Intentional — Betreiber muss `openssl rand -hex 32` ausfuehren vor erstem Build. Threat T-01-04 mitigiert durch expliziten Kommentar. |
| pubkeys-Array leer (kommentiert) | site/site.conf | ~158-162 | Intentional — ECDSA-Keypair wird in Phase 3 generiert; Autoupdater ist ohne Key nicht aktiv (Threat T-01-03) |

Diese Stubs verhindern NICHT das Ziel dieses Plans (Gluon-Build-Input erstellen). Sie werden in Phase 3 aufgeloest.

## Threat Surface Scan

No new threat surface beyond what is documented in the plan's threat_model. All three threats (T-01-03, T-01-04, T-01-05) are addressed per plan specification.

## Issues Encountered

None.

## User Setup Required

Before the first signed build (Phase 3):

1. Replace `domain_seed` in `site/site.conf`:
   ```bash
   openssl rand -hex 32
   # Ergebnis in site.conf unter domain_seed eintragen
   ```

2. After ECDSA key generation (Phase 3): add public key to `pubkeys` array in `site/site.conf` under `autoupdater.branches.stable`.

## Next Phase Readiness

- site.conf und site.mk sind vollstaendig und korrekt — Phase 02 (Gluon-Build) kann starten
- Voraussetzung Phase 02: Build-Host mit ~20 GB Disk + 8 GB RAM + mehrere Stunden pro Target
- domain_seed-Ersetzung und pubkeys koennen nach Phase 02 und vor Phase 03 erfolgen

---
*Phase: 01-site-repo-gluon-setup*
*Completed: 2026-04-16*
