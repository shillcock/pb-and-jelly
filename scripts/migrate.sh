#!/bin/bash

# PocketBase Migration Script
# Runs database migrations for dev or test environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

show_help() {
    echo "PocketBase Database Migrations"
    echo ""
    echo "Usage: $0 <environment> <subcommand> [args]"
    echo ""
    echo "Environment:"
    echo "  dev     Run migrations for development environment"
    echo "  test    Run migrations for test environment"
    echo ""
    echo "Subcommands:"
    echo "  up              Run all available migrations"
    echo "  down [number]   Revert the last [number] applied migrations"
    echo "  create name     Create new blank migration template file"
    echo "  collections     Create migration file with snapshot of current collections"
    echo "  history-sync    Clean up migration history for deleted files"
    echo ""
    echo "Examples:"
    echo "  $0 dev up                       # Apply all pending migrations"
    echo "  $0 dev down 1                   # Revert last migration"
    echo "  $0 dev create add_posts_table   # Create new migration template"
    echo "  $0 dev collections              # Snapshot current collections"
    echo "  $0 test up                      # Apply migrations to test environment"
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Parse environment
ENVIRONMENT="$1"
if [ -z "$ENVIRONMENT" ]; then
    echo_error "Environment required"
    show_help
    exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "test" ]; then
    echo_error "Invalid environment: $ENVIRONMENT. Use 'dev' or 'test'"
    exit 1
fi
shift

# Check for subcommand
if [ $# -eq 0 ]; then
    echo_error "Subcommand required"
    show_help
    exit 1
fi

# Load environment config
load_env "$ENVIRONMENT"

# Get directories
PROJECT_DIR="$(get_project_dir)"
ENV_DIR="$PROJECT_DIR/$ENVIRONMENT"
MIGRATIONS_DIR="$PROJECT_DIR/pb_migrations"

# Create migrations directory if it doesn't exist
if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo_info "Creating migrations directory: $MIGRATIONS_DIR"
    mkdir -p "$MIGRATIONS_DIR"
fi

# Get PocketBase binary
PB_BINARY=$(check_pocketbase_binary)
if [ $? -ne 0 ]; then
    exit 1
fi

# Display info
echo_info "Running migration for $ENVIRONMENT environment"
echo_debug "Data directory: $ENV_DIR/pb_data"
echo_debug "Migrations directory: $MIGRATIONS_DIR"
echo_debug "Command: migrate $@"

# Run migrate command
cd "$ENV_DIR"
"$PB_BINARY" migrate "$@" --dir="$ENV_DIR/pb_data" --migrationsDir="$MIGRATIONS_DIR"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo_success "Migration command completed successfully"
else
    echo_error "Migration command failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
