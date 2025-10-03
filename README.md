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
   ./pb-cli dev start
   ```

5. **Set up users (in another terminal):**
   ```bash
   ./pb-cli dev setup-users
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

### Main CLI: `./pb-cli <environment> <command>` or `./pb-cli <global-command>`

**Environment Commands:**
| Command | Description | Example |
|---------|-------------|---------|
| `<env> start` | Start server | `./pb-cli dev start` |
| `<env> stop` | Stop server | `./pb-cli test stop` |
| `<env> setup-users` | Create admin and test users | `./pb-cli dev setup-users` |
| `<env> create-user` | Interactively create a user | `./pb-cli dev create-user` |
| `<env> clean` | Clean environment data | `./pb-cli test clean --force` |
| `<env> status` | Show environment status | `./pb-cli dev status` |

**Global Commands:**
| Command | Description | Example |
|---------|-------------|---------|
| `install` | Download and install PocketBase | `./pb-cli install` |
| `status` | Show status of all environments | `./pb-cli status` |
| `stop-all` | Stop all running servers | `./pb-cli stop-all` |
| `clean-all` | Clean all environment data | `./pb-cli clean-all --force` |

### Direct Scripts (Advanced Usage)

**⚠️ Most users should use `./pb-cli` instead of direct scripts.**

For advanced usage, automation, or debugging, you can run scripts directly:

| Script | Purpose | Recommendation |
|--------|---------|----------------|
| `./scripts/pb-dev` | Start development server directly | Use `./pb-cli dev start` instead |
| `./scripts/pb-test` | Start test server directly | Use `./pb-cli test start` instead |
| `./scripts/install-pocketbase.sh` | Install PocketBase | Use `./pb-cli install` instead |
| `./scripts/setup-users.sh <env>` | Set up users (requires environment) | Use `./pb-cli <env> setup-users` instead |
| `./scripts/clean.sh <env>` | Clean environments (requires environment) | Use `./pb-cli <env> clean` instead |
| `./scripts/stop.sh <env>` | Stop servers (requires environment) | Use `./pb-cli <env> stop` instead |

**When to use direct scripts:**
- Custom automation scripts
- Debugging server startup issues
- Integration with external build systems
- When you need to bypass pb-cli's argument parsing

**For all regular usage, use the unified `./pb-cli` interface.**

## Usage Examples

### Development Workflow

```bash
# Start dev server
./pb-cli dev start

# In another terminal, set up users
./pb-cli dev setup-users

# Check status
./pb-cli status
# Or check just dev environment
./pb-cli dev status

# When done, stop the server (Ctrl+C or):
./pb-cli dev stop
```

### Testing Workflow

```bash
# Start test server in background
./pb-cli test start --background --quiet

# Set up test users
./pb-cli test setup-users

# Run your tests here...
npm test

# Clean up
./pb-cli test stop
./pb-cli test clean --force
```

### Reset Everything

```bash
# Stop all servers and clean all data
./pb-cli stop-all
./pb-cli clean-all --force

# Start fresh
./pb-cli dev start
./pb-cli dev setup-users
```

## Command Options

### Development Server (`./pb-cli dev start`)

```bash
./pb-cli dev start [options] [pocketbase-args...]

Options:
  --port PORT    Set port (default: from .env.local)
  --host HOST    Set host (default: from .env.local)
  --help, -h     Show help

Examples:
  ./pb-cli dev start                    # Start with defaults
  ./pb-cli dev start --port 9090       # Custom port
  ./pb-cli dev start serve --dev       # Pass --dev to PocketBase
```

### Test Server (`./pb-cli test start`)

```bash
./pb-cli test start [options] [pocketbase-args...]

Options:
  --port PORT        Set port (default: from .env.local)
  --host HOST        Set host (default: from .env.local)
  --background, -bg  Run in background
  --reset           Reset database before starting
  --quiet, -q       Suppress output
  --help, -h        Show help

Examples:
  ./pb-cli test start                      # Start interactive
  ./pb-cli test start --background --quiet # Background with no output
  ./pb-cli test start --reset             # Reset DB and start
```

### User Setup (`./pb-cli <env> setup-users`)

```bash
./pb-cli <env> setup-users [options]

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
  ./pb-cli dev setup-users                    # Use .env.local values
  ./pb-cli test setup-users --admin-email admin@myapp.com
```

### Cleanup (`./pb-cli <env> clean` or `./pb-cli clean-all`)

```bash
./pb-cli <env> clean [options]     # Clean specific environment
./pb-cli clean-all [options]       # Clean all environments

Environment:
  dev     Clean development environment
  test    Clean test environment

Options:
  --force, -f    Skip confirmation prompts
  --help, -h     Show help

Examples:
  ./pb-cli dev clean                   # Clean dev with confirmation
  ./pb-cli test clean --force          # Clean test without confirmation
  ./pb-cli clean-all --force           # Clean both without confirmation
```

## Directory Structure

```
pb-tools/
├── .env.example          # Example environment config
├── .env.local           # Your local config (gitignored)
├── .gitignore           # Ignore patterns
├── README.md            # This file
├── pb-cli               # Main CLI interface
├── bin/                 # PocketBase binary (gitignored)
│   └── pocketbase
├── dev/                 # Development environment (gitignored)
│   ├── pb_data/         # Development database
│   └── pocketbase.pid   # Dev server PID
├── test/                # Test environment (gitignored)
│   ├── pb_data/         # Test database
│   └── pocketbase.pid   # Test server PID
└── scripts/             # All utility scripts
    ├── utils.sh         # Shared utilities
    ├── pb-dev           # Development server launcher (internal)
    ├── pb-test          # Test server launcher (internal)
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
  await execPromise('./pb-cli test start --background --quiet --reset');
  
  // Set up test users
  await execPromise('./pb-cli test setup-users');
});

afterAll(async () => {
  // Clean up
  await execPromise('./pb-cli test stop');
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
        subprocess.run(['./pb-cli', 'test', 'start', '--background', '--quiet', '--reset'])
        subprocess.run(['./pb-cli', 'test', 'setup-users'])

    @classmethod
    def tearDownClass(cls):
        subprocess.run(['./pb-cli', 'test', 'stop'])

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
   ./pb-cli dev start --port 9090
   ```

### Permission errors

Make sure scripts are executable:
```bash
chmod +x pb-cli pb-dev pb-test scripts/*.sh
```

### Clean slate

If things get messed up:
```bash
./pb-cli stop-all
./pb-cli clean-all --force
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