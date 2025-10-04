#!/bin/bash

# Initialize pb-and-jelly in another project
# Copies template directory to create a self-contained PocketBase setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PB_AND_JELLY_DIR="$(dirname "$SCRIPT_DIR")"

# Define color codes without utils.sh (to avoid PB_PROJECT_DIR requirement)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

show_help() {
    echo "Initialize pb-and-jelly in another project"
    echo ""
    echo "Usage: $0 [target_directory]"
    echo ""
    echo "Arguments:"
    echo "  target_directory    Path to the project where pb-and-jelly should be initialized"
    echo "                      (defaults to current directory)"
    echo ""
    echo "What this creates:"
    echo "  pocketbase/         Directory containing all PocketBase files"
    echo "  pocketbase/pb.sh    Wrapper script that calls pb-and-jelly"
    echo "  pocketbase/bin/     PocketBase binary location"
    echo "  pocketbase/dev/     Development environment"
    echo "  pocketbase/test/    Test environment"
    echo "  pocketbase/pb_hooks/     JavaScript hooks"
    echo "  pocketbase/pb_migrations/ JavaScript migrations"
    echo "  pocketbase/.pb-version   Version pinning"
    echo "  pocketbase/.pb-core Path to pb-and-jelly (gitignored)"
    echo ""
    echo "Examples:"
    echo "  cd /path/to/my-project && $0 ."
    echo "  $0 /path/to/my-project"
    echo "  $0 ../my-app"
}

# Parse arguments
TARGET_DIR="${1:-$(pwd)}"

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Resolve target directory to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    echo_error "Target directory does not exist: $1"
    exit 1
}

POCKETBASE_DIR="$TARGET_DIR/pocketbase"
TEMPLATE_DIR="$PB_AND_JELLY_DIR/template"

# Verify template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo_error "Template directory not found: $TEMPLATE_DIR"
    echo_error "pb-and-jelly installation may be corrupted"
    exit 1
fi

echo_info "Initializing pb-and-jelly in: $TARGET_DIR"

# Check if pocketbase directory already exists
if [ -d "$POCKETBASE_DIR" ]; then
    echo_warn "PocketBase directory already exists: $POCKETBASE_DIR"
    read -p "Continue and overwrite? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo_info "Initialization cancelled"
        exit 0
    fi
    rm -rf "$POCKETBASE_DIR"
fi

# Copy entire template directory
echo_info "Copying template..."
cp -r "$TEMPLATE_DIR" "$POCKETBASE_DIR"

# Write absolute path to pb-and-jelly (gitignored)
echo_info "Configuring pb-and-jelly path..."
echo "$PB_AND_JELLY_DIR" > "$POCKETBASE_DIR/.pb-core"

# Ensure wrapper script is executable
chmod +x "$POCKETBASE_DIR/pb.sh"

echo_success "pb-and-jelly initialized successfully!"
echo ""
echo "Created:"
echo "  📁 $POCKETBASE_DIR/"
echo "  🔧 $POCKETBASE_DIR/pb.sh (wrapper script)"
echo "  📁 $POCKETBASE_DIR/bin/ (for PocketBase binary)"
echo "  📁 $POCKETBASE_DIR/dev/ (development environment)"
echo "  📁 $POCKETBASE_DIR/test/ (test environment)"
echo "  🪝 $POCKETBASE_DIR/pb_hooks/ (JavaScript hooks)"
echo "  🗄️  $POCKETBASE_DIR/pb_migrations/ (JavaScript migrations)"
echo "  📌 $POCKETBASE_DIR/.pb-version (version pinning)"
echo "  ⚙️  $POCKETBASE_DIR/.pb-core (pb-and-jelly path, gitignored)"
echo "  📖 $POCKETBASE_DIR/README.md"
echo ""
echo "Next steps:"
echo "  1. cd $POCKETBASE_DIR"
echo "  2. ./pb.sh install"
echo "  3. ./pb.sh dev start"
echo ""
echo "Recommended package.json scripts:"
echo '  "pb:install": "./pocketbase/pb.sh install",'
echo '  "pb:dev": "./pocketbase/pb.sh dev start",'
echo '  "pb:test:start": "./pocketbase/pb.sh test start --quiet --reset",'
echo '  "pb:test:setup": "./pocketbase/pb.sh test setup && ./pocketbase/pb.sh test seed-users",'
echo '  "pb:test:stop": "./pocketbase/pb.sh test stop"'
