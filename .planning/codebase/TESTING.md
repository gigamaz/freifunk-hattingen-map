# Testing Patterns

**Analysis Date:** 2026-04-15

## Test Framework

### Go (yanic/)

**Runner:** Go's built-in `testing` package
- Config: none (uses `go test ./...`)
- Race detection enabled in CI: `go test -race`

**Assertion Library:** `github.com/stretchr/testify v1.10.0`
- Style: `assert := assert.New(t)` then `assert.Equal(...)` — instance-based, not package-level calls

**Run Commands:**
```bash
make test              # runs go test -race -covermode=atomic -coverprofile=coverage.out ./...
make coverage.html     # generates HTML coverage report from coverage.out
go test ./...          # run all tests without coverage
go test -v ./runtime/  # run specific package tests
```

### Python (tunneldigger/)

**Runner:** `nose` (legacy) as seen in `tunneldigger/tests/test_nose.py`
- Uses `setup_module()` / `teardown_module()` functions at module level
- Test classes are plain objects (not `unittest.TestCase`)
- Integration tests require LXC containers — not unit tests

**No unit test framework** detected for the broker Python source (`tunneldigger/broker/src/`). Tests in `tunneldigger/tests/` are integration/system tests.

---

## Test File Organization

### Go

**Location:** Co-located with source files in the same directory and package.

**Naming:** `<source_file>_test.go`

**Structure:**
```
yanic/runtime/
├── nodes.go
├── nodes_test.go        # tests for nodes.go
├── stats.go
├── stats_test.go
└── testdata/            # JSON fixtures
    ├── nodes.json
    └── nodes-broken.json

yanic/data/
├── statistics.go
├── statistics_test.go
└── testdata/
    └── statistics.json

yanic/database/influxdb/
├── database.go
├── database_test.go
├── node.go
└── node_test.go
```

**Package name in tests:** Same as source package (not `_test` suffix):
```go
// yanic/runtime/nodes_test.go
package runtime

// yanic/database/influxdb/database_test.go
package influxdb
```

Exception: `yanic/database/all/internel_test.go` uses `package all_test` for black-box testing.

---

## Test Structure

### Suite Organization

```go
// Standard pattern across all Go test files
func TestFunctionName(t *testing.T) {
    assert := assert.New(t)

    // setup inline (no BeforeEach/AfterEach)
    nodes := &Nodes{
        List:          make(map[string]*Node),
        ifaceToNodeID: make(map[string]string),
        ...
    }

    // act
    nodes.Update("nodeID", &data.ResponseData{...})

    // assert
    assert.Len(nodes.List, 1)
    assert.NotNil(nodes.List["nodeID"])
}
```

**No shared setup helpers** — each test constructs its own minimal fixture inline.

**Multiple scenarios in one test function** (common pattern):
```go
func TestConnect(t *testing.T) {
    assert := assert.New(t)

    // invalid config test
    conn, err := Connect(map[string]interface{}{"address": ""})
    assert.Nil(conn)
    assert.Error(err)

    // valid config test
    conn, err = Connect(map[string]interface{}{"address": "http://localhost", "database": ""})
    assert.Nil(conn)
    assert.Error(err)

    // success case with mock HTTP server
    srv := httptest.NewServer(...)
    defer srv.Close()
    conn, err = Connect(map[string]interface{}{"address": srv.URL, ...})
    assert.NotNil(conn)
    assert.NoError(err)
}
```

---

## Mocking

**No mocking framework detected.** Mocking is done via:

1. **`net/http/httptest`** for HTTP server mocking:
```go
// yanic/database/influxdb/database_test.go
srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusNoContent)
}))
defer srv.Close()
conn, err = Connect(map[string]interface{}{"address": srv.URL, ...})
```

2. **Inline test implementations** of interfaces:
```go
// yanic/output/filter/filter_test.go
type filterBool struct{ bool }

func (f filterBool) Apply(node *runtime.Node) *runtime.Node {
    if f.bool { return node }
    return nil
}

func build(v interface{}) (Filter, error) {
    if config, ok := v.(bool); ok {
        return &filterBool{config}, nil
    }
    return nil, nil
}
```

3. **Direct struct instantiation** (bypassing constructors to avoid side effects):
```go
// yanic/runtime/nodes_test.go
nodes := &Nodes{
    config:              config,
    List:                make(map[string]*Node),
    ifaceToNodeID:       make(map[string]string),
    ifaceToLinkType:     make(map[string]LinkType),
    ifaceToLinkProtocol: make(map[string]LinkProtocol),
}
```

**What NOT to Mock:** Real file system I/O is tested with `/tmp` paths and `os.CreateTemp`. Tests verify actual file creation and removal.

---

## Fixtures and Factories

**Test Data:** JSON fixture files in `testdata/` subdirectories.

**Location:**
- `yanic/data/testdata/` — `statistics.json`, `nodeinfo.json`, etc.
- `yanic/runtime/testdata/` — `nodes.json`, `nodes-broken.json`
- `yanic/respond/testdata/` — response data
- `yanic/cmd/testdata/` — config files

**Loading Pattern:**
```go
// yanic/data/statistics_test.go
func testfile(name string, obj interface{}) {
    file, err := os.ReadFile("testdata/" + name)
    if err != nil {
        panic(err)
    }
    if err := json.Unmarshal(file, obj); err != nil {
        panic(err)
    }
}

func TestStatistics(t *testing.T) {
    assert := assert.New(t)
    obj := &Statistics{}
    testfile("statistics.json", obj)
    assert.Equal("f81a67a601ea", obj.NodeID)
    ...
}
```

**No factory helpers or builder patterns** for test data — tests build structs inline.

---

## Coverage

**Requirements:** No minimum enforced. Coverage is collected but thresholds are not checked in CI.

**View Coverage:**
```bash
make coverage.out   # generates coverage.out
make coverage.html  # generates coverage.html from coverage.out
```

**CI:** Coverage runs with race detection:
```bash
go test -race -covermode=atomic -coverprofile=coverage.out ./...
```

---

## Test Types

### Go Unit Tests

- **Scope:** Function and method behavior in isolation
- **Approach:** Direct struct construction, fixture files for JSON parsing, inline HTTP mocks
- **Location:** `yanic/**/*_test.go`
- **Execution:** `make test` or `go test ./...`

### Python Integration Tests (tunneldigger/tests/)

- **Scope:** Full client-server tunnel lifecycle via LXC containers
- **Framework:** `nose` with module-level `setup_module`/`teardown_module`
- **Location:** `tunneldigger/tests/test_nose.py`, `tunneldigger/tests/test_usage.py`
- **Requires:** LXC runtime, `CLIENT_REV` and `SERVER_REV` environment variables
- **Not suitable for local unit testing** — requires privileged container environment

### E2E Tests

- **Tunneldigger broker:** Full integration only (no unit tests for broker Python source)
- **Yanic:** No E2E tests; unit tests cover output file generation end-to-end within Go

---

## Common Patterns

### Panic Testing

Used to test unrecoverable error paths in `SaveJSON`:
```go
assert.Panics(func() {
    SaveJSON(nodes, "/proc/a")
})
```

### Error Path Testing

Test invalid configuration before valid configuration in the same test function:
```go
// Test failure first
filter, err := build(3)
assert.Error(err)
assert.Nil(filter)

// Test success
filter, err = build([]interface{}{})
assert.NoError(err)
```

### Async/Goroutine Testing

No async test helpers detected. Tests that involve goroutines (e.g., `nodes.Start()`) are not directly unit-tested — the worker goroutine's behavior is tested by calling `nodes.expire()` and `nodes.save()` directly.

### Cleanup Pattern

Temporary files cleaned up with inline error handling:
```go
if err := os.Remove(tmpfile.Name()); err != nil {
    fmt.Printf("during cleanup: %s\n", err)
}
```

---

*Testing analysis: 2026-04-15*
