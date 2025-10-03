# PocketBase Development Tools

A comprehensive toolkit for developing and testing applications with PocketBase locally, with separate environments for development and testing.

## Features

- **Dual Environment Support**: Separate `dev` and `test` environments with isolated databases
- **Automatic Setup**: Download PocketBase, create admin users, and set up test users automatically
- **Environment Configuration**: Use `.env.local` for customizable credentials and ports
- **Unified CLI**: Single command interface for all operations
- **Background Testing**: Run test servers in background for automated testing
- **Easy Cleanup**: Clean environments with confirmation prompts

## Quick Start

1. **Clone or set up the project:**
   ```bash
   git clone <your-repo> pb-tools
   cd pb-tools
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your preferred credentials
   ```

3. **Install PocketBase:**
   ```bash
   ./pb-cli install
   ```

4. **Start development server:**
   ```bash
   ./pb-cli dev
   ```

5. **Set up users (in another terminal):**
   ```bash
   ./pb-cli setup-users dev
   ```

6. **Access your PocketBase:**
   - API: http://127.0.0.1:8090
   - Admin UI: http://127.0.0.1:8090/_/

## Configuration

### Environment Variables

Copy `.env.example` to `.env.local` and customize:

```bash
# Admin user credentials
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=admin123456

# Test user credentials  
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=testpass123

# Server configuration
DEV_PORT=8090
TEST_PORT=8091
PB_HOST=127.0.0.1
```

**Note:** `.env.local` is gitignored to keep your credentials secure.

## Commands

### Main CLI: `./pb-cli <command>`

| Command | Description | Example |
|---------|-------------|---------|
| `install` | Download and install PocketBase | `./pb-cli install` |
| `dev` | Start development server | `./pb-cli dev` |
| `test` | Start test server | `./pb-cli test --background` |
| `setup-users <env>` | Create admin and test users | `./pb-cli setup-users dev` |
| `stop [env]` | Stop running servers | `./pb-cli stop all` |
| `clean [env]` | Clean environment data | `./pb-cli clean test --force` |
| `status` | Show server status | `./pb-cli status` |
| `create-user <env>` | Interactively create a user | `./pb-cli create-user dev` |

### Direct Scripts

You can also run scripts directly:

| Script | Purpose |
|--------|---------|
| `./pb-dev` | Start development server |
| `./pb-test` | Start test server |
| `./scripts/install-pocketbase.sh` | Install PocketBase |
| `./scripts/setup-users.sh` | Set up users |
| `./scripts/clean.sh` | Clean environments |
| `./scripts/stop.sh` | Stop servers |

## Usage Examples

### Development Workflow

```bash
# Start dev server
./pb-cli dev

# In another terminal, set up users
./pb-cli setup-users dev

# Check status
./pb-cli status

# When done, stop the server (Ctrl+C or):
./pb-cli stop dev
```

### Testing Workflow

```bash
# Start test server in background
./pb-cli test --background --quiet

# Set up test users
./pb-cli setup-users test

# Run your tests here...
npm test

# Clean up
./pb-cli stop test
./pb-cli clean test --force
```

### Reset Everything

```bash
# Stop all servers and clean all data
./pb-cli stop all
./pb-cli clean all --force

# Start fresh
./pb-cli dev
./pb-cli setup-users dev
```

## Command Options

### Development Server (`./pb-cli dev`)

```bash
./pb-cli dev [options] [pocketbase-args...]

Options:
  --port PORT    Set port (default: from .env.local)
  --host HOST    Set host (default: from .env.local)
  --help, -h     Show help

Examples:
  ./pb-cli dev                          # Start with defaults
  ./pb-cli dev --port 9090             # Custom port
  ./pb-cli dev serve --dev             # Pass --dev to PocketBase
```

### Test Server (`./pb-cli test`)

```bash
./pb-cli test [options] [pocketbase-args...]

Options:
  --port PORT        Set port (default: from .env.local)
  --host HOST        Set host (default: from .env.local)
  --background, -bg  Run in background
  --reset           Reset database before starting
  --quiet, -q       Suppress output
  --help, -h        Show help

Examples:
  ./pb-cli test                        # Start interactive
  ./pb-cli test --background --quiet   # Background with no output
  ./pb-cli test --reset               # Reset DB and start
```

### User Setup (`./pb-cli setup-users`)

```bash
./pb-cli setup-users <env> [options]

Environment:
  dev     Development environment
  test    Test environment

Options:
  --admin-email EMAIL      Override admin email
  --admin-password PASS    Override admin password
  --user-email EMAIL       Override test user email
  --user-password PASS     Override test user password
  --help, -h              Show help

Examples:
  ./pb-cli setup-users dev                    # Use .env.local values
  ./pb-cli setup-users test --admin-email admin@myapp.com
```

### Cleanup (`./pb-cli clean`)

```bash
./pb-cli clean [env] [options]

Environment:
  dev     Clean development environment
  test    Clean test environment
  all     Clean both (default)

Options:
  --force, -f    Skip confirmation prompts
  --help, -h     Show help

Examples:
  ./pb-cli clean dev                   # Clean dev with confirmation
  ./pb-cli clean all --force          # Clean both without confirmation
```

## Directory Structure

```
pb-tools/
├── .env.example          # Example environment config
├── .env.local           # Your local config (gitignored)
├── .gitignore           # Ignore patterns
├── README.md            # This file
├── pb-cli               # Main CLI interface
├── pb-dev               # Development server launcher
├── pb-test              # Test server launcher
├── bin/                 # PocketBase binary (gitignored)
│   └── pocketbase
├── dev/                 # Development environment (gitignored)
│   ├── pb_data/         # Development database
│   └── pocketbase.pid   # Dev server PID
├── test/                # Test environment (gitignored)
│   ├── pb_data/         # Test database
│   └── pocketbase.pid   # Test server PID
└── scripts/             # Utility scripts
    ├── utils.sh         # Shared utilities
    ├── install-pocketbase.sh
    ├── setup-users.sh
    ├── clean.sh
    └── stop.sh
```

## Environments

### Development Environment

- **Port**: 8090 (configurable in `.env.local`)
- **Directory**: `./dev/`
- **Purpose**: Main development work
- **Database**: Persistent across restarts

### Test Environment

- **Port**: 8091 (configurable in `.env.local`)
- **Directory**: `./test/`
- **Purpose**: Automated testing
- **Database**: Can be reset easily with `--reset` flag

## Integration with Testing

### Node.js/JavaScript Example

```javascript
// test-setup.js
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

beforeAll(async () => {
  // Start test server
  await execPromise('./pb-cli test --background --quiet --reset');
  
  // Set up test users
  await execPromise('./pb-cli setup-users test');
});

afterAll(async () => {
  // Clean up
  await execPromise('./pb-cli stop test');
});

// Your tests here...
test('should connect to PocketBase', async () => {
  const response = await fetch('http://127.0.0.1:8091/api/health');
  expect(response.ok).toBe(true);
});
```

### Python Example

```python
import subprocess
import unittest

class TestPocketBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Start test server
        subprocess.run(['./pb-cli', 'test', '--background', '--quiet', '--reset'])
        subprocess.run(['./pb-cli', 'setup-users', 'test'])

    @classmethod
    def tearDownClass(cls):
        subprocess.run(['./pb-cli', 'stop', 'test'])

    def test_health_check(self):
        import requests
        response = requests.get('http://127.0.0.1:8091/api/health')
        self.assertEqual(response.status_code, 200)
```

## Troubleshooting

### PocketBase won't start

1. Check if ports are available:
   ```bash
   lsof -i :8090 -i :8091
   ```

2. Check the status:
   ```bash
   ./pb-cli status
   ```

3. Try different ports:
   ```bash
   ./pb-cli dev --port 9090
   ```

### Permission errors

Make sure scripts are executable:
```bash
chmod +x pb-cli pb-dev pb-test scripts/*.sh
```

### Clean slate

If things get messed up:
```bash
./pb-cli stop all
./pb-cli clean all --force
rm -f bin/pocketbase
./pb-cli install
```

### Environment not loading

Check that `.env.local` exists and has valid syntax:
```bash
cat .env.local
```

## Production Deployment

This toolkit is for local development only. For production:

1. **PocketHost.io**: Deploy your PocketBase to PocketHost.io (as configured in your rules)
2. **Environment Variables**: Use production values in your app
3. **Database Migration**: Export your dev schema and import to production

## Contributing

1. Follow the existing script patterns
2. Use the shared utilities in `scripts/utils.sh`
3. Update this README for new features
4. Test all environments (dev/test) before committing

## License

[Your License Here]