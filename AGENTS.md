# AGENTS.md

## Architecture

**Core/Template Design**: pb-and-jelly provides core scripts that manage self-contained PocketBase setups in projects. Core logic lives in `pb-and-jelly/scripts/`, template files in `pb-and-jelly/template/`. Each initialized project gets its own `pocketbase/` directory with binary, data, and version config.

**Dual Environments**: Each project has `dev/` (persistent, port 8090) and `test/` (ephemeral, port 8091) environments with isolated databases.

**Always run from project**: All commands use project wrapper (`cd project/pocketbase && ./pb.sh`). Main `pb-and-jelly/pb.sh` requires `PB_PROJECT_DIR` to be set by wrapper.

## Commands

### Initial Setup (One Time)
```bash
# Clone pb-and-jelly
git clone <repo> ~/Code/pb-and-jelly

# Initialize in your project
cd /path/to/your-project
~/Code/pb-and-jelly/init-project.sh .

# Install PocketBase (optional if already installed globally)
cd pocketbase
./pb.sh install          # Or skip if using global install
./pb.sh dev setup
./pb.sh test setup
```

### Development
```bash
cd /path/to/your-project/pocketbase
./pb.sh dev start           # Port 8090
./pb.sh dev seed-users      # Optional
./pb.sh dev migrate up      # Apply migrations
./pb.sh dev stop
```

### Testing

**Performance-optimized pattern (recommended):**
```bash
cd /path/to/your-project/pocketbase

# Suite setup (once) - full initialization
./pb.sh test start --full --quiet

# Between tests - fast data cleanup
./pb.sh test clean-data

# Suite teardown (once)
./pb.sh test reset --force
```

**Manual testing:**
```bash
./pb.sh test start --quiet --reset
./pb.sh test seed-users
# Run your tests
./pb.sh test stop
```

### Migrations
```bash
./pb.sh dev migrate up              # Apply all migrations
./pb.sh dev migrate create my_table # Create new migration
./pb.sh dev migrate collections     # Snapshot collections
./pb.sh dev migrate down 1          # Revert last migration
```

### Status/Cleanup
```bash
./pb.sh status              # Show all environments
./pb.sh stop-all            # Stop all servers
./pb.sh kill-all --force    # Force kill all PocketBase processes
./pb.sh clean-all --force   # Clean all data
```

## Code Style

- **Bash**: Use `set -e`, utility logging (`echo_info`, `echo_warn`), `get_project_dir()` for paths, `load_env <environment>` for config
- **Wrapper requirement**: Scripts require `PB_PROJECT_DIR` set by project wrapper
- **Always use wrapper**: Run commands via `project/pocketbase/pb.sh`, never call core `pb-and-jelly/pb.sh` directly
- **Tests**: Use only test environment (port 8091), never dev (port 8090)

## Git Conventions

- **Staging**: Never use `git add .` - specify individual files
- **Commit messages**: Write clear, concise commit messages that describe what and why
- **No AI attribution**: Never include co-authoring, "co-written by," "co-committed by," or any collaboration by AI agents in commit messages. Commits should appear as regular human commits without AI attribution.
- **Never push without permission**: Never run `git push` without explicit user instruction. Always ask for permission before pushing commits to remote repositories.
