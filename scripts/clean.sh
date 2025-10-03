#!/bin/bash

# PocketBase Environment Cleanup Script
# Safely cleans dev and/or test environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_DIR="$(get_project_dir)"
DEV_DIR="$PROJECT_DIR/dev"
TEST_DIR="$PROJECT_DIR/test"

show_help() {
    echo "PocketBase Environment Cleanup"
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environment:"
    echo "  dev     Clean development environment"
    echo "  test    Clean test environment"
    echo "  all     Clean both environments (default if no environment specified)"
    echo ""
    echo "Options:"
    echo "  --force, -f    Skip confirmation prompts"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Clean dev environment (with confirmation)"
    echo "  $0 test --force          # Clean test environment (no confirmation)"
    echo "  $0 all                   # Clean both environments"
}

clean_environment() {
    local env="$1"
    local env_dir="$2"
    local force="$3"
    
    if [ ! -d "$env_dir" ]; then
        echo_warn "$env environment directory doesn't exist: $env_dir"
        return 0
    fi
    
    # Stop running server first
    echo_info "Stopping $env server if running..."
    stop_pocketbase "$env" || true
    
    # Check what will be cleaned
    local items_to_clean=()
    if [ -d "$env_dir/pb_data" ]; then
        items_to_clean+=("Database files (pb_data/)")
    fi
    if [ -d "$env_dir/pb_hooks" ]; then
        items_to_clean+=("Hook files (pb_hooks/)")
    fi
    if [ -f "$env_dir/pocketbase.pid" ]; then
        items_to_clean+=("PID file")
    fi
    
    # Find any log files
    if ls "$env_dir"/*.log >/dev/null 2>&1; then
        items_to_clean+=("Log files (*.log)")
    fi
    
    if [ ${#items_to_clean[@]} -eq 0 ]; then
        echo_info "$env environment is already clean"
        return 0
    fi
    
    echo_warn "The following will be removed from $env environment:"
    for item in "${items_to_clean[@]}"; do
        echo "  - $item"
    done
    
    if [ "$force" != "true" ]; then
        echo ""
        read -p "Are you sure you want to clean the $env environment? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Cleanup cancelled"
            return 0
        fi
    fi
    
    echo_info "Cleaning $env environment..."
    
    # Remove database and hook files
    if [ -d "$env_dir/pb_data" ]; then
        rm -rf "$env_dir/pb_data"
        echo_success "Removed database files"
    fi
    
    if [ -d "$env_dir/pb_hooks" ]; then
        rm -rf "$env_dir/pb_hooks"
        echo_success "Removed hook files"
    fi
    
    # Remove PID file
    if [ -f "$env_dir/pocketbase.pid" ]; then
        rm -f "$env_dir/pocketbase.pid"
        echo_success "Removed PID file"
    fi
    
    # Remove log files
    if ls "$env_dir"/*.log >/dev/null 2>&1; then
        rm -f "$env_dir"/*.log
        echo_success "Removed log files"
    fi
    
    echo_success "$env environment cleaned successfully"
}

# Parse command line arguments
ENVIRONMENT=""
FORCE=false

if [ $# -eq 0 ]; then
    ENVIRONMENT="all"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|test|all)
            if [ -z "$ENVIRONMENT" ]; then
                ENVIRONMENT="$1"
            else
                echo_error "Multiple environments specified. Use 'all' to clean both."
                exit 1
            fi
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default to all if no environment specified
if [ -z "$ENVIRONMENT" ]; then
    ENVIRONMENT="all"
fi

echo_info "PocketBase Environment Cleanup"
echo_debug "Environment: $ENVIRONMENT"
echo_debug "Force: $FORCE"

case $ENVIRONMENT in
    dev)
        clean_environment "dev" "$DEV_DIR" "$FORCE"
        ;;
    test)
        clean_environment "test" "$TEST_DIR" "$FORCE"
        ;;
    all)
        echo_info "Cleaning all environments..."
        clean_environment "dev" "$DEV_DIR" "$FORCE"
        clean_environment "test" "$TEST_DIR" "$FORCE"
        ;;
    *)
        echo_error "Invalid environment: $ENVIRONMENT"
        show_help
        exit 1
        ;;
esac

echo_success "Cleanup complete!"