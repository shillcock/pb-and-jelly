# PocketBase Development Tools

A comprehensive toolkit for developing and testing applications with PocketBase locally, with separate environments for development and testing.

## Features

- **Dual Environment Support**: Separate `dev` and `test` environments with isolated databases
- **Automatic Setup**: Download PocketBase, create admin users, and set up test users automatically
- **Environment-Specific Configuration**: Use `.env.dev` and `.env.test` for environment-specific settings, `.env.local` for global overrides
- **Unified CLI**: Single command interface for all operations
- **Background Testing**: Run test servers in background for automated testing
- **Easy Cleanup**: Clean environments with confirmation prompts

## Quick Start

1. **Clone or set up the project:**
   ```bash
   git clone <your-repo> pb-tools
   cd pb-tools
   ```

2. **Configure users (optional):**
   ```bash
   # Environment-specific configs are hardcoded and ready to use
   # Create seed files for custom user setups (see User Seed Files section)
   ```

3. **Install PocketBase:**
   ```bash
   ./pb.sh install
   ```

4. **Start development server:**
   ```bash
   ./pb.sh dev start
   ```

5. **Seed users (in another terminal):**
   ```bash
   # Create dev/dev-users.json first (see example files), then:
   ./pb.sh dev seed-users
   ```

6. **Access your PocketBase:**
   - API: http://127.0.0.1:8090
   - Admin UI: http://127.0.0.1:8090/_/

## Configuration

### Configuration Files

This toolkit uses configuration files for different purposes:

**Configuration Files (tracked in git):**
- `.pb-version` - PocketBase version pinning
- `dev/dev-users.json` - User seed data for development environment (optional)
- `test/test-users.json` - User seed data for test environment (optional)

**Environment Settings (hardcoded):**
- **Dev**: Port 8090, Host 127.0.0.1
- **Test**: Port 8091, Host 127.0.0.1


### User Seed Files

For setting up multiple users (useful for testing scenarios), create JSON seed files:

**Example `dev/dev-users.json`:**
```json
{
  "admin": {
    "email": "dev-admin@example.com",
    "password": "dev-admin-pass"
  },
  "users": [
    {
      "email": "dev-user@example.com",
      "password": "devpass123",
      "name": "Dev User"
    }
  ]
}
```

**Example `test/test-users.json`:**
```json
{
  "admin": {
    "email": "test-admin@example.com", 
    "password": "test-admin-pass"
  },
  "users": [
    {
      "email": "alice@example.com",
      "password": "alice123",
      "name": "Alice Cooper"
    },
    {
      "email": "bob@example.com",
      "password": "bob123",
      "name": "Bob Smith"
    }
  ]
}
```

**Configuration Priority:**
1. Seed file credentials (if available)
2. Hardcoded fallback values (built-in)


### Version Pinning

For CI/CD reliability, this toolkit uses a `.pb-version` file (similar to `.node-version`) to pin PocketBase to a specific version:

- **`.pb-version`**: Contains the PocketBase version (e.g., `0.30.1`)
- **Install behavior**: Always installs the pinned version, never "latest"
- **Upgrade management**: Use `./pb.sh upgrade` to see available versions and upgrade guidance
- **Team consistency**: Everyone gets the same version when they clone the repo

**Benefits:**
- Reproducible builds in CI/CD pipelines
- No unexpected API changes from automatic updates
- Controlled upgrade process
- Follows standard version pinning conventions (like `.node-version`)

**To upgrade:**
1. Run `./pb.sh upgrade` to see available versions
2. Update the version number in `.pb-version`
3. Run `./pb.sh install` to install the new version

## Commands

### Main Interface: `./pb.sh <environment> <command>` or `./pb.sh <global-command>`

**Environment Commands:**
| Command | Description | Example |
|---------|-------------|---------|
| `<env> start` | Start server | `./pb.sh dev start` |
| `<env> stop` | Stop server | `./pb.sh test stop` |
| `<env> setup` | Set up admin user | `./pb.sh dev setup` |
| `<env> seed-users` | Seed users from JSON file | `./pb.sh dev seed-users` |
| `<env> clean` | Clean environment data | `./pb.sh test clean --force` |
| `<env> status` | Show environment status | `./pb.sh dev status` |

**Global Commands:**
| Command | Description | Example |
|---------|-------------|---------|
| `install` | Download and install PocketBase | `./pb.sh install` |
| `upgrade` | Show available versions and upgrade guidance | `./pb.sh upgrade` |
| `status` | Show status of all environments | `./pb.sh status` |
| `stop-all` | Stop all running servers | `./pb.sh stop-all` |
| `clean-all` | Clean all environment data | `./pb.sh clean-all --force` |

### Direct Scripts (Advanced Usage)

**⚠️ Most users should use `./pb.sh` instead of direct scripts.**

For advanced usage, automation, or debugging, you can run scripts directly:

| Script | Purpose | Recommendation |
|--------|---------|----------------|
| `./scripts/pb-dev.sh` | Start development server directly | Use `./pb.sh dev start` instead |
| `./scripts/pb-test.sh` | Start test server directly | Use `./pb.sh test start` instead |
| `./scripts/install-pocketbase.sh` | Install PocketBase | Use `./pb.sh install` instead |
| `./scripts/seed-users.sh <env>` | Seed users from JSON (requires environment) | Use `./pb.sh <env> seed-users` instead |
| `./scripts/clean.sh <env>` | Clean environments (requires environment) | Use `./pb.sh <env> clean` instead |
| `./scripts/stop.sh <env>` | Stop servers (requires environment) | Use `./pb.sh <env> stop` instead |

**When to use direct scripts:**
- Custom automation scripts
- Debugging server startup issues
- Integration with external build systems
- When you need to bypass pb.sh's argument parsing

**For all regular usage, use the unified `./pb.sh` interface.**

## Usage Examples

### Development Workflow

```bash
# Start dev server
./pb.sh dev start

# In another terminal, seed users from JSON
./pb.sh dev seed-users

# Check status
./pb.sh status
# Or check just dev environment
./pb.sh dev status

# When done, stop the server (Ctrl+C or):
./pb.sh dev stop
```

### Testing Workflow

```bash
# Start test server in background
./pb.sh test start --background --quiet

# Seed test users from JSON
./pb.sh test seed-users

# Run your tests here...
npm test

# Clean up
./pb.sh test stop
./pb.sh test clean --force
```

### Reset Everything

```bash
# Stop all servers and clean all data
./pb.sh stop-all
./pb.sh clean-all --force

# Start fresh
./pb.sh dev start
./pb.sh dev seed-users
```

## Command Options

### Development Server (`./pb.sh dev start`)

```bash
./pb.sh dev start [options] [pocketbase-args...]

Options:
  --port PORT    Set port (default: from .env.local)
  --host HOST    Set host (default: from .env.local)
  --help, -h     Show help

Examples:
  ./pb.sh dev start                    # Start with defaults
  ./pb.sh dev start --port 9090       # Custom port
  ./pb.sh dev start serve --dev       # Pass --dev to PocketBase
```

### Test Server (`./pb.sh test start`)

```bash
./pb.sh test start [options] [pocketbase-args...]

Options:
  --port PORT        Set port (default: from .env.local)
  --host HOST        Set host (default: from .env.local)
  --background, -bg  Run in background
  --reset           Reset database before starting
  --quiet, -q       Suppress output
  --help, -h        Show help

Examples:
  ./pb.sh test start                      # Start interactive
  ./pb.sh test start --background --quiet # Background with no output
  ./pb.sh test start --reset             # Reset DB and start
```

### User Seeding (`./pb.sh <env> seed-users`)

```bash
./pb.sh <env> seed-users [options]

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
  ./pb.sh dev seed-users                     # Seed users from JSON file
  ./pb.sh test seed-users --admin-email admin@myapp.com
```

### Cleanup (`./pb.sh <env> clean` or `./pb.sh clean-all`)

```bash
./pb.sh <env> clean [options]     # Clean specific environment
./pb.sh clean-all [options]       # Clean all environments

Environment:
  dev     Clean development environment
  test    Clean test environment

Options:
  --force, -f    Skip confirmation prompts
  --help, -h     Show help

Examples:
  ./pb.sh dev clean                   # Clean dev with confirmation
  ./pb.sh test clean --force          # Clean test without confirmation
  ./pb.sh clean-all --force           # Clean both without confirmation
```

## Directory Structure

```
pb-tools/
├── .env.example          # Example environment config
├── .env.local           # Your local config (gitignored)
├── .gitignore           # Ignore patterns
├── README.md            # This file
├── pb.sh                # Main interface script
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
    ├── pb-dev.sh        # Development server launcher (internal)
    ├── pb-test.sh       # Test server launcher (internal)
    ├── install-pocketbase.sh
    ├── seed-users.sh
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
  await execPromise('./pb.sh test start --background --quiet --reset');
  
  // Seed test users from JSON
  await execPromise('./pb.sh test seed-users');
});

afterAll(async () => {
  // Clean up
  await execPromise('./pb.sh test stop');
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
        subprocess.run(['./pb.sh', 'test', 'start', '--background', '--quiet', '--reset'])
        subprocess.run(['./pb.sh', 'test', 'seed-users'])

    @classmethod
    def tearDownClass(cls):
        subprocess.run(['./pb.sh', 'test', 'stop'])

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
   ./pb.sh status
   ```

3. Try different ports:
   ```bash
   ./pb.sh dev start --port 9090
   ```

### Permission errors

Make sure scripts are executable:
```bash
chmod +x pb-cli pb-dev pb-test scripts/*.sh
```

### Clean slate

If things get messed up:
```bash
./pb.sh stop-all
./pb.sh clean-all --force
rm -f bin/pocketbase
./pb.sh install
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