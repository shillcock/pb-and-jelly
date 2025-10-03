# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Key Development Commands

### Initial Setup
```bash
# Install PocketBase binary
./pb.sh install

# Optional: customize credentials/ports by editing .env.dev or .env.test
```

### Development Server
```bash
# Start development server (interactive)
./pb.sh dev start

# Set up admin and test users (run in another terminal)
./pb.sh dev setup-users

# Check status of all environments
./pb.sh status

# Stop development server
./pb.sh dev stop
```

### Testing Environment
```bash
# Start test server in background with clean database
./pb.sh test start --background --quiet --reset

# Set up test users
./pb.sh test setup-users

# Stop test server
./pb.sh test stop

# Clean test environment completely
./pb.sh test clean --force
```

### Testing and Verification
```bash
# Run comprehensive test suite
./test-all.sh

# Check individual environment status
./pb.sh dev status
./pb.sh test status

# Clean all environments
./pb.sh clean-all --force
```

## Architecture Overview

**pb-tools** is a dual-environment PocketBase development toolkit designed for local development and automated testing.

### Core Components

**Unified CLI (`pb.sh`)**: Single entry point that orchestrates all operations across development and test environments. Routes commands to appropriate environment-specific scripts and manages global operations.

**Environment Isolation**: 
- `dev/` directory: Persistent development database on port 8090
- `test/` directory: Ephemeral test database on port 8091, designed for automated testing with reset capabilities

**Script Architecture**:
- `scripts/pb-dev.sh`, `scripts/pb-test.sh`: Direct environment launchers with environment-specific logging prefixes
- `scripts/utils.sh`: Shared utilities for logging, environment loading, PID management, and PocketBase process control
- `scripts/install-pocketbase.sh`: Auto-detects architecture and downloads latest PocketBase binary
- `scripts/setup-users.sh`: Automated user creation using PocketBase API
- `scripts/clean.sh`, `scripts/stop.sh`: Environment cleanup and process management utilities

### Environment Configuration

Configuration is loaded from environment-specific files (tracked in git):
- `.env.dev`: Development environment settings (port 8090)
- `.env.test`: Test environment settings (port 8091)  
- `.pb-version`: PocketBase version pinning

Key variables in each environment file:
- `ADMIN_EMAIL`, `ADMIN_PASSWORD`: Admin credentials for that environment
- `USER_EMAIL`, `USER_PASSWORD`: Test user credentials for that environment
- `PORT`: Environment-specific port
- `PB_HOST`: Host binding (127.0.0.1)

### Background Testing Support

The test environment supports background execution for integration with automated test suites:
- `--background`: Runs server as daemon with PID file management
- `--quiet`: Suppresses output for clean test logs
- `--reset`: Wipes database before starting for isolated test runs

### PID Management and Process Control

Each environment maintains a `.pid` file for process tracking. The utility functions handle graceful shutdown with fallback to force-kill, ensuring clean environment transitions.

### Direct Script Usage

For advanced use cases, environment scripts can be called directly:
- `./scripts/pb-dev.sh`: Direct development server launcher
- `./scripts/pb-test.sh`: Direct test server launcher with background/reset options

Note: The unified `./pb.sh` interface is recommended over direct script usage.

## Production Deployment

This toolkit is for local development only. Production deployment uses PocketHost.io as the hosting provider.

## User Rules Integration

- **Simplicity First**: This codebase exemplifies the "relentless pursuit of simplicity" rule - it uses straightforward bash scripts rather than complex build systems
- **PocketHost.io**: Production deployments target PocketHost.io as specified in user rules
- **Git Best Practices**: Never use `git add .` - always specify individual files to be added for better commit hygiene and intentional staging
