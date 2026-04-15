# Codebase Concerns

**Analysis Date:** 2026-04-15

## Tech Debt

**Hardcoded FTP credentials in plaintext shell scripts:**
- Issue: FTP username, password, and hostname are hardcoded directly in shell scripts and Python source files
- Files: `/home/openclaw/freifunk/upload_mesh.sh`, `/home/openclaw/freifunk/docker/upload.sh`, `/home/openclaw/freifunk/docker/generate_graphs.py`, `/home/openclaw/freifunk/docker/rollback_stats.sh`
- Credentials present: `hosting102099` / `kalisto334` on `af991.netcup.net`
- Impact: Any person with read access to the repo or these files obtains live FTP credentials. Credentials are committed to git history.
- Fix approach: Move credentials to a `.env` file or shell-sourced secrets file (e.g. `~/.ffhat_secrets`). Reference via `$FTP_USER`, `$FTP_PASS`. Add the secrets file to `.gitignore`.

**Duplicate and divergent yanic configurations:**
- Issue: Three separate `yanic.toml` files exist with different absolute paths and slightly different content, but no clear "which one is live" marker
- Files: `/home/openclaw/freifunk/yanicmap/yanic.toml` (openclaw paths, no InfluxDB), `/home/openclaw/freifunk/docker/yanic.toml` (Docker `/data/` paths, InfluxDB enabled pointing to `localhost:8086`), `/home/openclaw/freifunk/yanicmap/deploy_ffcollector.sh` (embeds a third inline config for `/home/marcus/…` paths)
- Impact: Config drift — changes made to one config are silently not applied to others. The active config is unclear from the repository alone.
- Fix approach: Maintain a single canonical `yanic.toml.template` with `${DATA_DIR}` placeholders, rendered at deploy time. Remove inline embedded config from `deploy_ffcollector.sh`.

**Hardcoded IP address in bridge_functions.sh:**
- Issue: Bridge IP `10.254.0.2/16` is hardcoded with a TODO comment acknowledging it should not be
- Files: `/home/openclaw/freifunk/tunneldigger/broker/scripts/bridge_functions.sh` (line 15–16)
- Impact: Cannot reuse this script for a different subnet without editing source. Breaks if the mesh uses a different address range.
- Fix approach: Accept bridge IP as a parameter or read from environment variable.

**Hardcoded policy routing table name in bridge_functions.sh:**
- Issue: Routing table name `mesh` is hardcoded with a TODO comment
- Files: `/home/openclaw/freifunk/tunneldigger/broker/scripts/bridge_functions.sh` (line 18)
- Impact: Assumes `mesh` exists in `/etc/iproute2/rt_tables`. Silent failure if missing.
- Fix approach: Parameterize or validate existence at startup.

**Tunneldigger broker version stuck at `0.4.1-dev1`:**
- Issue: `setup.py` declares version `0.4.1-dev1`, indicating a pre-release development version is in use
- Files: `/home/openclaw/freifunk/tunneldigger/broker/setup.py`
- Impact: Unclear which upstream commit is actually deployed; difficult to know if security fixes are included.
- Fix approach: Pin to a tagged upstream release, or record the git commit SHA explicitly in documentation.

**Docker image builds yanic from latest upstream `main` branch at build time:**
- Issue: `Dockerfile` runs `git clone --depth=1 https://github.com/FreifunkBremen/yanic.git` with no version pin
- Files: `/home/openclaw/freifunk/docker/Dockerfile`
- Impact: Rebuilding the image on a different day can produce a different binary. Breaking upstream changes are silently adopted.
- Fix approach: Pin to a specific git tag or commit SHA: `git clone --depth=1 --branch v0.6.0 ...` or `git checkout <sha>`.

**Grafana admin password hardcoded in docker-compose:**
- Issue: `GF_SECURITY_ADMIN_PASSWORD: "freifunk"` is a trivially guessable default password set in plain YAML
- Files: `/home/openclaw/freifunk/docker/docker-compose.stats.yml`
- Impact: Anyone who can reach port 3000 on ffcollector can log into Grafana with admin rights.
- Fix approach: Set via environment variable or Docker secret; remove from committed file.

**`upload_mesh.sh` uploads all files in data dir without filtering:**
- Issue: The loop `for FILE in "$LOCAL_DIR"/*` uploads every file including non-JSON artifacts (e.g. temporary files, partial writes)
- Files: `/home/openclaw/freifunk/upload_mesh.sh`
- Impact: Partial or corrupt JSON files can be published to the live webserver.
- Fix approach: Filter explicitly: `for FILE in "$LOCAL_DIR"/*.json "$LOCAL_DIR"/*.geojson` (as done correctly in `docker/upload.sh`).

**`upload_cron` references a path that may not exist on the actual host:**
- Issue: `/home/openclaw/freifunk/yanicmap/upload.cron` documents a cron path of `/home/openclaw/freifunk/upload_mesh.sh`, but this is the development machine path and will not be valid on `ffcollector` (where the path is `/home/marcus/...`)
- Files: `/home/openclaw/freifunk/yanicmap/upload.cron`
- Impact: Installing the cron as-is on ffcollector silently does nothing (wrong path).
- Fix approach: Document the correct per-host path clearly, or generate the cron entry during deploy.

---

## Known Bugs

**`HookManager.close()` references undefined attribute `self.sigchld_fd`:**
- Symptoms: `AttributeError: 'HookManager' object has no attribute 'sigchld_fd'` if `close()` is ever called
- Files: `/home/openclaw/freifunk/tunneldigger/broker/src/tunneldigger_broker/hooks.py` (line 164)
- Trigger: The `pipe_r` file descriptor is stored only as a local variable in `__init__`; `close()` tries to close `self.sigchld_fd` which is never assigned
- Workaround: Clean shutdown never explicitly calls `HookManager.close()` currently; the fd leaks on exit

**`TunnelManager.close()` logs wrong type in warning:**
- Symptoms: `TypeError` in warning message when all tunnels are exhausted
- Files: `/home/openclaw/freifunk/tunneldigger/broker/src/tunneldigger_broker/broker.py` (line 127)
- Trigger: `logger.warning("No more tunnel IDs available -- %d active tunnels", self.tunnels)` passes the dict object instead of `len(self.tunnels)`
- Workaround: The warning message is malformed but does not crash; the rejection logic still works

**`generate_graphs.py` does not close InfluxDB client connection:**
- Symptoms: Connection handles accumulate if the script is invoked frequently (every 5 minutes via cron)
- Files: `/home/openclaw/freifunk/docker/generate_graphs.py` (line 58 `generate_all()`)
- Trigger: No `client.close()` call after querying; Python garbage collection eventually reclaims but is not guaranteed
- Workaround: Script is short-lived per cron invocation, so process exit reclaims the connection

---

## Security Considerations

**FTP TLS certificate verification disabled everywhere:**
- Risk: All FTP uploads use `--insecure` (curl) or `context.verify_mode = ssl.CERT_NONE` (Python), allowing man-in-the-middle attacks on data in transit and credential interception
- Files: `/home/openclaw/freifunk/upload_mesh.sh`, `/home/openclaw/freifunk/docker/upload.sh`, `/home/openclaw/freifunk/docker/generate_graphs.py`, `/home/openclaw/freifunk/docker/rollback_stats.sh`
- Current mitigation: None
- Recommendations: Use a properly signed TLS certificate on the FTP host, remove `--insecure` / `CERT_NONE`. If certificate is self-signed, pin it explicitly rather than disabling all verification.

**Tunneldigger broker requires running as root:**
- Risk: The entire broker process runs as UID 0; any code execution vulnerability in the broker or its hooks yields full root access
- Files: `/home/openclaw/freifunk/tunneldigger/broker/src/tunneldigger_broker/main.py` (line 11–13)
- Current mitigation: Rate limiting (global + per-IP) reduces attack surface
- Recommendations: Investigate capability-based approach; at minimum run in a namespace/container with minimal capabilities (CAP_NET_ADMIN)

**Grafana exposed on `network_mode: host` with weak password:**
- Risk: Grafana listens on all interfaces on port 3000 with password `freifunk`; if ffcollector is internet-accessible, Grafana admin is publicly reachable
- Files: `/home/openclaw/freifunk/docker/docker-compose.stats.yml`
- Current mitigation: `GF_USERS_ALLOW_SIGN_UP: "false"` is set
- Recommendations: Bind Grafana to `127.0.0.1` only (use `GF_SERVER_HTTP_ADDR`), set a strong password, put behind nginx with auth if public access is needed

**InfluxDB accessible on `localhost:8086` with no authentication:**
- Risk: `yanic.toml` configures InfluxDB with empty username/password; any process on ffcollector can write or delete data
- Files: `/home/openclaw/freifunk/docker/yanic.toml` (lines 68–70)
- Current mitigation: Relies on network isolation (localhost only)
- Recommendations: Enable InfluxDB authentication and configure credentials via environment variables

**`broker.connection-rate-limit.sh` requires `ipset` pre-configuration:**
- Risk: The script assumes an `ipset` named `tunneldigger_blocked` and a matching iptables rule already exist; if not, `ipset add` silently fails with exit 1 (which `set -e` would abort on, but the script has no `set -e`)
- Files: `/home/openclaw/freifunk/tunneldigger/broker/scripts/broker.connection-rate-limit.sh`
- Current mitigation: Script is not enabled by default (empty hook in config)
- Recommendations: Add existence check for ipset before calling `ipset add`; document required pre-setup

---

## Performance Bottlenecks

**Graph generation queries all nodes individually per metric:**
- Problem: `generate_graphs.py` issues one InfluxDB query per node per chart type (3 charts × N nodes = 3N queries per cron run)
- Files: `/home/openclaw/freifunk/docker/generate_graphs.py` (lines 79–98)
- Cause: No batch query; each `client.query()` is a separate HTTP round-trip
- Improvement path: Use a single GROUP BY nodeid query per metric to fetch all nodes in one round-trip

**Yanic state.json written every 30 seconds to the same path:**
- Problem: Concurrent read of JSON output files by the upload script while yanic is mid-write can result in truncated or partial JSON being uploaded
- Files: `/home/openclaw/freifunk/yanicmap/yanic.toml` (`save_interval = "30s"`), `/home/openclaw/freifunk/upload_mesh.sh`
- Cause: No atomic write/rename pattern; no coordination between yanic write cycle and upload cron
- Improvement path: Yanic itself does atomic writes internally (write to temp then rename); the concern is the 5-minute upload cron potentially uploading mid-write. Low actual risk but worth noting.

---

## Fragile Areas

**`mcast_join.py` — interface name `bat0` is hardcoded:**
- Files: `/home/openclaw/freifunk/docker/mcast_join.py` (line 8), `/home/openclaw/freifunk/yanicmap/deploy_ffcollector.sh` (line 105)
- Why fragile: If the batman-adv interface is named differently (e.g., `bat1`), the script crashes at startup with `OSError: [Errno 19] No such device`
- Safe modification: Accept interface name as a command-line argument or environment variable
- Test coverage: None

**Docker yanic container uses `network_mode: host`:**
- Files: `/home/openclaw/freifunk/docker/docker-compose.yml`
- Why fragile: Host networking means the container directly uses the host's `bat0` interface; if the host interface is down or renamed at container start, yanic fails with no clear error. Container restart policy (`unless-stopped`) will loop-restart indefinitely.
- Safe modification: Add a health check or startup dependency on `bat0` being available
- Test coverage: None

**`migrate.sh` uses `set -e` but `docker compose build --no-cache` can fail silently if git clone inside Dockerfile fails:**
- Files: `/home/openclaw/freifunk/docker/migrate.sh`
- Why fragile: Network unavailability during `docker compose build` causes failure with a potentially confusing error; `set -e` will abort but old services will already have been stopped (step 1) with no rollback path
- Safe modification: Check Docker build success before stopping old services, or add a rollback step

**`bridge_functions.sh` uses `brctl` (deprecated) instead of `ip link`:**
- Files: `/home/openclaw/freifunk/tunneldigger/broker/scripts/bridge_functions.sh`, `/home/openclaw/freifunk/tunneldigger/broker/scripts/session.up.sh`, `/home/openclaw/freifunk/tunneldigger/broker/scripts/session.down.sh`
- Why fragile: `brctl` is part of the `bridge-utils` package which is not installed by default on modern distros (Debian 12+, Ubuntu 22.04+). If the package is not present, all tunnel up/down hooks fail silently.
- Safe modification: Replace `brctl addbr` / `brctl addif` / `brctl delif` with `ip link add type bridge` / `ip link set master` / `ip link set nomaster`
- Test coverage: None

---

## Scaling Limits

**Tunneldigger broker max_tunnels:**
- Current capacity: 256 tunnels (example config default)
- Limit: Set by `max_tunnels` in `l2tp_broker.cfg`; the comment notes "cheap VPS: 256 usually max"
- Scaling path: Increase `max_tunnels` on physical hardware; run multiple broker instances on different ports (already supported — ports `53,123,8942`)

**InfluxDB v1 (legacy):**
- Current capacity: Single-node InfluxDB 1.x running as system service on ffcollector
- Limit: InfluxDB 1.x is EOL; no clustering support; single point of failure for stats
- Scaling path: Migrate to InfluxDB 2.x or Victoria Metrics; the Grafana datasource (`influxdb.yaml`) uses InfluxDB v1 Flux-incompatible config

---

## Dependencies at Risk

**`influxdb` Python client (v1):**
- Risk: The `influxdb` package (InfluxDB 1.x Python client) is unmaintained; InfluxDB 1.x itself is EOL
- Impact: `generate_graphs.py` depends on it; security vulnerabilities in the client will not be patched upstream
- Migration plan: If moving to InfluxDB 2.x, switch to `influxdb-client` package and update query syntax to Flux

**`brctl` / `bridge-utils`:**
- Risk: Package is deprecated and removed from default installs in modern distros
- Impact: All tunneldigger session hook scripts (`session.up.sh`, `session.down.sh`) fail if `bridge-utils` is not installed
- Migration plan: Replace with `iproute2` bridge commands (see Fragile Areas section)

**Python 3.11 in `mcast-join` Docker container:**
- Risk: `image: python:3.11-alpine` — no pinned digest; `3.11` tag is mutable and will silently update to a new patch release on next pull
- Impact: Low risk for this simple script, but inconsistent with pinned practices
- Migration plan: Pin to a specific digest: `python:3.11-alpine@sha256:...`

---

## Missing Critical Features

**No monitoring or alerting for the upload pipeline:**
- Problem: The FTP upload cron logs to `upload.log` but there is no alert if uploads fail repeatedly. A broken FTP connection goes undetected until someone manually checks the meshviewer map.
- Blocks: Timely detection of outages in public node data availability

**No backup or redundancy for `state.json`:**
- Problem: `state.json` is the only persistent node cache. It is not backed up. If the file is corrupted or deleted, yanic loses all historical node-online/offline state and must rediscover all nodes from scratch.
- Files: `/home/openclaw/freifunk/yanicmap/yanic.toml` (`state_path`), `/home/openclaw/freifunk/docker/yanic.toml`
- Blocks: Recovery from disk failure or accidental deletion without data loss

**No health check endpoint for yanic:**
- Problem: The yanic webserver is disabled (`enable = false`) in all configs. There is no way to programmatically verify yanic is running and collecting data without inspecting `state.json` manually.
- Blocks: Automated monitoring integration

---

## Test Coverage Gaps

**No tests for any custom scripts:**
- What's not tested: `upload_mesh.sh`, `docker/upload.sh`, `generate_graphs.py`, `mcast_join.py`, all `deploy_*.sh` and `migrate.sh` scripts
- Files: All files under `/home/openclaw/freifunk/docker/` and `/home/openclaw/freifunk/yanicmap/`
- Risk: Silent regressions in upload logic, credential handling, or file path handling go undetected
- Priority: Medium

**No tests for tunneldigger hook scripts:**
- What's not tested: `session.up.sh`, `session.down.sh`, `bridge_functions.sh`, `broker.connection-rate-limit.sh`
- Files: `/home/openclaw/freifunk/tunneldigger/broker/scripts/`
- Risk: Bridge setup errors would only manifest when a node connects, making debugging difficult
- Priority: High (these are on the critical path for every new VPN session)

**Yanic graph test marked as incomplete:**
- What's not tested: Graph building logic beyond a single basic test
- Files: `/home/openclaw/freifunk/yanic/output/meshviewer/graph_test.go` (line 31: `// TODO more tests required`)
- Risk: Graph edge/link calculation bugs could silently produce incorrect meshviewer topology
- Priority: Medium

---

*Concerns audit: 2026-04-15*
