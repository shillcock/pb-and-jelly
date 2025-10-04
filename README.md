# PB & Jelly

A core/template toolkit for developing and testing applications with PocketBase locally. Like peanut butter and jelly, PocketBase and your project are better together! 🥜🍇

pb-and-jelly provides scripts (**core**) that manage self-contained PocketBase setups (**template**) in your projects.

## Architecture

pb-and-jelly uses a **core/template** design:

- **Core** (`pb-and-jelly/scripts/`): All logic and scripts stay in pb-and-jelly repo
- **Template** (`pb-and-jelly/template/`): Self-contained project setup that gets copied to each project
- **Projects**: Each initialized project has its own binary, data, version, and configuration

**Benefits:**
- Each project is fully independent with its own PocketBase version
- Update pb-and-jelly (git pull) without affecting project data
- Simple mental model: core has logic, template has data

## Features

- **Dual Environment Support**: Separate `dev` and `test` environments with isolated databases
- **Self-Contained Projects**: Each project has own PocketBase binary, data, and version
- **Version Pinning Per Project**: Control PocketBase version independently in each project
- **Automatic Setup**: Download PocketBase, create admin users, and seed test users
- **Unified CLI**: Single command interface for all operations
- **Background Testing**: Run test servers in background for automated testing
- **JavaScript Extensions**: Support for hooks and migrations

## Quick Start

### 1. Clone pb-and-jelly (one time)

```bash
git clone <your-repo> ~/Code/pb-and-jelly
```

### 2. Initialize in your project

```bash
cd /path/to/your-project
~/Code/pb-and-jelly/scripts/init-project.sh .
```

This creates a `pocketbase/` directory with:
- `pb.sh` - Wrapper script that calls pb-and-jelly
- `bin/` - PocketBase binary location
- `dev/` and `test/` - Environment directories
- `pb_hooks/` and `pb_migrations/` - JavaScript extensions
- `.pb-version` - Version pinning for this project
- `.pb-core` - Path to pb-and-jelly (gitignored)

### 3. Install and start

```bash
cd pocketbase
./pb.sh install           # Downloads PocketBase binary
./pb.sh dev start         # Starts development server

# In another terminal
./pb.sh dev setup         # Creates admin user
./pb.sh dev seed-users    # Seeds test users (optional)
```

### 4. Access your PocketBase

- API: http://127.0.0.1:8090
- Admin UI: http://127.0.0.1:8090/_/

## Configuration

All configuration files live in your project's `pocketbase/` directory (created by `init-project.sh`):

### Version Pinning

- `pocketbase/.pb-version` - Controls which PocketBase version gets installed for this project
- Each project can use a different PocketBase version
- Edit this file and run `./pb.sh install` to change versions

### User Seed Files

- `pocketbase/dev/dev-users.json` - Development environment users (optional)
- `pocketbase/test/test-users.json` - Test environment users (optional)

### Environment Settings (hardcoded)

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

## Commands

All commands are run from your project's `pocketbase/` directory using the wrapper script `./pb.sh`.

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

## Updating pb-and-jelly

Since pb-and-jelly uses a core/template architecture, you can safely update the core without affecting your projects:

```bash
cd ~/Code/pb-and-jelly
git pull
```

Your project's `pocketbase/` directories remain unchanged. The updated scripts will be used next time you run commands in your projects.

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
# Start test server
./pb.sh test start --quiet

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
  --reset           Reset database before starting
  --quiet, -q       Suppress output
  --help, -h        Show help

Examples:
  ./pb.sh test start                      # Start interactive
  ./pb.sh test start --quiet              # Start with no output
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
pb-and-jelly/
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
  await execPromise('./pb.sh test start --quiet --reset');
  
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
        subprocess.run(['./pb.sh', 'test', 'start', '--quiet', '--reset'])
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