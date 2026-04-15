# Technology Stack

**Analysis Date:** 2026-04-15

## Languages

**Primary:**
- Go 1.24 - Yanic node info collector (`yanic/`)
- Python 3 - Multicast keepalive, graph generation, tunneldigger broker (`yanicmap/mcast_join.py`, `docker/generate_graphs.py`, `docker/mcast_join.py`, `tunneldigger/`)
- Bash - Deployment, upload, migration scripts (`upload_mesh.sh`, `docker/upload.sh`, `docker/deploy_to_ffcollector.sh`, `docker/migrate.sh`, `yanicmap/deploy_ffcollector.sh`)

**Secondary:**
- TOML - Yanic configuration (`yanicmap/yanic.toml`, `docker/yanic.toml`)

## Runtime

**Environment:**
- Linux (systemd-based, Ubuntu/Debian)
- Userspace systemd services for local mode (`yanicmap/yanic.service`)
- Docker + Docker Compose for server deployment (`docker/docker-compose.yml`, `docker/docker-compose.stats.yml`)

**Package Manager:**
- Go modules (`yanic/go.mod`, `yanic/go.sum`)
- pip / Python venv for tunneldigger broker (`tunneldigger/venv/`)
- npm (dev-only, semantic-release tooling) (`yanic/package.json`, `yanic/package-lock.json`)
- Lockfile: `yanic/go.sum` present; `yanic/package-lock.json` present

## Frameworks

**Core:**
- Yanic (FreifunkBremen/yanic) - Freifunk mesh node data collector, built from source via Go
- Tunneldigger Broker 0.4.1-dev1 - L2TP VPN broker for batman-adv mesh (`tunneldigger/broker/`)
- Cobra v1.9.1 - CLI framework for yanic command dispatch (`yanic/cmd/`)

**Visualization / Stats:**
- Grafana 11.6.0 - Dashboard visualization via Docker (`docker/docker-compose.stats.yml`)
- matplotlib (Python) - PNG graph generation from InfluxDB data (`docker/generate_graphs.py`)

**Build/Dev:**
- Docker multi-stage build (Go 1.24-alpine → alpine:3.19) (`docker/Dockerfile`)
- Containerfile (Debian bookworm-slim, includes rrdtool) (`yanic/Containerfile`)
- Makefile (`yanic/Makefile`)
- semantic-release (npm dev dep, for yanic upstream CI) (`yanic/package.json`)
- mkdocs (docs site) (`yanic/mkdocs.yml`)

## Key Dependencies

**Critical (Go):**
- `github.com/BurntSushi/toml v1.5.0` - Configuration file parsing
- `github.com/influxdata/influxdb-client-go/v2 v2.14.0` - InfluxDB v2 writes
- `github.com/influxdata/influxdb1-client` - InfluxDB v1 writes
- `github.com/fgrosse/graphigo` - Graphite metrics output
- `github.com/paulmach/go.geojson v1.5.0` - GeoJSON output format
- `github.com/spf13/cobra v1.9.1` - CLI command structure
- `github.com/bdlm/log v0.1.20` - Structured logging
- `github.com/tidwall/gjson v1.18.0` - JSON path queries
- `golang.org/x/sys v0.33.0` - Linux system calls

**Critical (Python):**
- `influxdb` (InfluxDB v1 Python client) - Used in `docker/generate_graphs.py`
- `matplotlib` - Chart PNG generation in `docker/generate_graphs.py`
- `setuptools` - Tunneldigger broker packaging (`tunneldigger/broker/setup.py`)

## Configuration

**Environment:**
- No `.env` files in use; credentials are hardcoded in upload scripts (see CONCERNS)
- Yanic configured via TOML: `yanicmap/yanic.toml` (local), `docker/yanic.toml` (Docker)
- Grafana configured via provisioning YAML: `docker/grafana-provisioning/datasources/influxdb.yaml`, `docker/grafana-provisioning/dashboards/dashboard.yaml`

**Build:**
- `yanic/go.mod` / `yanic/go.sum` - Go module manifest
- `docker/Dockerfile` - Docker image for yanic + Python runtime
- `docker/docker-compose.yml` - yanic + mcast-join services
- `docker/docker-compose.stats.yml` - grafana + graph-generator services
- `yanic/Containerfile` / `yanic/Containerfile.bak` - Upstream container builds

## Platform Requirements

**Development:**
- Go 1.24+
- Python 3.11+ (for mcast_join.py, generate_graphs.py)
- Linux with batman-adv kernel module (`bat0` interface)
- Docker + Docker Compose plugin (for server deployment)

**Production:**
- Two Linux hosts: `openclaw` (local dev/run), `ffcollector` (marcus@ffcollector, server)
- batman-adv + L2TP (Tunneldigger) for mesh VPN connectivity
- InfluxDB v1 running as system service on `ffcollector` at `localhost:8086`
- FTP-capable Netcup webhosting account for JSON/PNG upload

---

*Stack analysis: 2026-04-15*
