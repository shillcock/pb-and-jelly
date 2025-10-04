#!/bin/bash

# Kill all PocketBase processes
# Useful when PID files are missing or processes got orphaned

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

echo_warn "Searching for all PocketBase processes..."

# Find all pocketbase processes
PIDS=$(pgrep -f "pocketbase.*serve" 2>/dev/null || true)

if [ -z "$PIDS" ]; then
    echo_success "No PocketBase processes found"
    
    # Clean up any stale PID files
    PROJECT_DIR="$(get_project_dir)"
    if [ -f "$PROJECT_DIR/dev/pocketbase.pid" ]; then
        echo_info "Removing stale dev PID file"
        rm -f "$PROJECT_DIR/dev/pocketbase.pid"
    fi
    if [ -f "$PROJECT_DIR/test/pocketbase.pid" ]; then
        echo_info "Removing stale test PID file"
        rm -f "$PROJECT_DIR/test/pocketbase.pid"
    fi
    
    exit 0
fi

echo_info "Found PocketBase processes:"
for pid in $PIDS; do
    # Get process info
    PROCESS_INFO=$(ps -p $pid -o pid,command 2>/dev/null | tail -1)
    echo "  PID $pid: $PROCESS_INFO"
done

# Parse force flag
FORCE=false
for arg in "$@"; do
    if [ "$arg" = "--force" ] || [ "$arg" = "-f" ]; then
        FORCE=true
    fi
done

# Confirm unless --force
if [ "$FORCE" = false ]; then
    echo ""
    echo_warn "This will kill ALL PocketBase processes"
    read -p "Continue? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo_info "Cancelled"
        exit 0
    fi
fi

# Kill all processes
echo_info "Killing PocketBase processes..."
for pid in $PIDS; do
    if kill $pid 2>/dev/null; then
        echo_success "Killed process $pid"
    else
        echo_warn "Could not kill process $pid (may require sudo)"
    fi
done

# Wait a moment for processes to terminate
sleep 1

# Force kill any that are still running
REMAINING=$(pgrep -f "pocketbase.*serve" 2>/dev/null || true)
if [ -n "$REMAINING" ]; then
    echo_warn "Some processes still running, forcing kill..."
    for pid in $REMAINING; do
        if kill -9 $pid 2>/dev/null; then
            echo_success "Force killed process $pid"
        else
            echo_error "Could not force kill process $pid (may require sudo)"
        fi
    done
fi

# Clean up PID files
PROJECT_DIR="$(get_project_dir)"
if [ -f "$PROJECT_DIR/dev/pocketbase.pid" ]; then
    echo_info "Removing dev PID file"
    rm -f "$PROJECT_DIR/dev/pocketbase.pid"
fi
if [ -f "$PROJECT_DIR/test/pocketbase.pid" ]; then
    echo_info "Removing test PID file"
    rm -f "$PROJECT_DIR/test/pocketbase.pid"
fi

echo_success "All PocketBase processes terminated"
