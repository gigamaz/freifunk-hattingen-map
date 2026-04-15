# External Integrations

**Analysis Date:** 2026-04-15

## APIs & External Services

**Freifunk Mesh Network (respondd):**
- Service: Batman-adv respondd protocol (UDP multicast, IPv6)
- What it does: Polls mesh nodes for stats, client counts, location, firmware info
- Interface: `bat0` (batman-adv mesh interface, backed by Tunneldigger L2TP tunnels)
- Multicast groups: `ff05::2:1001` (newer Gluon nodes), `ff02::2:1001` (older Gluon nodes)
- Config: `yanicmap/yanic.toml` [respondd] section, `docker/yanic.toml` [respondd] section
- Keepalive: `yanicmap/mcast_join.py`, `docker/mcast_join.py` — Python scripts that join multicast groups to keep batman-adv 2024.0 forwarding active

**Netcup FTP Webhosting:**
- Service: Netcup shared hosting (`af991.netcup.net`)
- What it does: Hosts JSON data files and PNG graphs publicly for meshviewer map consumption
- Protocol: FTP with TLS (`--ftp-ssl --insecure` via curl; FTPS via `ftplib.FTP_TLS` in Python)
- Remote paths: `/freifunk/json/` (JSON files), `/freifunk/json/graphs/` (PNG charts)
- Upload scripts:
  - `upload_mesh.sh` — local cron-based JSON upload from `yanicmap/data/`
  - `docker/upload.sh` — server-side JSON upload from Docker data volume
  - `docker/generate_graphs.py` — generates and uploads PNG graphs
- Credentials: Hardcoded in scripts (user `hosting102099`, host `af991.netcup.net`)
- Schedule: cron `*/5 * * * *` (`yanicmap/upload.cron`)

## Data Storage

**Databases:**
- Type: InfluxDB v1
  - Connection: `http://localhost:8086` (system service on ffcollector, not containerized)
  - Database name: `freifunk`
  - Auth: No username/password (open local access)
  - Used by: Yanic Docker config (`docker/yanic.toml` [database.connection.influxdb]), Grafana (`docker/grafana-provisioning/datasources/influxdb.yaml`), graph generator (`docker/generate_graphs.py`)
  - Yanic also supports InfluxDB v2 (`github.com/influxdata/influxdb-client-go/v2`) per go.mod, but current configs use v1

**File Storage:**
- Local JSON state: `yanicmap/state.json` — persisted node cache (loaded on start, updated every 30s)
- JSON outputs: `yanicmap/data/` (local) or `/data/` (Docker volume) — meshviewer.json, nodes.json, graph.json, nodelist.json, nodes.geojson
- Remote: Netcup FTP (see above)
- Backups: `yanic/yanic-data-backup.tar.gz`, `ffmap-backup.tar.gz` at repo root

**Caching:**
- None (yanic state.json serves as node data cache, not a caching layer)

## Authentication & Identity

**Auth Provider:**
- None (no user authentication system)
- Grafana: Basic auth, admin password hardcoded in `docker/docker-compose.stats.yml` as `GF_SECURITY_ADMIN_PASSWORD: "freifunk"`; sign-up disabled

## Monitoring & Observability

**Metrics / Dashboards:**
- Grafana 11.6.0 — Provisioned dashboards from `docker/grafana-provisioning/dashboards/`
- Datasource: InfluxDB at `localhost:8086`, database `freifunk`
- Config: `docker/grafana-provisioning/datasources/influxdb.yaml`

**Graph Generation:**
- `docker/generate_graphs.py` — Python script queries InfluxDB for per-node time-series (clients, CPU load, uptime), generates PNG charts via matplotlib, uploads to Netcup FTP

**Error Tracking:**
- None

**Logs:**
- Yanic: systemd journal (`SyslogIdentifier=yanic`) for local setup; `journald` Docker logging driver for Docker setup
- mcast-join: systemd journal (`SyslogIdentifier=mcast-join`)
- Upload results: `yanicmap/upload.log` (cron job stdout redirect)

## CI/CD & Deployment

**Hosting:**
- Local development/run: `openclaw` machine (user `openclaw`)
- Production server: `ffcollector` (user `marcus`, SSH alias `marcus@ffcollector`)
- Web hosting: Netcup shared hosting (`af991.netcup.net`)

**Deployment Scripts:**
- `docker/deploy_to_ffcollector.sh` — SCP files to ffcollector, then run migrate.sh remotely
- `docker/migrate.sh` — Stops old systemd services, copies state.json, runs `docker compose up -d`
- `yanicmap/deploy_ffcollector.sh` — Legacy: writes config inline, creates systemd user services, starts them directly (pre-Docker approach)

**CI Pipeline (Yanic upstream only):**
- Woodpecker CI: `yanic/.woodpecker/go.yaml`, `yanic/.woodpecker/docs.yaml`
- Drone CI: `yanic/.drone.yml`
- GitLab CI: `yanic/.gitlab-ci.yml`
- GitHub Actions: `yanic/.github/`
- semantic-release: `yanic/.releaserc`

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None (push model: periodic cron uploads to FTP)

## Network Architecture

**VPN / Mesh:**
- Tunneldigger (L2TP broker) — `tunneldigger/` — mesh nodes connect via L2TP tunnels
- batman-adv — layer 2 mesh routing over `bat0` interface
- Yanic listens on `bat0` for respondd UDP multicasts from Gluon firmware nodes

**Yanic Output Formats Supported:**
- `meshviewer-ffrgb` (modern meshviewer format) → `meshviewer.json`
- `meshviewer` v2 (classic format) → `nodes.json`, `graph.json`
- `nodelist` → `nodelist.json`
- `geojson` → `nodes.geojson`
- Additional (via Go output modules): graphite, influxdb, influxdb2, prometheus-sd, raw, raw-jsonl, respondd, logging

---

*Integration audit: 2026-04-15*
