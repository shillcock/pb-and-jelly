# PocketBase Setup

This directory contains PocketBase configuration for this project.

## Quick Start

```bash
# Install PocketBase binary (run once)
./pb.sh install

# Start development server
./pb.sh dev start

# In another terminal, setup admin and seed users
./pb.sh dev setup
./pb.sh dev seed-users

# Access PocketBase
# API: http://127.0.0.1:8090
# Admin UI: http://127.0.0.1:8090/_/
```

## Testing

```bash
# Start test server
./pb.sh test start --quiet --reset

# Setup test environment
./pb.sh test setup
./pb.sh test seed-users

# Run your tests here

# Stop test server
./pb.sh test stop
```

## Configuration

### Version Pinning
- `.pb-version` - Controls which PocketBase version to install
- Edit this file to pin a different version, then run `./pb.sh install`

### User Seed Files
- `dev/dev-users.json` - Development environment users
- `test/test-users.json` - Test environment users

Example structure:
```json
{
  "admin": {
    "email": "admin@example.com",
    "password": "admin-password"
  },
  "users": [
    {
      "email": "user@example.com",
      "password": "userpass123",
      "name": "Test User"
    }
  ]
}
```

### JavaScript Extensions

#### Hooks (`pb_hooks/`)
Add custom server-side logic in `pb_hooks/*.pb.js` files:
- Custom routes and endpoints
- Event handlers (onCreate, onUpdate, etc.)
- Authentication hooks
- Shared between dev and test environments

#### Migrations (`pb_migrations/`)
Manage database schema in `pb_migrations/*.js` files:
- Collection definitions
- Schema changes
- Data migrations
- Shared between dev and test environments

See [PocketBase JS Overview](https://pocketbase.io/docs/js-overview/) for documentation.

## Directory Structure

```
pocketbase/
├── bin/                 # PocketBase binary (installed, gitignored)
├── dev/                 # Development environment
│   ├── pb_data/        # Dev database (gitignored)
│   └── dev-users.json  # Dev user seed data
├── test/               # Test environment
│   ├── pb_data/        # Test database (gitignored)
│   └── test-users.json # Test user seed data
├── pb_hooks/           # JavaScript hooks (shared)
├── pb_migrations/      # JavaScript migrations (shared)
├── .pb-version         # PocketBase version
├── .pb-core       # Path to pb-and-jelly (gitignored)
└── pb.sh               # Wrapper script
```

## Environment Settings

- **Development**: Port 8090, Host 127.0.0.1
- **Test**: Port 8091, Host 127.0.0.1

## Commands Reference

```bash
# Global commands
./pb.sh install           # Install PocketBase binary
./pb.sh upgrade          # Show available versions
./pb.sh status           # Show status of all servers

# Environment-specific commands (dev or test)
./pb.sh dev start        # Start server
./pb.sh dev stop         # Stop server
./pb.sh dev setup        # Setup admin user
./pb.sh dev seed-users   # Seed users from JSON
./pb.sh dev clean        # Clean environment data
./pb.sh dev status       # Show environment status
```
