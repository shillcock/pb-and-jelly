# pb-and-jelly Integration Examples

This document shows how to integrate pb-and-jelly into various project setups for easy testing and development.

## Project Structure

After running `~/Code/pb-and-jelly/init-project.sh .` in your project, you'll have:

```
your-project/
├── pocketbase/           # All PocketBase files (self-contained)
│   ├── pb.sh            # Wrapper script
│   ├── bin/             # PocketBase binary (installed)
│   ├── dev/             # Development environment
│   │   ├── dev-users.json
│   │   └── pb_data/     # Dev database (gitignored)
│   ├── test/            # Test environment  
│   │   ├── test-users.json
│   │   └── pb_data/     # Test database (gitignored)
│   ├── pb_hooks/        # JavaScript hooks (shared)
│   ├── pb_migrations/   # JavaScript migrations (shared)
│   ├── .pb-version      # Version pinning
│   └── .pb-core         # Path to pb-and-jelly (gitignored)
├── src/                 # Your application code
├── tests/               # Your test files
└── package.json         # With pb-and-jelly scripts
```

## Package.json Scripts Integration

### Recommended Scripts (Bun)

```json
{
  "scripts": {
    "pb": "./pocketbase/pb.sh dev start",
    "pb:stop": "./pocketbase/pb.sh dev stop",
    "pb:setup": "./pocketbase/pb.sh dev setup && ./pocketbase/pb.sh dev seed-users",
    "pb:migrate": "./pocketbase/pb.sh dev migrate up",
    "pb:status": "./pocketbase/pb.sh status",
    
    "test": "bun run test:pb:start && bun test && bun run test:pb:stop",
    "test:pb:start": "./pocketbase/pb.sh test start --full --quiet",
    "test:pb:stop": "./pocketbase/pb.sh test reset --force"
  }
}
```

### Alternative Scripts (npm/pnpm/yarn)

```json
{
  "scripts": {
    "pb": "./pocketbase/pb.sh dev start",
    "pb:stop": "./pocketbase/pb.sh dev stop",
    "pb:setup": "./pocketbase/pb.sh dev setup && ./pocketbase/pb.sh dev seed-users",
    "pb:migrate": "./pocketbase/pb.sh dev migrate up",
    "pb:status": "./pocketbase/pb.sh status",
    
    "test": "npm run test:pb:start && jest && npm run test:pb:stop",
    "test:pb:start": "./pocketbase/pb.sh test start --full --quiet",
    "test:pb:stop": "./pocketbase/pb.sh test reset --force"
  }
}
```

## Testing Framework Integration

### Bun Test (Recommended)

Create `tests/setup.ts`:

```typescript
import { beforeAll, beforeEach, afterAll } from "bun:test";
import { execSync } from "child_process";

// Global test setup - runs once for entire suite
beforeAll(async () => {
  // Full setup: ensures admin user exists and starts the server
  execSync("./pocketbase/pb.sh test start --full --quiet", { stdio: "inherit" });
  // Optional: load shared fixtures from test/test-users.json
  // execSync("./pocketbase/pb.sh test seed-users", { stdio: "inherit" });
  
  // Wait for server to be fully ready
  await Bun.sleep(1000);
}, 30000);

// Fast cleanup between tests - keeps server running
beforeEach(() => {
  execSync("./pocketbase/pb.sh test clean-data", { stdio: "inherit" });
});

// Global teardown - runs once at end
afterAll(() => {
  execSync("./pocketbase/pb.sh test reset --force", { stdio: "inherit" });
});

// Test utilities
export const PB_TEST_URL = "http://127.0.0.1:8091";
export const PB_ADMIN = {
  email: "test-admin@example.com",
  password: "test-admin-pass",
};
```

Create `tests/example.test.ts`:

```typescript
import { test, expect } from "bun:test";
import { PB_TEST_URL, PB_ADMIN } from "./setup";

test("PocketBase health check", async () => {
  const response = await fetch(`${PB_TEST_URL}/api/health`);
  expect(response.ok).toBe(true);
});

test("Create user record", async () => {
  // Authenticate as admin
  const authResponse = await fetch(
    `${PB_TEST_URL}/api/collections/_superusers/auth-with-password`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        identity: PB_ADMIN.email,
        password: PB_ADMIN.password,
      }),
    }
  );
  const { token } = await authResponse.json();

  // Create a user
  const createResponse = await fetch(`${PB_TEST_URL}/api/collections/users/records`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: token,
    },
    body: JSON.stringify({
      email: "newuser@example.com",
      password: "password123",
      passwordConfirm: "password123",
      name: "New User",
    }),
  });

  expect(createResponse.ok).toBe(true);
  const user = await createResponse.json();
  expect(user.email).toBe("newuser@example.com");
});
```

Update `bunfig.toml`:

```toml
[test]
preload = ["./tests/setup.ts"]
timeout = 10000
```

### Jest Setup

Create `tests/setup.js`:

```javascript
const { execSync } = require("child_process");

// Global test setup - runs once for entire suite
beforeAll(async () => {
  // Full setup: ensures admin user exists and starts the server
  execSync("./pocketbase/pb.sh test start --full --quiet", { stdio: "inherit" });
  // Optional: load shared fixtures
  // execSync("./pocketbase/pb.sh test seed-users", { stdio: "inherit" });
  
  // Wait for server to be fully ready
  await new Promise(resolve => setTimeout(resolve, 1000));
}, 30000);

// Fast cleanup between tests - keeps server running
beforeEach(() => {
  execSync("./pocketbase/pb.sh test clean-data", { stdio: "inherit" });
});

// Global teardown - runs once at end
afterAll(() => {
  execSync("./pocketbase/pb.sh test reset --force", { stdio: "inherit" });
});

// Test utilities
global.PB_TEST_URL = "http://127.0.0.1:8091";
global.PB_ADMIN = {
  email: "test-admin@example.com",
  password: "test-admin-pass",
};
```

Update `jest.config.js`:

```javascript
module.exports = {
  setupFilesAfterEnv: ["<rootDir>/tests/setup.js"],
  testTimeout: 10000,
};
```

### Vitest Setup

Create `tests/setup.ts`:

```typescript
import { beforeAll, beforeEach, afterAll } from "vitest";
import { execSync } from "child_process";

beforeAll(async () => {
  execSync("./pocketbase/pb.sh test start --full --quiet", { stdio: "inherit" });
  // Optional: load shared fixtures
  // execSync("./pocketbase/pb.sh test seed-users", { stdio: "inherit" });
  await new Promise(resolve => setTimeout(resolve, 1000));
}, 30000);

beforeEach(() => {
  execSync("./pocketbase/pb.sh test clean-data", { stdio: "inherit" });
});

afterAll(() => {
  execSync("./pocketbase/pb.sh test reset --force", { stdio: "inherit" });
});

export const PB_TEST_URL = "http://127.0.0.1:8091";
export const PB_ADMIN = {
  email: "test-admin@example.com",
  password: "test-admin-pass",
};
```

Update `vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    setupFiles: ["./tests/setup.ts"],
    testTimeout: 10000,
  },
});
```

### Go Testing Setup

Create `testutil/pocketbase.go`:

```go
package testutil

import (
    "os/exec"
    "testing"
    "time"
)

const TestURL = "http://127.0.0.1:8091"

var AdminEmail = "test-admin@example.com"
var AdminPassword = "test-admin-pass"

func SetupPocketBase(t *testing.T) {
    t.Helper()
    
    // Start with full setup
    cmd := exec.Command("./pocketbase/pb.sh", "test", "start", "--full", "--quiet")
    if err := cmd.Run(); err != nil {
        t.Fatalf("Failed to start PocketBase: %v", err)
    }
    
    // Wait for server
    time.Sleep(1 * time.Second)
    
    // Cleanup function
    t.Cleanup(func() {
        cmd := exec.Command("./pocketbase/pb.sh", "test", "reset", "--force")
        cmd.Run()
    })
}

func CleanData(t *testing.T) {
    t.Helper()
    cmd := exec.Command("./pocketbase/pb.sh", "test", "clean-data")
    if err := cmd.Run(); err != nil {
        t.Logf("Failed to clean data: %v", err)
    }
}
```

Use in tests:

```go
func TestMain(m *testing.M) {
    // Setup runs once for all tests
    os.Exit(m.Run())
}

func TestPocketBaseIntegration(t *testing.T) {
    testutil.SetupPocketBase(t)
    
    t.Run("health check", func(t *testing.T) {
        testutil.CleanData(t)
        
        resp, err := http.Get(testutil.TestURL + "/api/health")
        if err != nil {
            t.Fatal(err)
        }
        defer resp.Body.Close()
        
        if resp.StatusCode != http.StatusOK {
            t.Errorf("Expected 200, got %d", resp.StatusCode)
        }
    })
}
```

### Python Testing Setup

Create `tests/conftest.py`:

```python
import subprocess
import time
import pytest

@pytest.fixture(scope="session")
def pocketbase_server():
    """Setup PocketBase test server for entire test session."""
    # Start with full setup
    subprocess.run(
        ["./pocketbase/pb.sh", "test", "start", "--full", "--quiet"],
        check=True
    )
    
    # Wait for server
    time.sleep(1)
    
    yield {
        "url": "http://127.0.0.1:8091",
        "admin": {
            "email": "test-admin@example.com",
            "password": "test-admin-pass"
        }
    }
    
    # Cleanup
    subprocess.run(["./pocketbase/pb.sh", "test", "reset", "--force"])

@pytest.fixture(autouse=True)
def clean_data(pocketbase_server):
    """Clean data before each test."""
    yield
    subprocess.run(["./pocketbase/pb.sh", "test", "clean-data"])

def test_health(pocketbase_server):
    import requests
    response = requests.get(f"{pocketbase_server['url']}/api/health")
    assert response.status_code == 200
```

## Migration Workflow

### Development Workflow

```bash
# Create new migration
bun pb:migrate create add_posts_table

# Edit the generated file in pb_migrations/

# Apply migration
bun pb:migrate up

# Or manually
./pocketbase/pb.sh dev migrate up
```

### Package.json Migration Scripts

```json
{
  "scripts": {
    "migrate": "./pocketbase/pb.sh dev migrate up",
    "migrate:create": "./pocketbase/pb.sh dev migrate create",
    "migrate:down": "./pocketbase/pb.sh dev migrate down 1",
    "migrate:snapshot": "./pocketbase/pb.sh dev migrate collections"
  }
}
```

### Test Environment Migrations

Migrations are automatically applied when the test server starts with `--full` flag or during `serve`. You can also apply them manually:

```bash
./pocketbase/pb.sh test migrate up
```

## CI/CD Integration

### GitHub Actions (Bun)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Bun
      uses: oven-sh/setup-bun@v1
      with:
        bun-version: latest
        
    - name: Install dependencies
      run: bun install
      
    - name: Setup PocketBase
      run: |
        ./pocketbase/pb.sh install
        
    - name: Run tests
      run: bun test
```

### GitHub Actions (Node)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        
    - name: Install dependencies
      run: npm install
      
    - name: Setup PocketBase
      run: npm run pb:install
        
    - name: Run tests
      run: npm test
```

## Usage Examples

### Quick Development Setup

```bash
# Initialize pb-and-jelly in your project
cd /path/to/your/project
~/Code/pb-and-jelly/init-project.sh .

# Install PocketBase
./pocketbase/pb.sh install

# Setup dev environment
bun pb:setup

# Start developing
bun pb
```

### Running Tests

```bash
# Run all tests
bun test

# Run specific test file
bun test tests/users.test.ts

# Watch mode
bun test --watch
```

### Manual PocketBase Management

```bash
# Check status
./pocketbase/pb.sh status

# Stop all servers
./pocketbase/pb.sh stop-all

# Clean test environment
./pocketbase/pb.sh test clean --force

# Reset test environment (stop + clean)
./pocketbase/pb.sh test reset --force
```

## PocketBase Test Helpers

### TypeScript user utilities

The template includes `pocketbase/test/helpers/pbTestUsers.ts` for managing
throwaway users during automated testing. It authenticates with the admin user
provisioned by `./pb.sh test start --full --quiet`, lazily creates the `users`
collection if needed, and tracks created accounts so they can be deleted after
each test.

```typescript
import { beforeAll, afterEach, describe, it, expect } from "vitest";
import {
  ensureTestAdmin,
  createTestUser,
  cleanupTestUsers,
} from "../pocketbase/test/helpers/pbTestUsers";

describe("PocketBase helpers", () => {
  beforeAll(async () => {
    await ensureTestAdmin();
  });

  afterEach(async () => {
    await cleanupTestUsers();
  });

  it("creates an isolated user", async () => {
    const user = await createTestUser({ name: "Helper User" });
    expect(user.email).toBeTruthy();
  });
});
```

Use `cleanupTestUsers()` or `deleteTestUser(id)` to remove records after each
test, and fall back to `./pb.sh test seed-users` whenever you need the shared
fixtures from `test/test-users.json`.

## Performance Tips

### Large Test Suites

For test suites with 100+ tests:

1. **Use `test start --full --quiet`** in `beforeAll` - ensures admin exists and starts the server
2. *(Optional)* **Run `test seed-users`** once if you need the shared fixtures from `test/test-users.json`
3. **Use `test clean-data`** in `beforeEach` - fast cleanup (~50-100ms per test)
4. **Use `pocketbase/test/helpers/pbTestUsers.ts`** to create throwaway users inside tests
5. **Use `test reset --force`** in `afterAll` - complete cleanup

This pattern reduces test suite time from 5-8 minutes to ~30 seconds for 100 tests.

### Watch Mode

When using watch mode, keep the test server running between runs:

```bash
# Terminal 1: Keep test server running
./pocketbase/pb.sh test start --full --quiet

# Terminal 2: Run tests in watch mode
bun test --watch

# When done
./pocketbase/pb.sh test reset --force
```

### CI/CD Optimization

In CI environments, the `--full` flag ensures the admin user exists and the server is ready:

```bash
./pocketbase/pb.sh test start --full --quiet
./pocketbase/pb.sh test seed-users            # Optional shared fixtures
```

This replaces:
```bash
# Old way (slower)
./pocketbase/pb.sh test start --quiet --reset
./pocketbase/pb.sh test setup                 # <-- Only needed before `--full`
./pocketbase/pb.sh test seed-users            # <-- Run explicitly when you need fixtures
```
