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
│   │   └── main.pb.js
│   ├── pb_migrations/   # JavaScript migrations (shared)
│   │   └── 1000000000_initial_setup.js
│   ├── .pb-version      # Version pinning
│   ├── .pb-core    # Path to pb-and-jelly (gitignored)
│   └── .gitignore       # Project-specific ignores
├── src/                 # Your application code
├── tests/               # Your test files
└── package.json         # With pb-and-jelly scripts
```

## Package.json Scripts Integration

### Basic Scripts

```json
{
  "scripts": {
    "pb:install": "./pocketbase/pb.sh install",
    "pb:dev": "./pocketbase/pb.sh dev start",
    "pb:dev:setup": "./pocketbase/pb.sh dev setup && ./pocketbase/pb.sh dev seed-users",
    
    "pb:test:start": "./pocketbase/pb.sh test start --quiet --reset",
    "pb:test:setup": "./pocketbase/pb.sh test setup && ./pocketbase/pb.sh test seed-users",
    "pb:test:stop": "./pocketbase/pb.sh test stop",
    
    "pb:status": "./pocketbase/pb.sh status",
    "pb:clean": "./pocketbase/pb.sh clean-all --force"
  }
}
```

### Test Integration Scripts

**Performance-optimized (recommended):**
```json
{
  "scripts": {
    "test": "npm run test:pb:setup && npm run test:run && npm run test:pb:cleanup",
    "test:run": "jest",
    "test:pb:setup": "./pocketbase/pb.sh test start --full --quiet",
    "test:pb:cleanup": "./pocketbase/pb.sh test reset --force",
    
    "test:watch": "npm run test:pb:setup && jest --watch",
    "test:ci": "npm run test:pb:setup && jest --ci --coverage && npm run test:pb:cleanup"
  }
}
```

**Legacy (slower):**
```json
{
  "scripts": {
    "test:pb:setup": "./pocketbase/pb.sh test start --quiet --reset && ./pocketbase/pb.sh test setup && ./pocketbase/pb.sh test seed-users",
    "test:pb:cleanup": "./pocketbase/pb.sh test stop"
  }
}
```

### Development Workflow Scripts

```json
{
  "scripts": {
    "dev": "npm run dev:pb && npm run dev:app",
    "dev:pb": "./pocketbase/pb.sh dev start && ./pocketbase/pb.sh dev setup && ./pocketbase/pb.sh dev seed-users",
    "dev:app": "npm run start",
    
    "setup": "npm install && npm run pb:install && npm run dev:pb",
    "reset": "./pocketbase/pb.sh clean-all --force && npm run dev:pb"
  }
}
```

## Testing Framework Integration

### Jest Setup

**Performance-optimized (recommended for large test suites):**

Create `tests/setup.js`:

```javascript
const { execSync } = require('child_process');

// Global test setup - runs once for entire suite
beforeAll(async () => {
  // Full setup: admin + start + seed users
  execSync('./pocketbase/pb.sh test start --full --quiet', { stdio: 'inherit' });
  
  // Wait for server to be fully ready
  await new Promise(resolve => setTimeout(resolve, 1000));
}, 30000);

// Fast cleanup between individual tests - keeps server running
beforeEach(() => {
  execSync('./pocketbase/pb.sh test clean-data', { stdio: 'inherit' });
});

// Global test teardown - runs once at end
afterAll(() => {
  execSync('./pocketbase/pb.sh test reset --force', { stdio: 'inherit' });
});

// Test utilities
global.PB_TEST_URL = 'http://127.0.0.1:8091';
global.PB_ADMIN = {
  email: 'test-admin@example.com',
  password: 'test-admin-pass'
};
```

**Simple setup (for small test suites):**

```javascript
const { execSync } = require('child_process');

beforeAll(async () => {
  execSync('./pocketbase/pb.sh test start --quiet --reset', { stdio: 'inherit' });
  execSync('./pocketbase/pb.sh test setup', { stdio: 'inherit' });
  execSync('./pocketbase/pb.sh test seed-users', { stdio: 'inherit' });
  await new Promise(resolve => setTimeout(resolve, 1000));
}, 30000);

afterAll(() => {
  execSync('./pocketbase/pb.sh test stop', { stdio: 'inherit' });
});

global.PB_TEST_URL = 'http://127.0.0.1:8091';
```

Update `jest.config.js`:

```javascript
module.exports = {
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  testTimeout: 10000,
};
```

### Vitest Setup

Create `tests/setup.ts`:

```typescript
import { beforeAll, afterAll } from 'vitest';
import { execSync } from 'child_process';

beforeAll(async () => {
  execSync('./pocketbase/pb.sh test start --quiet --reset', { stdio: 'inherit' });
  execSync('./pocketbase/pb.sh test setup', { stdio: 'inherit' });
  execSync('./pocketbase/pb.sh test seed-users', { stdio: 'inherit' });
  
  await new Promise(resolve => setTimeout(resolve, 1000));
}, 30000);

afterAll(() => {
  execSync('./pocketbase/pb.sh test stop', { stdio: 'inherit' });
});

export const PB_TEST_URL = 'http://127.0.0.1:8091';
export const PB_ADMIN = {
  email: 'test-admin@example.com',
  password: 'test-admin-pass'
};
```

Update `vite.config.ts`:

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globalSetup: ['./tests/setup.ts'],
    timeout: 10000,
  },
});
```

### Go Testing Setup

Create `testutil/pocketbase.go`:

```go
package testutil

import (
    "os"
    "os/exec"
    "testing"
    "time"
)

const TestURL = "http://127.0.0.1:8091"

func SetupPocketBase(t *testing.T) {
    // Start test server
    cmd := exec.Command("./pocketbase/pb.sh", "test", "start", "--quiet", "--reset")
    if err := cmd.Run(); err != nil {
        t.Fatalf("Failed to start PocketBase test server: %v", err)
    }
    
    // Setup admin and users
    cmd = exec.Command("./pocketbase/pb.sh", "test", "setup")
    if err := cmd.Run(); err != nil {
        t.Fatalf("Failed to setup admin: %v", err)
    }
    
    cmd = exec.Command("./pocketbase/pb.sh", "test", "seed-users")
    if err := cmd.Run(); err != nil {
        t.Fatalf("Failed to seed users: %v", err)
    }
    
    // Wait for server to be ready
    time.Sleep(1 * time.Second)
    
    // Cleanup function
    t.Cleanup(func() {
        cmd := exec.Command("./pocketbase/pb.sh", "test", "stop")
        cmd.Run()
    })
}
```

Use in tests:

```go
func TestPocketBaseIntegration(t *testing.T) {
    testutil.SetupPocketBase(t)
    
    // Your tests here using testutil.TestURL
}
```

### Python Testing Setup

Create `tests/conftest.py`:

```python
import subprocess
import time
import pytest

@pytest.fixture(scope="session")
def pocketbase():
    """Setup PocketBase for testing session."""
    # Start test server
    subprocess.run(["./pocketbase/pb.sh", "test", "start", "--quiet", "--reset"])
    subprocess.run(["./pocketbase/pb.sh", "test", "setup"])
    subprocess.run(["./pocketbase/pb.sh", "test", "seed-users"])
    
    # Wait for server to be ready
    time.sleep(1)
    
    yield {
        'url': 'http://127.0.0.1:8091',
        'admin': {
            'email': 'test-admin@example.com',
            'password': 'test-admin-pass'
        }
    }
    
    # Cleanup
    subprocess.run(["./pocketbase/pb.sh", "test", "stop"])

def test_pocketbase_connection(pocketbase):
    import requests
    response = requests.get(f"{pocketbase['url']}/api/health")
    assert response.status_code == 200
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: npm install
      
    - name: Setup PocketBase
      run: |
        npm run pb:install
        
    - name: Run tests
      run: npm test
```

### Docker Compose for Development

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  pocketbase:
    image: alpine:latest
    command: |
      sh -c "
        apk add --no-cache bash curl &&
        ./pocketbase/pb.sh install &&
        ./pocketbase/pb.sh dev start
      "
    ports:
      - "8090:8090"
    volumes:
      - .:/app
    working_dir: /app
    
  app:
    build: .
    depends_on:
      - pocketbase
    environment:
      - POCKETBASE_URL=http://pocketbase:8090
```

## Usage Examples

### Quick Development Setup

```bash
# Initialize pb-and-jelly in your project
cd /path/to/your/project
~/Code/pb-and-jelly/init-project.sh .

# Setup for development
npm run pb:install
npm run pb:dev:setup

# Start developing
npm run dev
```

### Running Tests

```bash
# One-time test run
npm test

# Watch mode for development
npm run test:watch

# CI environment
npm run test:ci
```

### Manual PocketBase Management

```bash
# Check status
./pocketbase/pb.sh status

# Reset everything
./pocketbase/pb.sh clean-all --force

# Start fresh development environment
npm run dev:pb
```