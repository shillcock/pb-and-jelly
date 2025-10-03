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
    echo "  status              Show status of all environments"
    echo "  stop-all            Stop all running servers"
    echo "  clean-all           Clean all environment data"
    echo ""
    echo "Options (varies by command):"
    echo "  --help, -h          Show help for specific command"
    echo ""
    echo "Examples:"
    echo "  $0 install                      # Download PocketBase"
    echo "  $0 dev start                    # Start dev server"
    echo "  $0 test start --background      # Start test server in background"
    echo "  $0 dev setup-users              # Setup users in dev environment"
    echo "  $0 test stop                    # Stop test server"
    echo "  $0 dev clean --force            # Clean dev environment"
    echo "  $0 status                       # Check all server status"
    echo "  $0 test create-user             # Create user in test environment"
    echo ""
    echo "Environment Configuration:"
    echo "  Configuration is loaded from .env.local"
    echo "  Copy .env.example to .env.local and customize"
    echo ""
    echo "Current Configuration:"
    echo "  Admin Email: $ADMIN_EMAIL"
    echo "  Test User Email: $TEST_USER_EMAIL"
    echo "  Dev Port: $DEV_PORT"
    echo "  Test Port: $TEST_PORT"
    echo "  Host: $PB_HOST"
}

show_status() {
    echo_info "PocketBase Server Status"
    echo ""
    
    local project_dir="$(get_project_dir)"
    
    # Check dev server
    echo -n "Development Server (port $DEV_PORT): "
    local dev_pid=$(get_pid_from_file "$project_dir/dev/pocketbase.pid" 2>/dev/null || echo "")
    if [ -n "$dev_pid" ]; then
        echo -e "${GREEN}Running${NC} (PID: $dev_pid)"
        echo "  URL: http://$PB_HOST:$DEV_PORT"
        echo "  Admin UI: http://$PB_HOST:$DEV_PORT/_/"
    elif check_port "$DEV_PORT"; then
        echo -e "${YELLOW}Port in use${NC} (not managed by pb-tools)"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    echo ""
    
    # Check test server
    echo -n "Test Server (port $TEST_PORT): "
    local test_pid=$(get_pid_from_file "$project_dir/test/pocketbase.pid" 2>/dev/null || echo "")
    if [ -n "$test_pid" ]; then
        echo -e "${GREEN}Running${NC} (PID: $test_pid)"
        echo "  URL: http://$PB_HOST:$TEST_PORT"
        echo "  Admin UI: http://$PB_HOST:$TEST_PORT/_/"
    elif check_port "$TEST_PORT"; then
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
    
    local port
    local env_name
    case $environment in
        dev)
            port="$DEV_PORT"
            env_name="Development"
            ;;
        test)
            port="$TEST_PORT"
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
    
    local port
    case $environment in
        dev) port="$DEV_PORT" ;;
        test) port="$TEST_PORT" ;;
    esac
    
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
        echo_info "Available global commands: install, status, stop-all, clean-all"
        echo_info "Use '$0 --help' for more information"
        exit 1
        ;;
esac
