#!/bin/bash

# PocketBase Test Environment Launcher
# Launches PocketBase using the test/ directory as working directory
#
# NOTE: Most users should use './pb.sh test start' instead of running this directly.
# This script is primarily used internally by pb.sh and for advanced/automation use cases.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load environment variables
load_env "test"

PROJECT_DIR="$(get_project_dir)"
TEST_DIR="$PROJECT_DIR/test"

# Check if PocketBase binary exists
PB_BINARY=$(check_pocketbase_binary)

# Create test directory if it doesn't exist
mkdir -p "$TEST_DIR"

# Use environment variables for defaults
TEST_PORT="$PORT"
TEST_HOST="$PB_HOST"

# Override echo functions for test context
echo_info() {
    echo -e "${PURPLE}[TEST]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

echo_error() {
    echo -e "${RED}[TEST]${NC} $1"
}

echo_debug() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Parse command line arguments
ARGS=()
BACKGROUND=true
RESET_DB=false
QUIET=false
FULL_SETUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            TEST_PORT="$2"
            shift 2
            ;;
        --host)
            TEST_HOST="$2"
            shift 2
            ;;
        --foreground|-fg)
            BACKGROUND=false
            shift
            ;;
        --reset)
            RESET_DB=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --full)
            FULL_SETUP=true
            shift
            ;;
        --help|-h)
            echo "PocketBase Test Environment"
            echo ""
            echo "Usage: $0 [options] [pocketbase-args...]"
            echo ""
            echo "Options:"
            echo "  --port PORT        Set port (default: 8091)"
            echo "  --host HOST        Set host (default: 127.0.0.1)"
            echo "  --foreground, -fg  Run in foreground (default: background)"
            echo "  --reset           Reset test database before starting"
            echo "  --full            Full setup: setup admin + start + seed users"
            echo "  --quiet, -q       Suppress output (useful for testing)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Any additional arguments will be passed directly to PocketBase"
            echo ""
            echo "Examples:"
            echo "  $0                          # Start in background (default)"
            echo "  $0 --port 9091              # Start on port 9091"
            echo "  $0 --foreground --quiet     # Start in foreground, no output"
            echo "  $0 --reset                  # Reset DB and start"
            echo "  $0 --full --quiet           # Full setup for testing"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Reset database if requested
if [ "$RESET_DB" = true ]; then
    if [ "$QUIET" = false ]; then
        echo_info "Resetting test database..."
    fi
    rm -rf "$TEST_DIR/pb_data"
fi

# Run admin setup first if --full is specified
if [ "$FULL_SETUP" = true ]; then
    if [ "$QUIET" = false ]; then
        echo_info "Running admin setup..."
    fi
    if setup_admin_user "test" "$QUIET"; then
        if [ "$QUIET" = false ]; then
            echo_success "Admin setup complete"
        fi
    else
        echo_error "Admin setup failed"
        exit 1
    fi
fi

# Default to 'serve' command if no command specified
if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=("serve")
fi

if [ "$QUIET" = false ]; then
    echo_info "Starting PocketBase Test Environment"
    echo_debug "Working directory: $TEST_DIR"
    echo_debug "Binary: $PB_BINARY"
    echo_debug "Command: ${ARGS[*]}"
    echo_debug "Host: $TEST_HOST"
    echo_debug "Port: $TEST_PORT"
fi

# Create pb_data directory if it doesn't exist (unless we're resetting)
if [ "$RESET_DB" = false ]; then
    mkdir -p "$TEST_DIR/pb_data"
fi

# Prepare command with explicit data directory and hooks/migrations paths
PB_CMD=("$PB_BINARY" "${ARGS[@]}" --http "$TEST_HOST:$TEST_PORT" --dir "$TEST_DIR/pb_data")

# Add hooks directory if it exists
if [ -d "$PROJECT_DIR/pb_hooks" ]; then
    PB_CMD+=("--hooksDir" "$PROJECT_DIR/pb_hooks")
fi

# Add migrations directory if it exists
if [ -d "$PROJECT_DIR/pb_migrations" ]; then
    PB_CMD+=("--migrationsDir" "$PROJECT_DIR/pb_migrations")
fi

if [ "$BACKGROUND" = true ]; then
    # Run in background
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Test Server starting in background at http://${TEST_HOST}:${TEST_PORT}"
        echo_info "Admin UI will be available at http://${TEST_HOST}:${TEST_PORT}/_/"
        echo_info "PID will be saved to ${PROJECT_DIR}/test/pocketbase.pid"
        echo_info "Logs will be written to ${TEST_DIR}/pocketbase.log"
    fi
    
    # Create log file for background mode
    LOG_FILE="$TEST_DIR/pocketbase.log"
    
    "${PB_CMD[@]}" </dev/null >"$LOG_FILE" 2>&1 &
    
    PB_PID=$!
    echo $PB_PID > "$PROJECT_DIR/test/pocketbase.pid"
    
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Test Server started with PID: $PB_PID"
        echo_info "To view logs: tail -f ${LOG_FILE}"
    fi
    
    # If --full is specified, wait for server and seed users
    if [ "$FULL_SETUP" = true ]; then
        if [ "$QUIET" = false ]; then
            echo_info "Waiting for server to be ready..."
        fi
        
        # Wait for server to be ready (max 10 seconds)
        for i in {1..20}; do
            if curl -s "http://${TEST_HOST}:${TEST_PORT}/api/health" >/dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
        
        if [ "$QUIET" = false ]; then
            echo_info "Seeding users..."
        fi
        
        # Run seed-users script
        if "$SCRIPT_DIR/seed-users.sh" "test" >/dev/null 2>&1; then
            if [ "$QUIET" = false ]; then
                echo_success "Users seeded successfully"
            fi
        else
            if [ "$QUIET" = false ]; then
                echo_warn "User seeding failed (this is OK if users already exist)"
            fi
        fi
    fi
else
    # Run in foreground
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Test Server starting at http://${TEST_HOST}:${TEST_PORT}"
        echo_info "Admin UI will be available at http://${TEST_HOST}:${TEST_PORT}/_/"
        echo_info "Press Ctrl+C to stop"
        echo ""
    fi
    
    if [ "$QUIET" = true ]; then
        exec "${PB_CMD[@]}" >/dev/null 2>&1
    else
        exec "${PB_CMD[@]}"
    fi
fi