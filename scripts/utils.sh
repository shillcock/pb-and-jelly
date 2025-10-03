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

# Read PocketBase version from .pb-version file
get_pb_version() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local project_dir="$script_dir"
    
    # Find project root by looking for .pb-version or pb.sh
    while [ "$project_dir" != "/" ] && [ ! -f "$project_dir/.pb-version" ] && [ ! -f "$project_dir/pb.sh" ]; do
        project_dir="$(dirname "$project_dir")"
    done
    
    local version_file="$project_dir/.pb-version"
    if [ -f "$version_file" ]; then
        # Read version and trim whitespace
        local version=$(cat "$version_file" | tr -d '\n\r\t ' | head -1)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback to default version
    echo "0.30.0"
}

# Set environment variables with hardcoded values per environment
load_env() {
    local environment="$1"
    
    # Set environment-specific values
    case "$environment" in
        dev)
            export PORT="8090"
            export PB_HOST="127.0.0.1"
            # Fallback user credentials (used only if no seed file)
            export USER_EMAIL="dev-user@example.com"
            export USER_PASSWORD="devpass123"
            ;;
        test)
            export PORT="8091"
            export PB_HOST="127.0.0.1"
            # Fallback user credentials (used only if no seed file)
            export USER_EMAIL="test-user@example.com"
            export USER_PASSWORD="test-pass123"
            ;;
        *)
            # Default values (for when no environment specified)
            export PORT="8090"
            export PB_HOST="127.0.0.1"
            export USER_EMAIL="user@example.com"
            export USER_PASSWORD="userpass123"
            ;;
    esac
    
    # Get PB version from .pb-version file
    export PB_VERSION="$(get_pb_version)"
}

# Get project directory
get_project_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$script_dir"
    
    # Find project root by looking for pb.sh script
    while [ "$project_dir" != "/" ] && [ ! -f "$project_dir/pb.sh" ]; do
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

# Fetch available PocketBase versions from GitHub API
fetch_available_versions() {
    local max_versions="${1:-10}"
    
    # Get releases from GitHub API (suppress debug during this call)
    local releases=$(curl -s "https://api.github.com/repos/pocketbase/pocketbase/releases?per_page=$max_versions")
    
    if [ $? -ne 0 ]; then
        echo_error "Failed to fetch version information from GitHub" >&2
        return 1
    fi
    
    # Extract version numbers (remove 'v' prefix) - output to stdout only
    echo "$releases" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//'
}

# Get current installed PocketBase version
get_current_version() {
    local project_dir="$(get_project_dir)"
    local pb_binary="$project_dir/bin/pocketbase"
    
    if [ -f "$pb_binary" ]; then
        "$pb_binary" --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1
    else
        echo "not_installed"
    fi
}

# Compare version strings (returns 0 if v1 < v2, 1 if v1 >= v2)
version_less_than() {
    local v1="$1"
    local v2="$2"
    
    # Use sort -V for version sorting
    if [ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ] && [ "$v1" != "$v2" ]; then
        return 0  # v1 < v2
    else
        return 1  # v1 >= v2
    fi
}

# Setup admin user using PocketBase CLI (works without server running)
# Reads admin credentials from JSON seed file, falls back to hardcoded values
setup_admin_user() {
    local environment="$1"
    local quiet="${2:-false}"
    
    if [ "$environment" != "dev" ] && [ "$environment" != "test" ]; then
        echo_error "Invalid environment: $environment. Use 'dev' or 'test'"
        return 1
    fi
    
    local project_dir="$(get_project_dir)"
    local seed_file="$project_dir/$environment/${environment}-users.json"
    
    # Try to read admin credentials from seed file first
    local admin_email admin_password
    if [ -f "$seed_file" ] && command -v jq >/dev/null 2>&1; then
        local seed_admin_email=$(jq -r '.admin.email // empty' "$seed_file" 2>/dev/null)
        local seed_admin_password=$(jq -r '.admin.password // empty' "$seed_file" 2>/dev/null)
        
        if [ -n "$seed_admin_email" ] && [ -n "$seed_admin_password" ]; then
            admin_email="$seed_admin_email"
            admin_password="$seed_admin_password"
            if [ "$quiet" = false ]; then
                echo_debug "Admin credentials loaded from seed file: $seed_file"
            fi
        else
            if [ "$quiet" = false ]; then
                echo_warn "Seed file found but missing admin credentials, using fallback"
            fi
        fi
    fi
    
    # Set hardcoded fallback admin credentials if not loaded from seed file
    if [ -z "$admin_email" ] || [ -z "$admin_password" ]; then
        case "$environment" in
            dev)
                admin_email="admin@example.com"
                admin_password="admin123456"
                ;;
            test)
                admin_email="test-admin@example.com"
                admin_password="test-admin123"
                ;;
        esac
        if [ "$quiet" = false ]; then
            echo_debug "Using hardcoded fallback admin credentials"
        fi
    fi
    
    local env_dir="$project_dir/$environment"
    local pb_binary
    
    # Check if PocketBase binary exists
    if ! pb_binary=$(check_pocketbase_binary); then
        return 1
    fi
    
    # Create environment directory if it doesn't exist
    mkdir -p "$env_dir/pb_data"
    
    # Check if admin already exists by trying to create with --upsert flag
    if [ "$quiet" = false ]; then
        case $environment in
            dev)
                echo_info "[DEV] Setting up admin user: $admin_email"
                ;;
            test)
                echo_info "[TEST] Setting up admin user: $admin_email"
                ;;
        esac
    fi
    
    # Use 'superuser upsert' to create or update the admin user
    # This command works even when the server isn't running
    local result
    result=$(cd "$env_dir" && "$pb_binary" superuser upsert "$admin_email" "$admin_password" --dir="$env_dir/pb_data" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if [ "$quiet" = false ]; then
            case $environment in
                dev)
                    echo_success "[DEV] Admin user ready: $admin_email"
                    ;;
                test)
                    echo_success "[TEST] Admin user ready: $admin_email"
                    ;;
            esac
        fi
        return 0
    else
        case $environment in
            dev)
                echo_error "[DEV] Failed to setup admin user: $result"
                ;;
            test)
                echo_error "[TEST] Failed to setup admin user: $result"
                ;;
        esac
        return 1
    fi
}
