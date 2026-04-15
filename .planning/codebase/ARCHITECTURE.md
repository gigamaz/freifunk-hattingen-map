# Architecture

**Analysis Date:** 2026-04-15

## Pattern Overview

**Overall:** Pipeline / Collector-Transform-Export

The repository is an operational infrastructure project for the Freifunk Hattingen (ffhat) community mesh network. It is not a single application but a collection of coordinated services: a node-data collector (Yanic), a VPN tunnel broker/client (Tunneldigger), and an optional stats stack (InfluxDB + Grafana). Data flows in one direction: mesh nodes → collector → JSON files → FTP upload → public web.

**Key Characteristics:**
- All coordination is done via file-based outputs (JSON on disk) rather than in-process messaging
- Yanic (Go binary) is the central data hub; all other components are satellite tooling
- Two deployment modes coexist: local user-systemd and Docker Compose on `ffcollector`
- No application-level API; data consumers read files uploaded to Netcup FTP

## Layers

**Mesh Network (hardware layer):**
- Purpose: Gluon-based router nodes send respondd UDP packets over batman-adv
- Location: physical/virtual mesh via `bat0` interface
- Contains: IPv6 multicast on `ff05::2:1001` (new Gluon) and `ff02::2:1001` (legacy)
- Depends on: Tunneldigger L2TP VPN for connectivity
- Used by: Yanic collector

**Multicast Keeper:**
- Purpose: Keeps batman-adv multicast group memberships alive so respondd traffic reaches Yanic
- Location: `yanicmap/mcast_join.py`, `docker/mcast_join.py`
- Contains: Python UDP socket that joins IPv6 multicast groups on `bat0`
- Depends on: `bat0` interface being up
- Used by: Implicitly required by Yanic

**Yanic Collector (core):**
- Purpose: Queries Freifunk nodes via respondd, maintains in-memory node cache, writes JSON outputs and optionally feeds time-series databases
- Location: `yanic/` (Go source, upstream FreifunkBremen/yanic)
- Entry point: `yanic/main.go` → `yanic/cmd/serve.go`
- Contains: `respond/` (UDP collector), `runtime/` (node cache with expiry), `output/` (multi-format JSON writers), `database/` (InfluxDB v1/v2, Graphite, respondd adapters)
- Depends on: `bat0`, TOML config, optional InfluxDB
- Used by: Upload scripts, Grafana (via InfluxDB)

**Output Writers:**
- Purpose: Transform the in-memory Nodes struct into format-specific JSON files
- Location: `yanic/output/meshviewer/`, `yanic/output/meshviewer-ffrgb/`, `yanic/output/nodelist/`, `yanic/output/geojson/`, `yanic/output/raw/`, `yanic/output/prometheus-sd/`
- Contains: One Go package per output format; each implements the `output.Output` interface
- Depends on: `runtime.Nodes`
- Used by: Upload scripts

**Output Files (data layer):**
- Purpose: Filesystem cache of current node state, consumed by upload scripts
- Location (local): `yanicmap/data/` — `meshviewer.json`, `nodes.json`, `graph.json`, `nodelist.json`, `nodes.geojson`
- Location (Docker): `/data/` inside container → mounted at `docker/data/`
- Contains: JSON snapshots refreshed every 30 seconds
- State cache: `state.json` (persisted node history, survives restarts)

**Upload Layer:**
- Purpose: Push JSON files from local disk to Netcup FTP hosting every 5 minutes
- Location (local): `upload_mesh.sh` (root), scheduled via `yanicmap/upload.cron`
- Location (Docker): `docker/upload.sh`, scheduled via cron on ffcollector
- Depends on: JSON files existing in data directory, `curl` with FTP-TLS support
- Used by: Meshviewer frontend on Netcup web hosting

**Stats Stack (optional):**
- Purpose: Collect time-series node metrics, visualize with Grafana, generate PNG graphs
- Location: `docker/docker-compose.stats.yml`, `docker/generate_graphs.py`, `docker/grafana-provisioning/`
- Contains: Grafana container + graph-generator container; InfluxDB runs as system service on host
- Depends on: InfluxDB at `localhost:8086`, database `freifunk`
- Used by: Dashboards, uploaded PNG graphs to `ftp://af991.netcup.net/freifunk/json/graphs/`

**Tunneldigger (VPN layer):**
- Purpose: L2TP-over-UDP VPN broker/client that creates `l2tpethX` tunnel interfaces aggregated into `bat0` by batman-adv
- Location: `tunneldigger/broker/` (Python), `tunneldigger/client/` (C)
- Contains: `broker/src/tunneldigger_broker/` Python package (event loop, L2TP netlink, protocol, traffic control), C client binary
- Depends on: Linux kernel L2TP support, batman-adv
- Used by: All mesh nodes connecting remotely; `bat0` is the result

## Data Flow

**Node Collection Flow:**

1. Gluon mesh nodes broadcast respondd UDP packets on `bat0` (IPv6 multicast)
2. `mcast_join.py` maintains multicast group membership so packets arrive at host
3. Yanic `respond/` collector receives UDP packets, parses JSON payload into `data.ResponseData`
4. `runtime.Nodes.Update()` merges response into in-memory node map, keyed by node ID
5. Background worker in `runtime.Nodes` calls `expire()` and `save()` every 30 seconds
6. `save()` writes `state.json` (full node cache) to disk
7. Output plugins (`output/all`) write format-specific JSON files to data directory every save interval
8. cron (`*/5 * * * *`) runs upload script, which iterates `data/*.json` and uploads each via `curl --ftp-ssl` to `ftp://af991.netcup.net/freifunk/json/`

**Stats/InfluxDB Flow:**

1. Yanic `database/influxdb` connection writes per-node metrics to InfluxDB on every collection cycle
2. Grafana reads InfluxDB (provisioned datasource at `localhost:8086`, database `freifunk`)
3. `generate_graphs.py` queries InfluxDB for 7-day history per node, renders matplotlib PNG charts
4. PNGs uploaded to `ftp://af991.netcup.net/freifunk/json/graphs/` via `ftplib.FTP_TLS`

**State Management:**
- Node state is held in memory in `runtime.Nodes.List` (map keyed by node ID), protected by `sync.RWMutex`
- Persisted to `state.json` every 30 seconds as atomic rename (write to `.tmp`, then `os.Rename`)
- On restart, `state.json` is loaded, restoring node history without data loss
- Nodes absent for >10 minutes are marked offline; nodes absent for >30 days are pruned

## Key Abstractions

**`runtime.Nodes`:**
- Purpose: Central in-memory database of all known mesh nodes
- Examples: `yanic/runtime/nodes.go`, `yanic/runtime/node.go`
- Pattern: Struct with embedded `sync.RWMutex`, goroutine-based background worker for periodic save/expire

**`data.ResponseData`:**
- Purpose: Typed representation of a respondd UDP response (nodeinfo, statistics, neighbours)
- Examples: `yanic/data/` package
- Pattern: Struct hierarchy matching the JSON schema sent by Gluon firmware

**`output.Output` interface:**
- Purpose: Pluggable output format (meshviewer, geojson, nodelist, etc.)
- Examples: `yanic/output/all/`, `yanic/output/meshviewer/`, `yanic/output/geojson/`
- Pattern: Each subdirectory registers itself; `output/all` aggregates and coordinates lifecycle

**`database.Connection` interface:**
- Purpose: Pluggable time-series backend (InfluxDB v1, InfluxDB v2, Graphite, logging)
- Examples: `yanic/database/influxdb/`, `yanic/database/influxdb2/`, `yanic/database/graphite/`
- Pattern: Same aggregator pattern as outputs via `database/all`

## Entry Points

**Yanic binary:**
- Location: `yanic/main.go` → `yanic/cmd/serve.go`
- Triggers: `yanic serve --config /path/to/yanic.toml` (via systemd or Docker ENTRYPOINT)
- Responsibilities: Parse config, start database connections, initialize node cache, start output writers, start respondd collector, serve optional HTTP, wait for SIGINT/SIGTERM

**Upload cron:**
- Location: `upload_mesh.sh` (local), `docker/upload.sh` (Docker deployment)
- Triggers: cron `*/5 * * * *`
- Responsibilities: Iterate JSON files in data directory, upload each via FTP-TLS to Netcup

**Multicast keeper:**
- Location: `yanicmap/mcast_join.py`, `docker/mcast_join.py`
- Triggers: Systemd user service or Docker container (`mcast-join`)
- Responsibilities: Join IPv6 multicast groups on `bat0`, keep sockets open to maintain kernel membership

**Docker Compose (collector stack):**
- Location: `docker/docker-compose.yml`
- Services: `yanic` (Go collector), `mcast-join` (Python multicast keeper)

**Docker Compose (stats stack):**
- Location: `docker/docker-compose.stats.yml`
- Services: `grafana`, `graph-generator` (matplotlib PNG exporter, cron profile)

**Deployment script:**
- Location: `docker/deploy_to_ffcollector.sh`
- Triggers: Manual execution from `openclaw` machine
- Responsibilities: SCP files to `marcus@ffcollector`, run migration script

## Error Handling

**Strategy:** Panic on fatal startup errors; log and continue on runtime errors

**Patterns:**
- Yanic uses `log.WithError(err).Panic(...)` for unrecoverable startup failures (DB connect, output init)
- File saves use atomic rename pattern to prevent corrupt partial writes
- Upload scripts use curl exit code checks; Docker services use `restart: unless-stopped`
- `generate_graphs.py` catches per-file FTP errors and counts them, does not abort

## Cross-Cutting Concerns

**Logging:** Yanic uses `github.com/bdlm/log` with level-based routing (panic/fatal/error → stderr, others → stdout); Docker services log to journald with custom tags

**Validation:** Yanic filters nodes via pluggable filters (`output/filter/`) — blocklist, area, site, has-location, no-owner; configuration validated at startup via TOML parsing

**Authentication:** No application-layer auth; FTP credentials are hardcoded in shell scripts and `generate_graphs.py` (plaintext — see CONCERNS.md)

---

*Architecture analysis: 2026-04-15*
