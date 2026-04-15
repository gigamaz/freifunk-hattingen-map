# Coding Conventions

**Analysis Date:** 2026-04-15

## Languages and Their Conventions

This codebase mixes three languages across three sub-projects:

- **Go** (`yanic/`) — primary application logic
- **Python** (`tunneldigger/broker/`, `docker/`) — broker daemon and utility scripts
- **Shell/Bash** (`tunneldigger/broker/scripts/`, `tunneldigger/tests/`) — lifecycle hooks and integration tests
- **C** (`tunneldigger/client/`) — L2TP VPN client

---

## Go Conventions (yanic/)

### Naming Patterns

**Files:**
- Snake_case for multi-word files: `nodes_test.go`, `statistics_airtime.go`, `output_test.go`
- Single-word names where possible: `nodes.go`, `filter.go`, `output.go`
- Test files colocated: `nodes.go` → `nodes_test.go`

**Functions and Methods:**
- PascalCase for exported: `NewNodes`, `SaveJSON`, `InsertNode`, `BuildNodesV1`
- camelCase for unexported: `readIfaces`, `updateIface`, `make_chart` (Python)
- Constructor pattern: `New<Type>()` — e.g., `NewNodes`, `NewCollector`

**Types:**
- PascalCase structs: `Nodes`, `Collector`, `Config`, `TunnelManager`
- Interfaces named by capability: `Filter`, `Output`, `Connection`
- Type aliases for config: `type Config map[string]interface{}`

**Variables:**
- camelCase: `nodeID`, `ifaceToNodeID`, `offlineAfter`
- Short names in tight scopes: `f`, `n`, `v`, `ok`
- Descriptive names for exported fields: `StatePath`, `SaveInterval`, `PruneAfter`

**Constants:**
- Not defined in Go files reviewed; protocol constants in Python use ALL_CAPS

### Package Organization

- One package per directory
- Package name matches directory name: `package meshviewer`, `package influxdb`, `package filter`
- Internal test package uses same package name (not `_test` suffix): `package meshviewer` in `output_test.go`
- Sub-packages with `internal.go` and `main.go` for registration: `yanic/database/all/`, `yanic/output/all/`

### Import Organization

**Order:**
1. Standard library
2. Third-party packages (`github.com/bdlm/log`, `github.com/stretchr/testify/assert`)
3. Internal packages (`github.com/FreifunkBremen/yanic/...`)

Example from `yanic/runtime/nodes.go`:
```go
import (
    "encoding/json"
    "os"
    "sync"
    "time"

    "github.com/bdlm/log"

    "github.com/FreifunkBremen/yanic/data"
    "github.com/FreifunkBremen/yanic/lib/jsontime"
)
```

### Registration Pattern

Filters and outputs use a `func init()` + `Register()` pattern for self-registration:

```go
// yanic/output/filter/inarea/inarea.go
func init() {
    filter.Register("in_area", build)
}

func build(config interface{}) (filter.Filter, error) { ... }
```

```go
// yanic/output/meshviewer/output.go
func init() {
    output.RegisterAdapter("meshviewer", Register)
}
```

### Error Handling

**Pattern:** Return `(result, error)` tuples from factory/constructor functions.

```go
// yanic/output/meshviewer/output.go
func Register(configuration map[string]interface{}) (output.Output, error) {
    ...
    if builder == nil {
        return nil, fmt.Errorf("invalid nodes version: %d", config.Version())
    }
    return &Output{...}, nil
}
```

**Panic for unrecoverable errors** (e.g., file I/O during save):
```go
// yanic/runtime/nodes.go
if err != nil {
    log.Panic(err)
}
```

**Logging errors instead of returning** for non-critical failures:
```go
log.WithError(err).Error("failed to unmarshal nodes")
```

**Wrapping errors** using `github.com/pkg/errors`:
```go
errs = append(errs, errors.Wrapf(err, "unable to initialize filter %s", name))
```

### Logging

**Framework:** `github.com/bdlm/log` (not standard `log` package)
- Exception: `yanic/database/influxdb/node.go` uses stdlib `log` — inconsistency

**Patterns:**
```go
log.Infof("loaded %d nodes", len(nodes.List))
log.Warnf("override %s from %s to %s on %s", class, oldValue, value, addr)
log.WithError(err).Error("failed to close after save")
log.Panic(err)
```

### Comments

- Exported functions and types have doc comments: `// Nodes struct: cache DB of Node's structs`
- Block comments explain non-obvious behavior inline
- Short single-line comments explain intent: `// Locking foo`
- TODO comments in German or English: `// TODO bessere Fehlerbehandlung!`, `// TODO maybe change LLDP for link quality`

### Concurrency Pattern

`sync.RWMutex` embedded in struct for node-cache thread safety:
```go
type Nodes struct {
    List map[string]*Node `json:"nodes"`
    ...
    sync.RWMutex
}
```

Callers use `nodes.Lock()` / `nodes.RLock()` with `defer nodes.Unlock()`.

---

## Python Conventions (tunneldigger/broker/)

### Naming Patterns

**Files:** snake_case: `broker.py`, `event_loop.py`, `traffic_control.py`

**Classes:** PascalCase: `TunnelManager`, `Broker`, `HookManager`, `HookProcess`

**Functions/Methods:** snake_case: `create_tunnel`, `run_hook`, `report_usage`, `destroy_tunnel`

**Constants:** ALL_CAPS: `CONTROL_TYPE_KEEPALIVE`, `ERROR_REASON_SHUTDOWN`, `FEATURE_UNIQUE_SESSION_ID`

**Variables:** snake_case: `tunnel_id`, `hook_manager`, `last_tunnel_created`

**Module-level loggers:**
```python
logger = logging.getLogger("tunneldigger.broker")
```
Consistent naming pattern: `"tunneldigger.<module>"`.

### Class Design

Classes use `object` base class (Python 2 legacy style retained in Python 3 code):
```python
class TunnelManager(object):
class HookProcess(object):
```

Multiple inheritance via mixins:
```python
class Broker(protocol.HandshakeProtocolMixin, network.Pollable):
class Tunnel(protocol.HandshakeProtocolMixin, network.Pollable):
```

### Docstrings

All public methods have docstrings with `:param name:` Sphinx-style parameter documentation:
```python
def create_tunnel(self, broker, address, uuid, remote_tunnel_id, client_features):
    """
    Creates a new tunnel.

    :param broker: Broker that received the tunnel request
    :param address: Remote tunnel endpoint address (host, port) tuple
    ...
    :return: True if a tunnel has been created, False otherwise
    """
```

### Error Handling

**Bare except clauses** used for truly unexpected exceptions at top-level operations:
```python
except:
    self.tunnel_ids.add(tunnel_id)
    logger.error("Unhandled exception while creating tunnel %d:" % tunnel_id)
    logger.error(traceback.format_exc())
    return False
```

**Specific exception handling preferred** when exception type is known:
```python
except l2tp.L2TPTunnelExists as e:
    logger.warning("Tunnel identifier %d already exists." % e.tunnel_id)
    return False
except KeyboardInterrupt:
    raise
```

### String Formatting

Mixed usage of old (`%`) and new (`format`) styles:
```python
# Old style (common)
logger.info("Creating tunnel %s with id %d.", tunnel_str, tunnel_id)
# New style (also present)
logger.info("{}: Closing after {} seconds".format(self.name, ...))
```

---

## Python Conventions (docker/generate_graphs.py)

Standalone script, less structured. Uses f-strings (Python 3.6+):
```python
path = os.path.join(OUTPUT_DIR, f"{node_id}_{suffix}.png")
print(f"{len(nodes)} Knoten gefunden.")
```

Comments in German (operator-owned file):
```python
# Alle Knoten mit Hostname holen
# Verzeichnis anlegen falls nicht vorhanden
```

---

## Shell Conventions (tunneldigger/broker/scripts/, tunneldigger/tests/)

- Scripts sourced via `. bridge_functions.sh` for shared utility functions
- `set -e` not consistently used
- Script arguments accessed positionally: `$1`, `$2`
- No formal error handling beyond exit codes

---

## Module Design

**Go exports via `output.RegisterAdapter` / `filter.Register`:** Sub-packages register themselves using `init()`, making the top-level `all` packages just import side-effects:

- `yanic/output/all/output.go` imports all output implementations
- `yanic/database/all/connection.go` imports all database drivers

**Barrel pattern for side-effect imports** is the intended extensibility mechanism.

---

*Convention analysis: 2026-04-15*
