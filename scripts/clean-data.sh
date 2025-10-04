#!/bin/bash

# Clean PocketBase collection data via API (keeps server running)
# This is a fast cleanup method for between-test data reset

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Check environment argument
ENVIRONMENT="${1:-test}"

if [ "$ENVIRONMENT" != "test" ] && [ "$ENVIRONMENT" != "dev" ]; then
    echo_error "Invalid environment: $ENVIRONMENT"
    echo_error "Usage: $0 <environment>"
    echo_error "Environment must be 'dev' or 'test'"
    exit 1
fi

# Load environment configuration
load_env "$ENVIRONMENT"

PROJECT_DIR="$(get_project_dir)"
PB_URL="http://${PB_HOST}:${PORT}"

echo_info "Cleaning data for $ENVIRONMENT environment..."
echo_debug "PocketBase URL: $PB_URL"

# Check if server is running
if ! curl -s "${PB_URL}/api/health" >/dev/null 2>&1; then
    echo_error "PocketBase server is not running at $PB_URL"
    echo_error "Start it first with: ./pb.sh $ENVIRONMENT start"
    exit 1
fi

# Get admin credentials from seed file or use defaults
SEED_FILE="$PROJECT_DIR/$ENVIRONMENT/${ENVIRONMENT}-users.json"
if [ -f "$SEED_FILE" ]; then
    ADMIN_EMAIL=$(jq -r '.admin.email // empty' "$SEED_FILE" 2>/dev/null || echo "")
    ADMIN_PASSWORD=$(jq -r '.admin.password // empty' "$SEED_FILE" 2>/dev/null || echo "")
fi

# Fall back to environment defaults if not found
if [ -z "$ADMIN_EMAIL" ]; then
    if [ "$ENVIRONMENT" = "test" ]; then
        ADMIN_EMAIL="test-admin@example.com"
        ADMIN_PASSWORD="test-admin-pass"
    else
        ADMIN_EMAIL="dev-admin@example.com"
        ADMIN_PASSWORD="dev-admin-pass"
    fi
fi

echo_debug "Authenticating as admin..."

# Authenticate as admin to get token
# Note: In PocketBase 0.23+, admins became superusers and the endpoint changed
AUTH_RESPONSE=$(curl -s -X POST "${PB_URL}/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$AUTH_RESPONSE" ]; then
    echo_error "Failed to authenticate as admin"
    echo_error "Make sure admin user exists (run: ./pb.sh $ENVIRONMENT setup)"
    exit 1
fi

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo_error "Failed to get admin token"
    echo_error "Admin user may not exist. Run: ./pb.sh $ENVIRONMENT setup"
    echo_error "Or use: ./pb.sh test start --full --quiet (admin only, seed users separately)"
    if [ -f "$SEED_FILE" ]; then
        echo_debug "Using credentials from: ${SEED_FILE}"
    fi
    exit 1
fi

echo_debug "Getting list of collections..."

# Get list of all collections
COLLECTIONS=$(curl -s -X GET "${PB_URL}/api/collections" \
    -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$COLLECTIONS" ]; then
    echo_error "Failed to get collections list"
    exit 1
fi

# Extract collection names (skip system collections)
COLLECTION_NAMES=$(echo "$COLLECTIONS" | jq -r '.items[]? | select(.system == false) | .name' 2>/dev/null)

if [ -z "$COLLECTION_NAMES" ]; then
    echo_success "No user collections found to clean"
    exit 0
fi

echo_info "Found collections: $(echo "$COLLECTION_NAMES" | tr '\n' ' ')"

# Delete all records from each collection
TOTAL_DELETED=0
for collection in $COLLECTION_NAMES; do
    echo_debug "Cleaning collection: $collection"
    
    # Get all record IDs from this collection
    RECORDS=$(curl -s -X GET "${PB_URL}/api/collections/${collection}/records?perPage=500" \
        -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)
    
    RECORD_IDS=$(echo "$RECORDS" | jq -r '.items[]?.id' 2>/dev/null)
    
    if [ -z "$RECORD_IDS" ]; then
        echo_debug "  No records in $collection"
        continue
    fi
    
    COUNT=0
    for id in $RECORD_IDS; do
        if curl -s -X DELETE "${PB_URL}/api/collections/${collection}/records/${id}" \
            -H "Authorization: Bearer ${TOKEN}" >/dev/null 2>&1; then
            ((COUNT++))
        else
            echo_warn "  Failed to delete record $id from $collection"
        fi
    done
    
    echo_debug "  Deleted $COUNT records from $collection"
    ((TOTAL_DELETED+=COUNT))
done

echo_success "Data cleanup complete - deleted $TOTAL_DELETED records from $ENVIRONMENT environment"
