#!/bin/bash

# PocketBase User Setup Script
# Creates admin user and test users for dev/test environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load environment variables (will be overridden when environment is parsed)
load_env

# Override with command line values
ENVIRONMENT=""
PB_HOST_OVERRIDE=""
PB_PORT_OVERRIDE=""
ADMIN_EMAIL_OVERRIDE=""
ADMIN_PASSWORD_OVERRIDE=""
TEST_USER_EMAIL_OVERRIDE=""
TEST_USER_PASSWORD_OVERRIDE=""

show_help() {
    echo "PocketBase User Setup"
    echo ""
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environment:"
    echo "  dev     Set up users for development environment (port 8090)"
    echo "  test    Set up users for test environment (port 8091)"
    echo ""
    echo "Options:"
    echo "  --host HOST             PocketBase host (default: 127.0.0.1)"
    echo "  --port PORT             PocketBase port (overrides environment default)"
    echo "  --admin-email EMAIL     Admin email (default: admin@example.com)"
    echo "  --admin-password PASS   Admin password (default: admin123456)"
    echo "  --user-email EMAIL      Test user email (default: user@example.com)"
    echo "  --user-password PASS    Test user password (default: userpass123)"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                                    # Setup users for dev environment"
    echo "  $0 test                                   # Setup users for test environment"
    echo "  $0 dev --admin-email admin@myapp.com     # Custom admin email"
    echo "  $0 test --port 9091                      # Custom port"
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
        --admin-email)
            ADMIN_EMAIL_OVERRIDE="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD_OVERRIDE="$2"
            shift 2
            ;;
        --user-email)
            TEST_USER_EMAIL_OVERRIDE="$2"
            shift 2
            ;;
        --user-password)
            TEST_USER_PASSWORD_OVERRIDE="$2"
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

# Apply overrides to environment variables
[ -n "$PB_HOST_OVERRIDE" ] && PB_HOST="$PB_HOST_OVERRIDE"
[ -n "$ADMIN_EMAIL_OVERRIDE" ] && ADMIN_EMAIL="$ADMIN_EMAIL_OVERRIDE"
[ -n "$ADMIN_PASSWORD_OVERRIDE" ] && ADMIN_PASSWORD="$ADMIN_PASSWORD_OVERRIDE"
[ -n "$TEST_USER_EMAIL_OVERRIDE" ] && USER_EMAIL="$TEST_USER_EMAIL_OVERRIDE"
[ -n "$TEST_USER_PASSWORD_OVERRIDE" ] && USER_PASSWORD="$TEST_USER_PASSWORD_OVERRIDE"

# Load environment-specific configuration now that we know the environment
load_env "$ENVIRONMENT"

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

# Function to wait for PocketBase to be ready
wait_for_pocketbase() {
    local max_attempts=30
    local attempt=1
    
    echo_info "Waiting for PocketBase to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$PB_URL/_/" > /dev/null 2>&1; then
            echo_info "PocketBase is ready!"
            return 0
        fi
        
        echo_debug "Attempt $attempt/$max_attempts - PocketBase not ready yet..."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo_error "PocketBase did not become ready within $max_attempts seconds"
    return 1
}

# Function to create admin user
create_admin_user() {
    echo_info "Creating admin user: $ADMIN_EMAIL"
    
    # Check if admin already exists
    ADMIN_CHECK=$(curl -s "$PB_URL/api/admins" 2>/dev/null || echo "")
    
    if echo "$ADMIN_CHECK" | grep -q '"totalItems":0'; then
        # No admin exists, create one
        RESPONSE=$(curl -s -X POST "$PB_URL/api/admins" \
            -H "Content-Type: application/json" \
            -d "{
                \"email\": \"$ADMIN_EMAIL\",
                \"password\": \"$ADMIN_PASSWORD\",
                \"passwordConfirm\": \"$ADMIN_PASSWORD\"
            }")
        
        if echo "$RESPONSE" | grep -q '"id"'; then
            echo_info "Admin user created successfully"
        else
            echo_warn "Admin user creation response: $RESPONSE"
        fi
    else
        echo_warn "Admin user already exists, skipping creation"
    fi
}

# Function to authenticate as admin and get token
authenticate_admin() {
    echo_debug "Authenticating as admin..."
    
    AUTH_RESPONSE=$(curl -s -X POST "$PB_URL/api/admins/auth-with-password" \
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

# Function to create test user
create_test_user() {
    echo_info "Creating test user: $USER_EMAIL"
    
    # Check if test user already exists
    USER_CHECK=$(curl -s "$PB_URL/api/collections/users/records?filter=(email='$USER_EMAIL')" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
    
    if echo "$USER_CHECK" | grep -q '"totalItems":0'; then
        # Create test user
        USER_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"email\": \"$USER_EMAIL\",
                \"password\": \"$USER_PASSWORD\",
                \"passwordConfirm\": \"$USER_PASSWORD\",
                \"name\": \"Test User\"
            }")
        
        if echo "$USER_RESPONSE" | grep -q '"id"'; then
            echo_info "Test user created successfully"
        else
            echo_warn "Test user creation response: $USER_RESPONSE"
        fi
    else
        echo_warn "Test user already exists, skipping creation"
    fi
}

# Main execution
main() {
    # Wait for PocketBase to be ready
    if ! wait_for_pocketbase; then
        echo_error "PocketBase is not running. Please start it first:"
        echo_info "For dev: ./pb.sh dev start"
        echo_info "For test: ./pb.sh test start"
        exit 1
    fi
    
    # Create admin user
    create_admin_user
    
    # Authenticate as admin
    if ! authenticate_admin; then
        echo_error "Failed to authenticate. Cannot proceed with user setup."
        exit 1
    fi
    
    # Setup users collection
    if ! setup_users_collection; then
        echo_error "Failed to setup users collection"
        exit 1
    fi
    
    # Create test user
    create_test_user
    
    echo_info "User setup complete!"
    echo_info "Admin: $ADMIN_EMAIL / $ADMIN_PASSWORD"
    echo_info "Test User: $USER_EMAIL / $USER_PASSWORD"
    echo_info "Admin UI: ${PB_URL}/_/"
}

main