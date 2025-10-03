#!/bin/bash

# Shared utilities for PocketBase scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

echo_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Load environment variables from .env.local
load_env() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local project_dir
    
    # Find project root by looking for .env.local
    project_dir="$script_dir"
    while [ "$project_dir" != "/" ] && [ ! -f "$project_dir/.env.local" ]; do
        project_dir="$(dirname "$project_dir")"
    done
    
    local env_file="$project_dir/.env.local"
    
    if [ -f "$env_file" ]; then
        echo_debug "Loading environment from $env_file"
        # Export variables from .env.local, skipping comments and empty lines
        set -a
        source "$env_file"
        set +a
    else
        echo_warn "No .env.local file found. Using defaults."
        echo_info "Copy .env.example to .env.local and customize it."
    fi
    
    # Set defaults if not provided
    export ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
    export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123456}"
    export TEST_USER_EMAIL="${TEST_USER_EMAIL:-test@example.com}"
    export TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-testpass123}"
    export DEV_PORT="${DEV_PORT:-8090}"
    export TEST_PORT="${TEST_PORT:-8091}"
    export PB_HOST="${PB_HOST:-127.0.0.1}"
}

# Get project directory
get_project_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local project_dir="$script_dir"
    
    # Find project root by looking for .env.example or pb-cli script
    while [ "$project_dir" != "/" ] && [ ! -f "$project_dir/.env.example" ] && [ ! -f "$project_dir/pb-cli" ]; do
        project_dir="$(dirname "$project_dir")"
    done
    
    if [ "$project_dir" = "/" ]; then
        echo_error "Could not find project root directory"
        exit 1
    fi
    
    echo "$project_dir"
}

# Check if PocketBase binary exists
check_pocketbase_binary() {
    local project_dir="$(get_project_dir)"
    local pb_binary="$project_dir/bin/pocketbase"
    
    if [ ! -f "$pb_binary" ]; then
        echo_error "PocketBase binary not found at $pb_binary"
        echo_info "Run './scripts/install-pocketbase.sh' to download PocketBase"
        return 1
    fi
    
    echo "$pb_binary"
}

# Wait for PocketBase to be ready
wait_for_pocketbase() {
    local url="$1"
    local max_attempts="${2:-30}"
    local attempt=1
    
    echo_debug "Waiting for PocketBase at $url to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url/_/" > /dev/null 2>&1; then
            echo_debug "PocketBase is ready!"
            return 0
        fi
        
        if [ $((attempt % 5)) -eq 0 ]; then
            echo_debug "Attempt $attempt/$max_attempts - PocketBase not ready yet..."
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo_error "PocketBase did not become ready within $max_attempts seconds"
    return 1
}

# Check if a port is in use
check_port() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Get PID from PID file
get_pid_from_file() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        # Check if PID is valid and process exists
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        else
            # Clean up stale PID file
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Stop PocketBase process
stop_pocketbase() {
    local environment="$1"
    local project_dir="$(get_project_dir)"
    local pid_file="$project_dir/$environment/pocketbase.pid"
    
    local pid=$(get_pid_from_file "$pid_file")
    if [ -n "$pid" ]; then
        echo_info "Stopping PocketBase $environment server (PID: $pid)..."
        if kill "$pid" 2>/dev/null; then
            # Wait for process to stop
            local attempts=0
            while kill -0 "$pid" 2>/dev/null && [ $attempts -lt 10 ]; do
                sleep 1
                attempts=$((attempts + 1))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                echo_warn "Process didn't stop gracefully, forcing..."
                kill -9 "$pid" 2>/dev/null
            fi
            
            rm -f "$pid_file"
            echo_success "PocketBase $environment server stopped"
            return 0
        else
            echo_error "Failed to stop PocketBase process"
            rm -f "$pid_file"
            return 1
        fi
    else
        echo_warn "No running PocketBase $environment server found"
        return 1
    fi
}