# Gluon Firmware für Freifunk Hattingen (ffhat)

Dieses Repository enthält die Build-Konfiguration (`site/`) für die
[Gluon](https://gluon.readthedocs.io/)-Firmware der Freifunk-Community
Hattingen (Ennepe-Ruhr-Kreis). Gluon ist als Git-Submodul unter `gluon/`
eingebunden.

## Build-Umgebung aufsetzen

### Voraussetzungen

**Betriebssystem:** Debian 12 (Bookworm) oder Ubuntu 22.04 LTS (64-bit)
**Ressourcen:** mindestens 20 GB freier Speicher, 8 GB RAM (16 GB empfohlen)
**Zeitbedarf:** 2–4 Stunden pro Target (beim ersten Build; danach schneller dank ccache)

**Abhängigkeiten installieren (Debian/Ubuntu):**
```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential gawk gettext git libncurses-dev libssl-dev \
  python3 python3-distutils rsync unzip wget zlib1g-dev \
  qemu-utils ecdsautils
```

### Repository klonen

```bash
git clone https://github.com/DEIN-ORG/freifunk.git
cd freifunk
git submodule update --init --recursive
```

### Firmware bauen

```bash
cd gluon

# Feeds aktualisieren (einmalig oder nach Gluon-Update)
make update

# ath79-generic (TP-Link, Ubiquiti u.a.)
make GLUON_TARGET=ath79-generic -j$(nproc) GLUON_SITEDIR=../site

# x86-64 (VM-Tests, x86-Router)
make GLUON_TARGET=x86-64 -j$(nproc) GLUON_SITEDIR=../site
```

Build-Artefakte landen in `gluon/output/`.

### Autoupdater-Manifest signieren

Siehe Phase 3 — ECDSA-Keypair muss vorher erzeugt werden (ecdsautils).

## Netzwerk-Parameter (ffhat)

| Parameter            | Wert                          |
|----------------------|-------------------------------|
| Site-Code            | ffhat                         |
| Domain-Code          | ffhat                         |
| Batman-adv Interface | bat-hat                       |
| IPv4 Mesh-Subnetz    | 10.254.0.0/16                 |
| IPv4 Broker-Bridge   | 10.254.0.2                    |
| IPv6 Prefix          | 2a11:6c6:4000:feed::/64       |
| IPv6 Gateway         | 2a11:6c6:4000:feed:ff::1      |
| VPN                  | Tunneldigger L2TP             |
| Broker               | broker1.ff-en.de:8942         |
| Autoupdater-Branch   | stable                        |
| Gluon-Version        | v2023.2.5                     |

## Repository-Struktur

```
freifunk/
├── gluon/          # Gluon-Upstream (Submodul, v2023.2.5)
├── site/           # ffhat site-Konfiguration
│   ├── site.conf   # Lua — Netzwerkparameter
│   ├── site.mk     # Make — Paketliste
│   └── i18n/       # Übersetzungen (Pflichtverzeichnis)
├── tunneldigger/   # L2TP-Broker (Submodul)
├── yanic/          # Yanic-Collector (Submodul)
├── yanicmap/       # Lokale Betriebsdaten
├── docker/         # Docker-Deployment für ffcollector
└── README.md       # Diese Datei
```
