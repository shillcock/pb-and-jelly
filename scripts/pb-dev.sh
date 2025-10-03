#!/bin/bash

# PocketBase Development Environment Launcher
# Launches PocketBase using the dev/ directory as working directory
#
# NOTE: Most users should use './pb.sh dev start' instead of running this directly.
# This script is primarily used internally by pb.sh and for advanced/automation use cases.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load environment variables
load_env "dev"

PROJECT_DIR="$(get_project_dir)"
DEV_DIR="$PROJECT_DIR/dev"

# Check if PocketBase binary exists
PB_BINARY=$(check_pocketbase_binary)

# Create dev directory if it doesn't exist
mkdir -p "$DEV_DIR"

# Use environment variables for defaults
DEV_PORT="$PORT"
DEV_HOST="$PB_HOST"

# Override echo functions for dev context
echo_info() {
    echo -e "${GREEN}[DEV]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[DEV]${NC} $1"
}

echo_error() {
    echo -e "${RED}[DEV]${NC} $1"
}

echo_debug() {
    echo -e "${BLUE}[DEV]${NC} $1"
}

# Parse command line arguments
ARGS=()
BACKGROUND=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            DEV_PORT="$2"
            shift 2
            ;;
        --host)
            DEV_HOST="$2"
            shift 2
            ;;
        --background|-bg)
            BACKGROUND=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --help|-h)
            echo "PocketBase Development Environment"
            echo ""
            echo "Usage: $0 [options] [pocketbase-args...]"
            echo ""
            echo "Options:"
            echo "  --port PORT        Set port (default: 8090)"
            echo "  --host HOST        Set host (default: 127.0.0.1)"
            echo "  --background, -bg  Run in background"
            echo "  --quiet, -q       Suppress output (useful for automation)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Any additional arguments will be passed directly to PocketBase"
            echo ""
            echo "Examples:"
            echo "  $0                           # Start with defaults"
            echo "  $0 --port 9090             # Start on port 9090"
            echo "  $0 --host 0.0.0.0          # Listen on all interfaces"
            echo "  $0 --background             # Start in background"
            echo "  $0 serve --dev             # Pass --dev flag to PocketBase"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Default to 'serve' command if no command specified
if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=("serve")
fi

if [ "$QUIET" = false ]; then
    echo_info "Starting PocketBase Development Environment"
    echo_debug "Working directory: $DEV_DIR"
    echo_debug "Binary: $PB_BINARY"
    echo_debug "Host: $DEV_HOST"
    echo_debug "Port: $DEV_PORT"
    echo_debug "Command: ${ARGS[*]}"
    echo_debug "Background: $BACKGROUND"
fi

# Create pb_data directory if it doesn't exist
mkdir -p "$DEV_DIR/pb_data"

# Prepare command with explicit data directory
PB_CMD=("$PB_BINARY" "${ARGS[@]}" --http="${DEV_HOST}:${DEV_PORT}" --dir="$DEV_DIR/pb_data")

if [ "$BACKGROUND" = true ]; then
    # Run in background
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Dev Server starting in background at http://${DEV_HOST}:${DEV_PORT}"
        echo_info "Admin UI will be available at http://${DEV_HOST}:${DEV_PORT}/_/"
        echo_info "PID will be saved to ${PROJECT_DIR}/dev/pocketbase.pid"
        echo_info "Logs will be written to ${DEV_DIR}/pocketbase.log"
    fi
    
    # Create log file for background mode
    LOG_FILE="$DEV_DIR/pocketbase.log"
    
    if [ "$QUIET" = true ]; then
        "${PB_CMD[@]}" </dev/null >"$LOG_FILE" 2>&1 &
    else
        "${PB_CMD[@]}" </dev/null >"$LOG_FILE" 2>&1 &
    fi
    
    PB_PID=$!
    echo $PB_PID > "$PROJECT_DIR/dev/pocketbase.pid"
    
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Dev Server started with PID: $PB_PID"
        echo_info "To view logs: tail -f ${LOG_FILE}"
    fi
else
    # Run in foreground
    if [ "$QUIET" = false ]; then
        echo_info "PocketBase Dev Server starting at http://${DEV_HOST}:${DEV_PORT}"
        echo_info "Admin UI will be available at http://${DEV_HOST}:${DEV_PORT}/_/"
        echo_info "Press Ctrl+C to stop"
        echo ""
    fi
    
    if [ "$QUIET" = true ]; then
        exec "${PB_CMD[@]}" >/dev/null 2>&1
    else
        exec "${PB_CMD[@]}"
    fi
fi
