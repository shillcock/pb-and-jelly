#!/bin/bash

# PocketBase CLI - Unified command-line interface
# Orchestrates all PocketBase development and testing operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check that PB_PROJECT_DIR is set (must be called via project wrapper)
if [ -z "$PB_PROJECT_DIR" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
    echo "Error: This script must be called via project wrapper script"
    echo ""
    echo "To use pb-and-jelly:"
    echo "  1. Initialize pb-and-jelly in your project:"
    echo "     cd /path/to/your-project"
    echo "     $SCRIPT_DIR/init-project.sh ."
    echo ""
    echo "  2. Use the project wrapper:"
    echo "     cd /path/to/your-project/pocketbase"
    echo "     ./pb.sh <command>"
    exit 1
fi

# Load utils
source "$SCRIPT_DIR/utils.sh"
# Load environment for help display
load_env

show_help() {
    echo "PocketBase Development CLI"
    echo ""
    echo "Usage: $0 <environment> <command> [options]"
    echo "       $0 <global-command> [options]"
    echo ""
    echo "Environment Commands:"
    echo "  <env> start         Start server (env: dev|test)"
    echo "  <env> stop          Stop server"
    echo "  <env> setup         Set up admin user (without running server)"
    echo "  <env> seed-users    Seed users from JSON file"
    echo "  <env> clean         Clean environment data"
    echo "  <env> status        Show environment status"
    echo "Global Commands:"
    echo "  install             Download and install PocketBase binary"
    echo "  upgrade             Show available versions and upgrade PocketBase"
    echo "  status              Show status of all environments"
    echo "  stop-all            Stop all running servers"
    echo "  kill-all            Force kill all PocketBase processes"
    echo "  clean-all           Clean all environment data"
    echo ""
    echo "Options (varies by command):"
    echo "  --help, -h          Show help for specific command"
    echo ""
    echo "Examples:"
    echo "  $0 install                      # Download PocketBase"
    echo "  $0 upgrade                      # Show available versions and upgrade"
    echo "  $0 dev start                    # Start dev server"
    echo "  $0 test start --quiet --reset   # Start test server with clean DB"
    echo "  ./pb.sh dev seed-users               # Seed users in dev environment"
    echo "  $0 test stop                    # Stop test server"
    echo "  $0 dev clean --force            # Clean dev environment"
    echo "  $0 status                       # Check all server status"
    echo ""
    echo "Configuration Files:"
    echo "  .pb-version - Version pinning"
    echo "  {env}/{env}-users.json - User seed files (optional)"
    echo ""
    echo "Environment Settings:"
    echo "  Dev: Port 8090, Host 127.0.0.1"
    echo "  Test: Port 8091, Host 127.0.0.1"
    echo "  PB Version: $PB_VERSION (from .pb-version file)"
}

show_status() {
    echo_info "PocketBase Server Status"
    echo ""
    
    local project_dir="$(get_project_dir)"
    
    # Load dev environment to get dev port
    load_env "dev"
    local dev_port="$PORT"
    
    # Check dev server
    echo -n "Development Server (port $dev_port): "
    local dev_pid=$(get_pid_from_file "$project_dir/dev/pocketbase.pid" 2>/dev/null || echo "")
    if [ -n "$dev_pid" ]; then
        echo -e "${GREEN}Running${NC} (PID: $dev_pid)"
        echo "  URL: http://$PB_HOST:$dev_port"
        echo "  Admin UI: http://$PB_HOST:$dev_port/_/"
    elif check_port "$dev_port"; then
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-and-jelly)"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    echo ""
    
    # Load test environment to get test port
    load_env "test"
    local test_port="$PORT"
    
    # Check test server
    echo -n "Test Server (port $test_port): "
    local test_pid=$(get_pid_from_file "$project_dir/test/pocketbase.pid" 2>/dev/null || echo "")
    if [ -n "$test_pid" ]; then
        echo -e "${GREEN}Running${NC} (PID: $test_pid)"
        echo "  URL: http://$PB_HOST:$test_port"
        echo "  Admin UI: http://$PB_HOST:$test_port/_/"
    elif check_port "$test_port"; then
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-and-jelly)"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    echo ""
    
    # Check if PocketBase binary exists
    echo -n "PocketBase Binary: "
    if check_pocketbase_binary >/dev/null 2>&1; then
        local pb_binary=$(check_pocketbase_binary)
        local version=$("$pb_binary" --version 2>/dev/null | head -1 || echo "unknown")
        
        if [[ "$pb_binary" == *"/bin/pocketbase" ]]; then
            echo -e "${GREEN}Installed (local)${NC} ($version)"
        else
            echo -e "${GREEN}Installed (global)${NC} ($version)"
        fi
        echo "  Path: $pb_binary"
    else
        echo -e "${RED}Not installed${NC}"
        echo "  Run: $0 install (or install globally)"
    fi
}

show_env_status() {
    local environment="$1"
    local project_dir="$(get_project_dir)"
    
    if [ "$environment" != "dev" ] && [ "$environment" != "test" ]; then
        echo_error "Invalid environment: $environment. Use 'dev' or 'test'"
        exit 1
    fi
    
    # Load environment-specific configuration
    load_env "$environment"
    local port="$PORT"
    
    local env_name
    case $environment in
        dev)
            env_name="Development"
            ;;
        test)
            env_name="Test"
            ;;
    esac
    
    echo_info "$env_name Environment Status"
    echo ""
    
    echo -n "$env_name Server (port $port): "
    local pid=$(get_pid_from_file "$project_dir/$environment/pocketbase.pid" 2>/dev/null || echo "")
    if [ -n "$pid" ]; then
        echo -e "${GREEN}Running${NC} (PID: $pid)"
        echo "  URL: http://$PB_HOST:$port"
        echo "  Admin UI: http://$PB_HOST:$port/_/"
        echo "  Data Directory: $project_dir/$environment/pb_data"
    elif check_port "$port"; then
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-and-jelly)"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    echo ""
    
    # Show data directory info
    if [ -d "$project_dir/$environment/pb_data" ]; then
        local db_size=$(du -sh "$project_dir/$environment/pb_data" 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "Database: ${GREEN}Exists${NC} ($db_size)"
    else
        echo -e "Database: ${YELLOW}Not initialized${NC}"
    fi
}


show_upgrade_options() {
    echo_info "PocketBase Version Management"
    echo ""
    
    # Get current version
    local current_version=$(get_current_version)
    local pinned_version="$PB_VERSION"
    
    echo "Current Configuration:"
    if [ "$current_version" = "not_installed" ]; then
        echo "  Installed Version: Not installed"
    else
        echo "  Installed Version: $current_version"
    fi
    echo "  Pinned Version: $pinned_version (from .pb-version file)"
    echo ""
    
    # Fetch available versions
    echo_info "Fetching available versions from GitHub..."
    local versions=$(fetch_available_versions 15)
    
    if [ $? -ne 0 ] || [ -z "$versions" ]; then
        echo_error "Failed to fetch version information"
        return 1
    fi
    
    echo "Available versions (showing last 15):"
    local count=1
    echo "$versions" | while read -r version; do
        if [ -n "$version" ]; then
            local status=""
            if [ "$version" = "$pinned_version" ]; then
                status=" (pinned)"
            fi
            if [ "$version" = "$current_version" ]; then
                status="$status (installed)"
            fi
            echo "  $count. $version$status"
            count=$((count + 1))
        fi
    done
    
    echo ""
    echo "Upgrade Options:"
    echo "  1. Update .pb-version file to pin a different version, then run './pb.sh install'"
    echo "  2. Check latest releases: https://github.com/pocketbase/pocketbase/releases"
    echo ""
    
    # Show upgrade recommendation
    if [ "$current_version" != "not_installed" ] && [ "$current_version" != "$pinned_version" ]; then
        if version_less_than "$current_version" "$pinned_version"; then
            echo_warn "Your installed version ($current_version) is older than pinned version ($pinned_version)"
            echo_info "Run './pb.sh install' to upgrade to the pinned version"
        else
            echo_warn "Your installed version ($current_version) is newer than pinned version ($pinned_version)"
            echo_info "Consider updating the version in .pb-version file to match your installed version"
        fi
        echo ""
    fi
    
    # Show latest version info
    local latest_version=$(echo "$versions" | head -1)
    if [ -n "$latest_version" ] && [ "$latest_version" != "$pinned_version" ]; then
        if version_less_than "$pinned_version" "$latest_version"; then
            echo_info "Latest version available: $latest_version"
            echo_info "To upgrade: Update .pb-version to $latest_version, then run './pb.sh install'"
        fi
    fi
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Check for help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

FIRST_ARG="$1"
shift

# Handle global commands (no environment specified)
case $FIRST_ARG in
    install)
        exec "$SCRIPT_DIR/install-pocketbase.sh" "$@"
        ;;
    upgrade)
        show_upgrade_options
        ;;
    status)
        show_status
        ;;
    stop-all)
        exec "$SCRIPT_DIR/stop.sh" all "$@"
        ;;
    kill-all)
        exec "$SCRIPT_DIR/kill-all.sh" "$@"
        ;;
    clean-all)
        exec "$SCRIPT_DIR/clean.sh" all "$@"
        ;;
    dev|test)
        # Environment-specific commands
        ENVIRONMENT="$FIRST_ARG"
        
        if [ $# -eq 0 ]; then
            echo_error "Command required after environment"
            echo_info "Usage: $0 $ENVIRONMENT <command>"
            echo_info "Available commands: start, stop, setup, seed-users, clean, status"
            exit 1
        fi
        
        COMMAND="$1"
        shift
        
        case $COMMAND in
            start)
                if [ "$ENVIRONMENT" = "dev" ]; then
                    exec "$SCRIPT_DIR/pb-dev.sh" "$@"
                else
                    exec "$SCRIPT_DIR/pb-test.sh" "$@"
                fi
                ;;
            stop)
                exec "$SCRIPT_DIR/stop.sh" "$ENVIRONMENT" "$@"
                ;;
            setup)
                # Load environment-specific configuration and setup admin
                load_env "$ENVIRONMENT"
                if setup_admin_user "$ENVIRONMENT" false; then
                    echo_success "Admin setup complete for $ENVIRONMENT environment"
                    echo_info "Admin: $SETUP_ADMIN_EMAIL / $SETUP_ADMIN_PASSWORD"
                else
                    exit 1
                fi
                ;;
            seed-users)
                exec "$SCRIPT_DIR/seed-users.sh" "$ENVIRONMENT" "$@"
                ;;
            clean)
                exec "$SCRIPT_DIR/clean.sh" "$ENVIRONMENT" "$@"
                ;;
            clean-data)
                exec "$SCRIPT_DIR/clean-data.sh" "$ENVIRONMENT" "$@"
                ;;
            reset)
                # Only available for test environment
                if [ "$ENVIRONMENT" != "test" ]; then
                    echo_error "reset command is only available for test environment"
                    exit 1
                fi
                # Stop then clean (pass --force flag if provided)
                "$SCRIPT_DIR/stop.sh" "$ENVIRONMENT"
                "$SCRIPT_DIR/clean.sh" "$ENVIRONMENT" "$@"
                echo_success "Test environment reset complete"
                ;;
            status)
                show_env_status "$ENVIRONMENT"
                ;;
            --help|-h)
                echo "$ENVIRONMENT Environment Commands:"
                echo ""
                echo "Usage: $0 $ENVIRONMENT <command> [options]"
                echo ""
                echo "Commands:"
                echo "  start         Start $ENVIRONMENT server"
                echo "  stop          Stop $ENVIRONMENT server"
                echo "  setup         Set up admin user (without running server)"
                echo "  seed-users    Seed users from JSON file"
                echo "  clean         Clean $ENVIRONMENT environment data"
                echo "  clean-data    Fast data cleanup (keeps server running)"
                if [ "$ENVIRONMENT" = "test" ]; then
                    echo "  reset         Stop and clean test environment"
                fi
                echo "  status        Show $ENVIRONMENT environment status"
                echo "Examples:"
                echo "  $0 $ENVIRONMENT start                    # Start server"
                if [ "$ENVIRONMENT" = "test" ]; then
                    echo "  $0 $ENVIRONMENT start --full --quiet     # Full setup for testing"
                    echo "  $0 $ENVIRONMENT start --quiet --reset    # Start with clean DB"
                    echo "  $0 $ENVIRONMENT reset --force            # Stop and clean"
                else
                    echo "  $0 $ENVIRONMENT start --quiet            # Start in quiet mode"
                fi
                echo "  $0 $ENVIRONMENT setup                    # Setup admin user first"
                echo "  $0 $ENVIRONMENT seed-users               # Seed users from JSON"
                echo "  $0 $ENVIRONMENT clean-data               # Fast cleanup (keeps server running)"
                echo "  $0 $ENVIRONMENT clean --force            # Clean without confirmation"
                ;;
            *)
                echo_error "Unknown command for $ENVIRONMENT environment: $COMMAND"
                echo_info "Available commands: start, stop, setup, seed-users, clean, status"
                echo_info "Use '$0 $ENVIRONMENT --help' for more information"
                exit 1
                ;;
        esac
        ;;
    *)
        echo_error "Unknown command or environment: $FIRST_ARG"
        echo_info "Available environments: dev, test"
        echo_info "Available global commands: install, upgrade, status, stop-all, clean-all"
        echo_info "Use '$0 --help' for more information"
        exit 1
        ;;
esac
