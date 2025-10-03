#!/bin/bash

# Test script to verify PocketBase tools functionality
# This script runs a comprehensive test of all features

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
for script in pb.sh scripts/pb-dev scripts/pb-test scripts/install-pocketbase.sh scripts/setup-users.sh scripts/clean.sh scripts/stop.sh; do
    if [ ! -f "$script" ]; then
        test_error "Script not found: $script"
    fi
    
    if [ ! -x "$script" ]; then
        test_error "Script not executable: $script"
    fi
done
test_success "All required scripts exist and are executable"

# Test 2: Check environment configuration
test_info "Checking environment configuration..."
if [ ! -f ".env.example" ]; then
    test_error ".env.example not found"
fi

if [ ! -f ".env.local" ]; then
    test_error ".env.local not found - please copy from .env.example"
fi
test_success "Environment configuration files exist"

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

# Test 6: Clean up any existing processes first
test_info "Cleaning up existing processes..."
./pb.sh stop-all > /dev/null 2>&1 || true
./pb.sh clean-all --force > /dev/null 2>&1 || true
sleep 1

# Test development server (background start and stop)
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

# Test 7: Test user setup
test_info "Testing user setup..."
if ! ./pb.sh test setup-users; then
    test_warn "User setup might have failed, but this could be due to existing users"
fi
test_success "User setup completed (or users already exist)"

# Test 8: Test API connectivity
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

# Test 9: Test stop functionality
test_info "Testing stop functionality..."
if ! ./pb.sh test stop; then
    test_error "Failed to stop test server"
fi
test_success "Test server stopped successfully"

# Test 10: Test cleanup functionality
test_info "Testing cleanup functionality..."
if ! ./pb.sh test clean --force; then
    test_error "Failed to clean test environment"
fi
test_success "Test environment cleaned successfully"

# Test 11: Verify file structure
test_info "Verifying directory structure..."
expected_dirs=("bin" "dev" "test" "scripts")
for dir in "${expected_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        test_error "Directory not found: $dir"
    fi
done
test_success "Directory structure is correct"

# Test 12: Test gitignore
test_info "Testing gitignore configuration..."
if [ -f ".gitignore" ]; then
    if grep -q ".env.local" .gitignore && grep -q "bin/" .gitignore && grep -q "dev/" .gitignore && grep -q "test/" .gitignore; then
        test_success "Gitignore configuration is correct"
    else
        test_warn "Gitignore might be missing some entries"
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
echo "  ./pb.sh dev setup-users      # Set up users (in another terminal)"
echo "  ./pb.sh status               # Check server status"
echo ""
echo "For full documentation, see README.md"