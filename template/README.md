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
# Suite setup (once per test run)
./pb.sh test start --full --quiet
./pb.sh test seed-users          # Optional: load users from test/test-users.json

# Between tests (fast cleanup)
./pb.sh test clean-data

# Suite teardown
./pb.sh test reset --force
```

> Prefer creating throwaway users inside tests with
> `test/helpers/pbTestUsers.ts`. The helper authenticates with the admin account
> provisioned by `--full` and can create or clean up records on demand.

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

### Test Helpers
- `test/helpers/pbTestUsers.ts` - TypeScript utilities for creating and cleaning
  up test users via the PocketBase API.

Use `createTestUser()` inside tests to generate throwaway accounts and
`cleanupTestUsers()` to remove them after each test. These helpers log in with
the test admin created by `./pb.sh test start --full --quiet` and will create the
`users` collection automatically if it is missing. You can still load
`test/test-users.json` through `./pb.sh test seed-users` whenever you need the
shared fixtures.

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

```bash
# Create new migration
./pb.sh dev migrate create my_migration

# Apply migrations (or they auto-apply during serve)
./pb.sh dev migrate up

# Revert last migration
./pb.sh dev migrate down 1

# Create snapshot of current collections
./pb.sh dev migrate collections
```

See [PocketBase JS Overview](https://pocketbase.io/docs/js-overview/) and [Migrations documentation](https://pocketbase.io/docs/js-migrations/) for more details.

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
