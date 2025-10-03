#!/bin/bash

# PocketBase User Setup Script
# Creates admin and users from {environment}-users.json seed files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load environment variables (will be overridden when environment is parsed)
load_env

# Override with command line values
ENVIRONMENT=""
PB_HOST_OVERRIDE=""
PB_PORT_OVERRIDE=""

show_help() {
    echo "PocketBase User Seeding"
    echo ""
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environment:"
    echo "  dev     Seed users for development environment (reads dev/dev-users.json)"
    echo "  test    Seed users for test environment (reads test/test-users.json)"
    echo ""
    echo "Behavior:"
    echo "  - Reads {environment}/{environment}-users.json seed file"
    echo "  - Creates admin user from seed file"
    echo "  - Creates all users listed in seed file"
    echo "  - Falls back to .env.{environment} if seed file missing"
    echo "  - Requires 'jq' command to be installed"
    echo ""
    echo "Options:"
    echo "  --host HOST             PocketBase host (default: 127.0.0.1)"
    echo "  --port PORT             PocketBase port (overrides environment default)"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                  # Seed users from dev/dev-users.json"
    echo "  $0 test                 # Seed users from test/test-users.json"
    echo "  $0 dev --port 9090      # Custom port for dev environment"
}

# Parse command line arguments
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

ENVIRONMENT=$1
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            PB_HOST_OVERRIDE="$2"
            shift 2
            ;;
        --port)
            PB_PORT_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Load environment-specific configuration now that we know the environment
load_env "$ENVIRONMENT"

# Apply overrides to environment variables
[ -n "$PB_HOST_OVERRIDE" ] && PB_HOST="$PB_HOST_OVERRIDE"

# Set port based on environment if not overridden
if [ -n "$PB_PORT_OVERRIDE" ]; then
    PB_PORT="$PB_PORT_OVERRIDE"
else
    case $ENVIRONMENT in
        dev|test)
            PB_PORT="$PORT"
            ;;
        *)
            echo_error "Invalid environment: $ENVIRONMENT. Use 'dev' or 'test'"
            exit 1
            ;;
    esac
fi

PB_URL="http://${PB_HOST}:${PB_PORT}"
echo_info "Setting up users for $ENVIRONMENT environment at $PB_URL"

# Check for jq availability
if ! command -v jq >/dev/null 2>&1; then
    echo_error "'jq' command is required but not installed."
    echo_info "Install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    exit 1
fi

# Determine seed file path
PROJECT_DIR="$(get_project_dir)"
SEED_FILE="$PROJECT_DIR/$ENVIRONMENT/${ENVIRONMENT}-users.json"

if [ -f "$SEED_FILE" ]; then
    echo_info "Using seed file: $SEED_FILE"
    # Read admin credentials from seed file
    SEED_ADMIN_EMAIL=$(jq -r '.admin.email // empty' "$SEED_FILE")
    SEED_ADMIN_PASSWORD=$(jq -r '.admin.password // empty' "$SEED_FILE")
    
    if [ -n "$SEED_ADMIN_EMAIL" ] && [ -n "$SEED_ADMIN_PASSWORD" ]; then
        ADMIN_EMAIL="$SEED_ADMIN_EMAIL"
        ADMIN_PASSWORD="$SEED_ADMIN_PASSWORD"
        echo_info "Admin credentials loaded from seed file"
    else
        echo_warn "Seed file missing admin credentials; using .env values"
    fi
else
    echo_warn "No seed file found at $SEED_FILE; using fallback mode with .env credentials"
fi

# Function to create admin user using PocketBase CLI (fallback)
create_admin_user_fallback() {
    echo_info "Creating admin user: $ADMIN_EMAIL (fallback mode)"
    
    # Since we can't check superusers without authentication, just try to create via CLI
    # This is the safer fallback approach
    local project_dir="$(get_project_dir)"
    local env_dir="$project_dir/$ENVIRONMENT"
    local pb_binary
    
    # Check if PocketBase binary exists
    if ! pb_binary=$(check_pocketbase_binary); then
        return 1
    fi
    
    # Use 'superuser upsert' to create or update the admin user
    local result
    result=$(cd "$env_dir" && "$pb_binary" superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASSWORD" --dir="$env_dir/pb_data" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo_success "Admin user ready: $ADMIN_EMAIL (fallback)"
        return 0
    else
        echo_error "Failed to create admin user via CLI: $result"
        return 1
    fi
}

# Function to authenticate as admin and get token
authenticate_admin() {
    echo_debug "Authenticating as admin..."
    
    AUTH_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$ADMIN_EMAIL\",
            \"password\": \"$ADMIN_PASSWORD\"
        }")
    
    if echo "$AUTH_RESPONSE" | grep -q '"token"'; then
        ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        echo_debug "Admin authenticated successfully"
        return 0
    else
        echo_error "Failed to authenticate admin: $AUTH_RESPONSE"
        return 1
    fi
}

# Function to create or ensure users collection exists
setup_users_collection() {
    echo_info "Setting up users collection..."
    
    # Check if users collection exists
    COLLECTIONS=$(curl -s "$PB_URL/api/collections" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
    
    if ! echo "$COLLECTIONS" | grep -q '"name":"users"'; then
        echo_info "Creating users collection..."
        
        CREATE_COLLECTION=$(curl -s -X POST "$PB_URL/api/collections" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "name": "users",
                "type": "auth",
                "schema": [
                    {
                        "name": "name",
                        "type": "text",
                        "required": false
                    },
                    {
                        "name": "avatar",
                        "type": "file",
                        "required": false,
                        "options": {
                            "maxSelect": 1,
                            "maxSize": 5242880,
                            "mimeTypes": ["image/jpeg", "image/png", "image/svg+xml", "image/gif", "image/webp"]
                        }
                    }
                ]
            }')
        
        if echo "$CREATE_COLLECTION" | grep -q '"id"'; then
            echo_info "Users collection created successfully"
        else
            echo_error "Failed to create users collection: $CREATE_COLLECTION"
            return 1
        fi
    else
        echo_debug "Users collection already exists"
    fi
}

# Function to create a single user
create_single_user() {
    local email="$1"
    local password="$2"
    local name="$3"

    if [ -z "$email" ] || [ -z "$password" ]; then
        echo_warn "Skipping user with missing email or password"
        return 0
    fi

    echo_info "Creating user: $email"

    # Check if user already exists
    USER_CHECK=$(curl -s "$PB_URL/api/collections/users/records?filter=(email='$email')" \
        -H "Authorization: Bearer $ADMIN_TOKEN")

    if echo "$USER_CHECK" | grep -q '"totalItems":0'; then
        # Create user
        if [ -n "$name" ]; then
            USER_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
                -H "Authorization: Bearer $ADMIN_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"email\": \"$email\",
                    \"password\": \"$password\",
                    \"passwordConfirm\": \"$password\",
                    \"name\": \"$name\"
                }")
        else
            USER_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
                -H "Authorization: Bearer $ADMIN_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"email\": \"$email\",
                    \"password\": \"$password\",
                    \"passwordConfirm\": \"$password\"
                }")
        fi

        if echo "$USER_RESPONSE" | grep -q '"id"'; then
            echo_success "User created: $email"
        else
            echo_warn "User creation failed for $email: $USER_RESPONSE"
        fi
    else
        echo_debug "User already exists: $email"
    fi
}

# Function to create users from seed file
create_users_from_seed() {
    local users_count=$(jq '.users | length' "$SEED_FILE" 2>/dev/null || echo 0)
    
    if [ "$users_count" -gt 0 ]; then
        echo_info "Creating $users_count users from seed file..."
        
        for i in $(seq 0 $((users_count - 1))); do
            local email=$(jq -r ".users[$i].email // empty" "$SEED_FILE")
            local password=$(jq -r ".users[$i].password // empty" "$SEED_FILE")
            local name=$(jq -r ".users[$i].name // empty" "$SEED_FILE")
            
            create_single_user "$email" "$password" "$name"
        done
    else
        echo_warn "No users defined in seed file"
    fi
}

# Function to create admin user from seed file using CLI
create_admin_from_seed() {
    echo_info "Creating admin user from seed file: $ADMIN_EMAIL"
    
    local project_dir="$(get_project_dir)"
    local env_dir="$project_dir/$ENVIRONMENT"
    local pb_binary
    
    # Check if PocketBase binary exists
    if ! pb_binary=$(check_pocketbase_binary); then
        return 1
    fi
    
    # Create environment directory if it doesn't exist
    mkdir -p "$env_dir/pb_data"
    
    # Use 'superuser upsert' to create or update the admin user
    # This command works even when the server is running
    local result
    result=$(cd "$env_dir" && "$pb_binary" superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASSWORD" --dir="$env_dir/pb_data" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo_success "Admin user ready: $ADMIN_EMAIL"
        return 0
    else
        echo_error "Failed to create admin user: $result"
        return 1
    fi
}

# Main execution
main() {
    # Wait for PocketBase to be ready
    if ! wait_for_pocketbase "$PB_URL" 30; then
        echo_error "PocketBase is not running. Please start it first:"
        echo_info "For dev: ./pb.sh dev start"
        echo_info "For test: ./pb.sh test start"
        exit 1
    fi

    # Create admin user based on mode
    if [ -f "$SEED_FILE" ]; then
        # Create admin from seed file
        if ! create_admin_from_seed; then
            echo_error "Failed to create admin from seed file"
            exit 1
        fi
    else
        # Fallback mode - create admin via API
        create_admin_user_fallback
    fi

    # Authenticate as admin
    if ! authenticate_admin; then
        echo_error "Failed to authenticate as admin."
        echo_info "Make sure admin user exists with correct credentials."
        exit 1
    fi

    # Setup users collection
    if ! setup_users_collection; then
        echo_error "Failed to setup users collection"
        exit 1
    fi

    # Create users based on mode
    if [ -f "$SEED_FILE" ]; then
        create_users_from_seed
        echo_success "Users created from seed file: $SEED_FILE"
    else
        # Fallback to single test user
        create_single_user "$USER_EMAIL" "$USER_PASSWORD" "Test User"
        echo_success "Fallback test user created: $USER_EMAIL"
    fi

    echo_info "Admin UI: ${PB_URL}/_/"
}

main
