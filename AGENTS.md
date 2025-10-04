# AGENTS.md

## Commands

**Setup**: `./pb.sh install` (downloads PocketBase), then `./pb.sh dev setup` and `./pb.sh test setup` (creates admin users)

**Development**: `./pb.sh dev start` (port 8090), `./pb.sh dev seed-users` (optional), `./pb.sh dev stop`

**Testing**: `./test-all.sh` runs comprehensive integration tests. Or manually: `./pb.sh test start --quiet --reset`, `./pb.sh test seed-users`, run tests, `./pb.sh test stop`

**Status/Cleanup**: `./pb.sh status`, `./pb.sh clean-all --force`

## Architecture

Dual-environment PocketBase toolkit: `dev/` (persistent, port 8090) and `test/` (ephemeral, port 8091). Main CLI `pb.sh` routes to environment scripts (`pb-dev.sh`, `pb-test.sh`). Shared utilities in `scripts/utils.sh`. Config: `.pb-version` for version pinning, optional `{env}/{env}-users.json` for user seeding. Production uses PocketHost.io.

## Code Style

- Bash: Use `set -e`, utility logging functions (`echo_info`, `echo_warn`, etc.), `get_project_dir()` for paths, `load_env <environment>` for config
- Always use `./pb.sh` interface over direct script calls
- Never use `git add .` - specify individual files
- Tests use only test environment (port 8091), never dev (port 8090)
