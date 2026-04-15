# Codebase Structure

**Analysis Date:** 2026-04-15

## Directory Layout

```
freifunk/                         # Root — Freifunk Hattingen (ffhat) infrastructure
├── upload_mesh.sh                # Cron-triggered FTP upload script (local deployment)
├── ffmap-backup.tar.gz           # Archived legacy ffmap data
│
├── docker/                       # Docker-based deployment for ffcollector server
│   ├── docker-compose.yml        # Collector stack: yanic + mcast-join
│   ├── docker-compose.stats.yml  # Stats stack: grafana + graph-generator
│   ├── Dockerfile                # Builds Yanic binary from source (golang:1.24-alpine)
│   ├── Dockerfile.graphs         # Builds matplotlib graph-generator image
│   ├── yanic.toml                # Yanic config for Docker deployment (paths: /data/)
│   ├── mcast_join.py             # IPv6 multicast group keeper (Docker container)
│   ├── generate_graphs.py        # InfluxDB → matplotlib PNG → FTP upload
│   ├── upload.sh                 # FTP upload script for Docker deployment
│   ├── deploy_to_ffcollector.sh  # SCP + remote setup script (run from openclaw)
│   ├── migrate.sh                # Migrate old systemd setup → Docker on ffcollector
│   ├── rollback_stats.sh         # Undo stats stack deployment
│   └── grafana-provisioning/     # Auto-provisioning for Grafana
│       ├── datasources/
│       │   └── influxdb.yaml     # InfluxDB datasource (localhost:8086, db: freifunk)
│       └── dashboards/
│           └── dashboard.yaml    # Dashboard provider pointing at provisioning dir
│
├── tunneldigger/                 # Submodule: L2TP VPN broker + C client (upstream)
│   ├── broker/
│   │   └── src/tunneldigger_broker/   # Python broker package
│   │       ├── main.py           # Broker entry point
│   │       ├── broker.py         # Core broker logic
│   │       ├── tunnel.py         # L2TP tunnel management
│   │       ├── l2tp.py           # L2TP netlink interface
│   │       ├── protocol.py       # Client-broker protocol
│   │       ├── network.py        # Network utilities
│   │       ├── hooks.py          # Event hooks
│   │       ├── traffic_control.py# tc/bandwidth shaping
│   │       └── eventloop.py      # Async event loop
│   ├── client/
│   │   ├── l2tp_client.c         # C client source
│   │   └── build/                # CMake build output (generated, not committed)
│   ├── tests/                    # Broker tests
│   └── docs/                     # Tunneldigger documentation
│
├── yanic/                        # Submodule: Yanic node collector (upstream Go)
│   ├── main.go                   # Binary entry point
│   ├── go.mod / go.sum           # Go module definition
│   ├── cmd/                      # CLI commands (cobra)
│   │   ├── root.go               # Root command, config loading
│   │   ├── serve.go              # `yanic serve` — main daemon command
│   │   ├── import.go             # `yanic import` — one-shot data import
│   │   └── version.go            # `yanic version`
│   ├── data/                     # Typed data structures (Gluon respondd schema)
│   │   ├── node.go               # Node, Nodeinfo, Statistics, Neighbours structs
│   │   └── testdata/             # JSON fixtures for tests
│   ├── respond/                  # UDP respondd collector
│   │   └── query.go              # Multicast query sender + response parser
│   ├── runtime/                  # In-memory node cache
│   │   ├── nodes.go              # Nodes map, Update, expire, save, load
│   │   ├── node.go               # Single Node struct
│   │   ├── nodes_config.go       # NodesConfig (TOML binding)
│   │   └── stats.go              # Aggregate statistics
│   ├── output/                   # Output format plugins
│   │   ├── output.go             # Output interface definition
│   │   ├── all/                  # Aggregator — starts/stops all enabled outputs
│   │   ├── meshviewer/           # Classic nodes.json + graph.json (v2)
│   │   ├── meshviewer-ffrgb/     # Modern meshviewer.json (ffrgb format)
│   │   ├── nodelist/             # nodelist.json (simple list)
│   │   ├── geojson/              # nodes.geojson (GeoJSON)
│   │   ├── raw/                  # raw node JSON
│   │   ├── raw-jsonl/            # JSONL per-node output
│   │   ├── prometheus-sd/        # Prometheus service discovery
│   │   └── filter/               # Node filter plugins
│   │       ├── blocklist/        # Exclude by node ID
│   │       ├── haslocation/      # Exclude nodes without GPS coords
│   │       ├── inarea/           # Limit to geographic bounding box
│   │       ├── noowner/          # Exclude nodes with owner info
│   │       ├── site/             # Filter by site name
│   │       ├── domainassite/     # Treat domain as site
│   │       └── domainappendsite/ # Append domain to site name
│   ├── database/                 # Time-series database plugins
│   │   ├── database.go           # Connection interface
│   │   ├── all/                  # Aggregator
│   │   ├── influxdb/             # InfluxDB v1 client
│   │   ├── influxdb2/            # InfluxDB v2 client
│   │   ├── graphite/             # Graphite/Carbon client
│   │   ├── logging/              # Log-only (debug) backend
│   │   └── respondd/             # Re-publish via respondd
│   ├── webserver/                # Optional built-in HTTP file server
│   ├── lib/                      # Shared utility packages
│   │   ├── duration/             # TOML-parseable duration type
│   │   └── jsontime/             # JSON-serializable time.Time
│   └── rrd/                      # RRD graph support (legacy)
│
└── yanicmap/                     # Local operational data directory
    ├── yanic.toml                # Yanic config for local (non-Docker) deployment
    ├── yanic.service             # Systemd user service unit file
    ├── upload.cron               # Cron snippet: */5 upload_mesh.sh
    ├── mcast_join.py             # IPv6 multicast keeper (local deployment)
    ├── deploy_ffcollector.sh     # Bootstrap script for ffcollector (systemd variant)
    ├── state.json                # Persistent node cache (auto-generated, ~296 KB)
    ├── upload.log                # FTP upload log (auto-generated)
    └── data/                     # Generated JSON outputs (written by Yanic every 30s)
        ├── meshviewer.json       # Modern meshviewer format (ffrgb)
        ├── nodes.json            # Classic nodes format v2
        ├── graph.json            # Mesh topology graph
        ├── nodelist.json         # Simple node list
        └── nodes.geojson         # GeoJSON node locations
```

## Directory Purposes

**`docker/`:**
- Purpose: Complete Docker Compose deployment for `ffcollector` (remote server)
- Contains: Dockerfiles, Compose files, Python scripts, Grafana provisioning configs, operational scripts
- Key files: `docker-compose.yml`, `docker-compose.stats.yml`, `yanic.toml`, `generate_graphs.py`

**`tunneldigger/`:**
- Purpose: L2TP VPN system enabling mesh nodes to connect over internet to create `bat0` interface
- Contains: Python broker (`tunneldigger_broker` package), C client binary, tests, docs
- Key files: `broker/src/tunneldigger_broker/main.py`, `client/l2tp_client.c`

**`yanic/`:**
- Purpose: Go source of the Yanic node collector (upstream project, vendored as submodule)
- Contains: CLI, respondd UDP collector, node runtime cache, output plugins, database plugins
- Key files: `main.go`, `cmd/serve.go`, `runtime/nodes.go`, `data/node.go`

**`yanicmap/`:**
- Purpose: Local deployment working directory — configs, service files, generated data
- Contains: TOML config, systemd service unit, cron snippet, state cache, JSON output files
- Key files: `yanic.toml`, `yanic.service`, `state.json`, `data/*.json`

## Key File Locations

**Entry Points:**
- `yanic/main.go`: Yanic binary entry point
- `yanic/cmd/serve.go`: Daemon startup — initializes all subsystems
- `upload_mesh.sh`: FTP upload trigger (local cron)
- `docker/upload.sh`: FTP upload trigger (Docker cron)

**Configuration:**
- `yanicmap/yanic.toml`: Yanic config for local deployment (state/output paths under `yanicmap/`)
- `docker/yanic.toml`: Yanic config for Docker deployment (paths under `/data/`)
- `yanicmap/yanic.service`: Systemd user service unit
- `yanicmap/upload.cron`: Cron schedule snippet
- `docker/docker-compose.yml`: Collector stack definition
- `docker/docker-compose.stats.yml`: Stats stack definition
- `docker/grafana-provisioning/datasources/influxdb.yaml`: Grafana InfluxDB datasource
- `docker/grafana-provisioning/dashboards/dashboard.yaml`: Grafana dashboard provider

**Core Logic:**
- `yanic/runtime/nodes.go`: Node cache, expiry, persistence
- `yanic/respond/`: UDP respondd collector
- `yanic/output/`: All output format implementations
- `yanic/database/`: All time-series backend implementations
- `docker/generate_graphs.py`: InfluxDB query + matplotlib chart generation
- `docker/mcast_join.py` / `yanicmap/mcast_join.py`: Multicast group keeper

**Generated / Runtime Data:**
- `yanicmap/state.json`: Persistent node cache (~296 KB, auto-updated every 30s)
- `yanicmap/data/*.json`: JSON outputs served to FTP
- `yanicmap/upload.log`: Upload history log

## Naming Conventions

**Files:**
- Go source: lowercase with underscores (`nodes_config.go`, `nodes_test.go`)
- Python scripts: lowercase with underscores (`mcast_join.py`, `generate_graphs.py`)
- Shell scripts: lowercase with underscores (`upload_mesh.sh`, `deploy_to_ffcollector.sh`)
- Config files: lowercase (`yanic.toml`, `docker-compose.yml`)
- Docker provisioning: lowercase YAML (`influxdb.yaml`, `dashboard.yaml`)

**Directories:**
- Go packages: lowercase single word (`runtime`, `respond`, `output`, `database`)
- Output plugins: hyphenated lowercase (`meshviewer-ffrgb`, `raw-jsonl`, `prometheus-sd`)
- Filter plugins: single word (`blocklist`, `haslocation`, `inarea`)

**JSON outputs:**
- Standard names consumed by Freifunk tooling: `meshviewer.json`, `nodes.json`, `graph.json`, `nodelist.json`, `nodes.geojson`

## Where to Add New Code

**New output format for Yanic:**
- Implementation: `yanic/output/<format-name>/` (new Go package)
- Register: add import to `yanic/output/all/all.go`

**New database backend for Yanic:**
- Implementation: `yanic/database/<backend-name>/` (new Go package)
- Register: add import to `yanic/database/all/all.go`

**New node filter:**
- Implementation: `yanic/output/filter/<filtername>/` (new Go package)

**New operational script (local deployment):**
- Place in `yanicmap/` if related to local runtime
- Place in `docker/` if related to Docker/ffcollector deployment

**New Grafana dashboard:**
- Place JSON dashboard file in `docker/grafana-provisioning/dashboards/`
- Grafana auto-provisions from that directory

**New Docker service:**
- Add service to `docker/docker-compose.yml` (collector) or `docker/docker-compose.stats.yml` (stats)

## Special Directories

**`tunneldigger/`:**
- Purpose: Upstream submodule (FreifunkBremen/tunneldigger)
- Generated: `client/build/` (CMake output — generated, not committed)
- Committed: `broker/src/`, `client/l2tp_client.c`, `tests/`, `docs/`

**`yanic/`:**
- Purpose: Upstream submodule (FreifunkBremen/yanic)
- Generated: `yanic` binary, test cache
- Committed: full Go source

**`yanicmap/data/`:**
- Purpose: Runtime JSON output directory
- Generated: Yes — Yanic writes every 30 seconds
- Committed: No (runtime data)

**`yanicmap/state.json`:**
- Purpose: Persistent node cache, survives Yanic restarts
- Generated: Yes — written by Yanic
- Committed: No (runtime data, ~296 KB)

**`.planning/codebase/`:**
- Purpose: Architecture and analysis documents for GSD planning tooling
- Generated: By GSD mapper agents
- Committed: Yes

---

*Structure analysis: 2026-04-15*
