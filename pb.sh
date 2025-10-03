#!/bin/bash

# PocketBase CLI - Unified command-line interface
# Orchestrates all PocketBase development and testing operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Load environment variables
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
    echo "  <env> setup-users   Set up admin and test users"
    echo "  <env> create-user   Create a new user interactively"
    echo "  <env> clean         Clean environment data"
    echo "  <env> status        Show environment status"
    echo ""
    echo "Global Commands:"
    echo "  install             Download and install PocketBase binary"
    echo "  upgrade             Show available versions and upgrade PocketBase"
    echo "  status              Show status of all environments"
    echo "  stop-all            Stop all running servers"
    echo "  clean-all           Clean all environment data"
    echo ""
    echo "Options (varies by command):"
    echo "  --help, -h          Show help for specific command"
    echo ""
    echo "Examples:"
    echo "  $0 install                      # Download PocketBase"
    echo "  $0 upgrade                      # Show available versions and upgrade"
    echo "  $0 dev start                    # Start dev server"
    echo "  $0 test start --background      # Start test server in background"
    echo "  $0 dev setup-users              # Setup users in dev environment"
    echo "  $0 test stop                    # Stop test server"
    echo "  $0 dev clean --force            # Clean dev environment"
    echo "  $0 status                       # Check all server status"
    echo "  $0 test create-user             # Create user in test environment"
    echo ""
    echo "Configuration Files:"
    echo "  .env.dev, .env.test - Environment-specific settings"
    echo "  .pb-version - Version pinning"
    echo ""
    echo "Current Configuration:"
    echo "  Host: $PB_HOST"
    echo "  PB Version: $PB_VERSION (from .pb-version file)"
    echo "  (Edit .env.dev/.env.test to customize)"
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
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-tools)"
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
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-tools)"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    echo ""
    
    # Check if PocketBase binary exists
    echo -n "PocketBase Binary: "
    if check_pocketbase_binary >/dev/null 2>&1; then
        local pb_binary=$(check_pocketbase_binary)
        local version=$("$pb_binary" --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "${GREEN}Installed${NC} ($version)"
        echo "  Path: $pb_binary"
    else
        echo -e "${RED}Not installed${NC}"
        echo "  Run: $0 install"
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
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-tools)"
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

create_user_interactive() {
    local environment="$1"
    
    if [ "$environment" != "dev" ] && [ "$environment" != "test" ]; then
        echo_error "Invalid environment: $environment. Use 'dev' or 'test'"
        exit 1
    fi
    
    # Load environment-specific configuration
    load_env "$environment"
    local port="$PORT"
    
    local pb_url="http://$PB_HOST:$port"
    
    echo_info "Creating new user in $environment environment"
    echo_debug "PocketBase URL: $pb_url"
    
    # Check if PocketBase is running
    if ! wait_for_pocketbase "$pb_url" 5; then
        echo_error "PocketBase $environment server is not running"
        echo_info "Start it first: $0 $environment start"
        exit 1
    fi
    
    # Get user details interactively
    echo ""
    read -p "Email: " user_email
    read -s -p "Password: " user_password
    echo ""
    read -s -p "Confirm Password: " user_password_confirm
    echo ""
    
    if [ "$user_password" != "$user_password_confirm" ]; then
        echo_error "Passwords don't match"
        exit 1
    fi
    
    read -p "Name (optional): " user_name
    
    # Authenticate as admin first
    echo_info "Authenticating as admin..."
    AUTH_RESPONSE=$(curl -s -X POST "$pb_url/api/admins/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$ADMIN_EMAIL\",
            \"password\": \"$ADMIN_PASSWORD\"
        }")
    
    if ! echo "$AUTH_RESPONSE" | grep -q '"token"'; then
        echo_error "Failed to authenticate as admin. Make sure admin user exists."
        echo_info "Run: $0 $environment setup-users"
        exit 1
    fi
    
    ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    # Create the user
    echo_info "Creating user..."
    USER_DATA="{
        \"email\": \"$user_email\",
        \"password\": \"$user_password\",
        \"passwordConfirm\": \"$user_password\""
    
    if [ -n "$user_name" ]; then
        USER_DATA="$USER_DATA,
        \"name\": \"$user_name\""
    fi
    
    USER_DATA="$USER_DATA
    }"
    
    USER_RESPONSE=$(curl -s -X POST "$pb_url/api/collections/users/records" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$USER_DATA")
    
    if echo "$USER_RESPONSE" | grep -q '"id"'; then
        echo_success "User created successfully!"
        echo_info "Email: $user_email"
        [ -n "$user_name" ] && echo_info "Name: $user_name"
    else
        echo_error "Failed to create user"
        echo_debug "Response: $USER_RESPONSE"
        exit 1
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
        exec "$SCRIPT_DIR/scripts/install-pocketbase.sh" "$@"
        ;;
    upgrade)
        show_upgrade_options
        ;;
    status)
        show_status
        ;;
    stop-all)
        exec "$SCRIPT_DIR/scripts/stop.sh" all "$@"
        ;;
    clean-all)
        exec "$SCRIPT_DIR/scripts/clean.sh" all "$@"
        ;;
    dev|test)
        # Environment-specific commands
        ENVIRONMENT="$FIRST_ARG"
        
        if [ $# -eq 0 ]; then
            echo_error "Command required after environment"
            echo_info "Usage: $0 $ENVIRONMENT <command>"
            echo_info "Available commands: start, stop, setup-users, create-user, clean, status"
            exit 1
        fi
        
        COMMAND="$1"
        shift
        
        case $COMMAND in
            start)
                if [ "$ENVIRONMENT" = "dev" ]; then
                    exec "$SCRIPT_DIR/scripts/pb-dev.sh" "$@"
                else
                    exec "$SCRIPT_DIR/scripts/pb-test.sh" "$@"
                fi
                ;;
            stop)
                exec "$SCRIPT_DIR/scripts/stop.sh" "$ENVIRONMENT" "$@"
                ;;
            setup-users)
                exec "$SCRIPT_DIR/scripts/setup-users.sh" "$ENVIRONMENT" "$@"
                ;;
            create-user)
                create_user_interactive "$ENVIRONMENT"
                ;;
            clean)
                exec "$SCRIPT_DIR/scripts/clean.sh" "$ENVIRONMENT" "$@"
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
                echo "  setup-users   Set up admin and test users"
                echo "  create-user   Create a new user interactively"
                echo "  clean         Clean $ENVIRONMENT environment data"
                echo "  status        Show $ENVIRONMENT environment status"
                echo ""
                echo "Examples:"
                echo "  $0 $ENVIRONMENT start                    # Start server"
                echo "  $0 $ENVIRONMENT start --background       # Start in background (test only)"
                echo "  $0 $ENVIRONMENT setup-users              # Setup users"
                echo "  $0 $ENVIRONMENT clean --force            # Clean without confirmation"
                ;;
            *)
                echo_error "Unknown command for $ENVIRONMENT environment: $COMMAND"
                echo_info "Available commands: start, stop, setup-users, create-user, clean, status"
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
