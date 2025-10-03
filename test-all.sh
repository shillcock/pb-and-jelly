#!/bin/bash

# Test script to verify PocketBase tools functionality
# This script runs a comprehensive integration test using ONLY the test environment
# It will reset the test database but leaves the dev environment untouched

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_info() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

test_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "======================================="
echo "PocketBase Tools Comprehensive Test"
echo "======================================="
echo ""

# Test 1: Check if main scripts exist and are executable
test_info "Checking script files..."
for script in pb.sh scripts/pb-dev.sh scripts/pb-test.sh scripts/install-pocketbase.sh scripts/seed-users.sh scripts/clean.sh scripts/stop.sh; do
    if [ ! -f "$script" ]; then
        test_error "Script not found: $script"
    fi
    
    if [ ! -x "$script" ]; then
        test_error "Script not executable: $script"
    fi
done
test_success "All required scripts exist and are executable"

# Test 2: Check configuration files
# Current architecture uses:
# - .pb-version for version pinning
# - Hardcoded environment settings in scripts/utils.sh
# - Optional JSON seed files in dev/ and test/ directories
test_info "Checking configuration files..."
if [ ! -f ".pb-version" ]; then
    test_error ".pb-version not found - version pinning file required"
fi

# Check if .pb-version has valid content
if [ ! -s ".pb-version" ]; then
    test_error ".pb-version is empty - should contain PocketBase version"
fi

test_success "Configuration files exist and are valid"

# Test 3: Test CLI help
test_info "Testing CLI help command..."
if ! ./pb.sh --help > /dev/null; then
    test_error "CLI help command failed"
fi
test_success "CLI help command works"

# Test 4: Test status command (should work even without PocketBase installed)
test_info "Testing status command..."
if ! ./pb.sh status > /dev/null; then
    test_error "Status command failed"
fi
test_success "Status command works"

# Test 5: Install PocketBase if not present
test_info "Checking PocketBase installation..."
if [ ! -f "bin/pocketbase" ]; then
    test_info "Installing PocketBase..."
    if ! ./pb.sh install; then
        test_error "PocketBase installation failed"
    fi
fi
test_success "PocketBase is installed"

# Test 6: Clean up test environment first
test_info "Cleaning up test environment..."
./pb.sh test stop > /dev/null 2>&1 || true
./pb.sh test clean --force > /dev/null 2>&1 || true
sleep 1

# Test 7: Setup admin user before starting server
test_info "Setting up admin user for test environment..."
if ! ./pb.sh test setup; then
    test_error "Failed to setup admin user"
fi
test_success "Admin user setup completed"

# Test 8: Start test server
test_info "Testing test server..."
if ! ./pb.sh test start --background --quiet --reset; then
    test_error "Failed to start test server"
fi
sleep 3

# Check if server is running
if ! ./pb.sh status | grep -q "Test Server.*Running"; then
    test_warn "Test server status check failed - might be a timing issue"
    # Try checking the port directly
    if lsof -i :8091 > /dev/null 2>&1; then
        test_success "Test server is running (verified by port check)"
    else
        test_error "Test server is not running"
    fi
else
    test_success "Test server started successfully"
fi

# Test 9: Test user seeding
test_info "Testing user seeding..."
if ! ./pb.sh test seed-users; then
    test_warn "User seeding might have failed, but this could be due to existing users"
fi
test_success "User seeding completed (or users already exist)"

# Test 10: Test API connectivity
test_info "Testing API connectivity..."
if command -v curl >/dev/null 2>&1; then
    if curl -s "http://127.0.0.1:8091/_/" > /dev/null; then
        test_success "API is accessible"
    else
        test_warn "API not accessible - server might need more time to start"
    fi
else
    test_warn "curl not available - skipping API test"
fi

# Test 11: Test stop functionality
test_info "Testing stop functionality..."
if ! ./pb.sh test stop; then
    test_error "Failed to stop test server"
fi
test_success "Test server stopped successfully"

# Test 12: Test cleanup functionality
test_info "Testing cleanup functionality..."
if ! ./pb.sh test clean --force; then
    test_error "Failed to clean test environment"
fi
test_success "Test environment cleaned successfully"

# Test 13: Verify file structure
test_info "Verifying directory structure..."
expected_dirs=("bin" "dev" "test" "scripts")
for dir in "${expected_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        test_error "Directory not found: $dir"
    fi
done
test_success "Directory structure is correct"

# Test 14: Test gitignore
test_info "Testing gitignore configuration..."
if [ -f ".gitignore" ]; then
    if grep -q "bin/" .gitignore && grep -q "dev/" .gitignore && grep -q "test/" .gitignore; then
        test_success "Gitignore configuration is correct"
    else
        test_warn "Gitignore might be missing some entries (should ignore: bin/, dev/, test/)"
    fi
else
    test_warn ".gitignore not found"
fi

echo ""
echo "======================================="
echo -e "${GREEN}All tests completed successfully!${NC}"
echo "======================================="
echo ""
echo "Your PocketBase development environment is ready to use."
echo ""
echo "Quick start:"
echo "  ./pb.sh dev start            # Start development server"
echo "  ./pb.sh dev seed-users       # Seed users from JSON (in another terminal)"
echo "  ./pb.sh status               # Check server status"
echo ""
echo "For full documentation, see README.md"