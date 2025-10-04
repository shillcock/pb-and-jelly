#!/bin/bash

# Initialize pb-tools in another project
# Creates pocketbase/ directory with wrapper script and environment directories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PB_TOOLS_DIR="$(dirname "$SCRIPT_DIR")"

show_help() {
    echo "Initialize pb-tools in another project"
    echo ""
    echo "Usage: $0 [target_directory]"
    echo ""
    echo "Arguments:"
    echo "  target_directory    Path to the project where pb-tools should be initialized"
    echo "                      (defaults to current directory)"
    echo ""
    echo "What this creates:"
    echo "  pocketbase/         Directory containing all PocketBase files"
    echo "  pocketbase/pb.sh    Wrapper script that calls main pb-tools"
    echo "  pocketbase/dev/     Development environment directory"
    echo "  pocketbase/test/    Test environment directory"
    echo "  pocketbase/pb_hooks/     JavaScript event hooks (shared)"
    echo "  pocketbase/pb_migrations/ JavaScript migrations (shared)"
    echo "  pocketbase/.pb-project  Config file pointing to pb-tools location"
    echo ""
    echo "Examples:"
    echo "  $0                          # Initialize in current directory"
    echo "  $0 /path/to/my-project      # Initialize in specific directory"
    echo "  $0 ../my-app                # Initialize in relative path"
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

echo_info "Initializing pb-tools in: $TARGET_DIR"
echo_debug "PocketBase directory: $POCKETBASE_DIR"

# Check if pocketbase directory already exists
if [ -d "$POCKETBASE_DIR" ]; then
    echo_warn "PocketBase directory already exists: $POCKETBASE_DIR"
    read -p "Continue and overwrite? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo_info "Initialization cancelled"
        exit 0
    fi
fi

# Create pocketbase directory structure
echo_info "Creating directory structure..."
mkdir -p "$POCKETBASE_DIR/dev"
mkdir -p "$POCKETBASE_DIR/test"
mkdir -p "$POCKETBASE_DIR/pb_hooks"
mkdir -p "$POCKETBASE_DIR/pb_migrations"

# Create .pb-project config file
echo_info "Creating configuration..."
cat > "$POCKETBASE_DIR/.pb-project" << EOF
# pb-tools configuration
# This file tells the local pb.sh wrapper where to find the main pb-tools installation

PB_TOOLS_PATH="$PB_TOOLS_DIR"
EOF

# Create wrapper pb.sh script
echo_info "Creating wrapper script..."
cat > "$POCKETBASE_DIR/pb.sh" << 'EOF'
#!/bin/bash

# pb-tools wrapper script for project-specific PocketBase management
# This script calls the main pb-tools installation but uses local directories

set -e

# Get the directory containing this script
WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load pb-tools configuration
if [ -f "$WRAPPER_DIR/.pb-project" ]; then
    source "$WRAPPER_DIR/.pb-project"
else
    echo "Error: .pb-project config file not found"
    echo "This wrapper requires a .pb-project file in the same directory"
    exit 1
fi

# Verify pb-tools installation exists
if [ ! -f "$PB_TOOLS_PATH/pb.sh" ]; then
    echo "Error: pb-tools not found at: $PB_TOOLS_PATH"
    echo "Update the PB_TOOLS_PATH in .pb-project or reinstall pb-tools"
    exit 1
fi

# Set environment variable to tell pb-tools to use this project's directories
export PB_PROJECT_DIR="$WRAPPER_DIR"

# Call the main pb-tools script with all arguments
exec "$PB_TOOLS_PATH/pb.sh" "$@"
EOF

# Make wrapper script executable
chmod +x "$POCKETBASE_DIR/pb.sh"

# Copy template files from pb-tools
echo_info "Copying template files..."

# Copy dev-users.json if it exists in pb-tools
if [ -f "$PB_TOOLS_DIR/dev/dev-users.json" ]; then
    cp "$PB_TOOLS_DIR/dev/dev-users.json" "$POCKETBASE_DIR/dev/"
    echo_debug "Copied dev-users.json template"
else
    echo_warn "No dev-users.json template found in pb-tools, creating basic template"
    cat > "$POCKETBASE_DIR/dev/dev-users.json" << 'EOF'
{
  "admin": {
    "email": "dev-admin@example.com",
    "password": "dev-admin-pass"
  },
  "users": [
    {
      "email": "dev-user@example.com",
      "password": "devpass123",
      "name": "Dev User"
    }
  ]
}
EOF
fi

# Copy test-users.json if it exists in pb-tools
if [ -f "$PB_TOOLS_DIR/test/test-users.json" ]; then
    cp "$PB_TOOLS_DIR/test/test-users.json" "$POCKETBASE_DIR/test/"
    echo_debug "Copied test-users.json template"
else
    echo_warn "No test-users.json template found in pb-tools, creating basic template"
    cat > "$POCKETBASE_DIR/test/test-users.json" << 'EOF'
{
  "admin": {
    "email": "test-admin@example.com",
    "password": "test-admin-pass"
  },
  "users": [
    {
      "email": "test-user@example.com",
      "password": "testpass123",
      "name": "Test User"
    }
  ]
}
EOF
fi

# Copy pb_hooks directory if it exists in pb-tools
if [ -d "$PB_TOOLS_DIR/pb_hooks" ]; then
    cp -r "$PB_TOOLS_DIR/pb_hooks" "$POCKETBASE_DIR/"
    echo_debug "Copied pb_hooks templates"
else
    echo_warn "No pb_hooks directory found in pb-tools, creating empty directory"
fi

# Copy pb_migrations directory if it exists in pb-tools
if [ -d "$PB_TOOLS_DIR/pb_migrations" ]; then
    cp -r "$PB_TOOLS_DIR/pb_migrations" "$POCKETBASE_DIR/"
    echo_debug "Copied pb_migrations templates"
else
    echo_warn "No pb_migrations directory found in pb-tools, creating empty directory"
fi

# Create a simple README
cat > "$POCKETBASE_DIR/README.md" << EOF
# PocketBase Setup

This directory contains PocketBase configuration for this project.

## Quick Start

\`\`\`bash
# Install PocketBase binary (run once)
./pb.sh install

# Start development server
./pb.sh dev start

# In another terminal, setup admin and seed users
./pb.sh dev setup
./pb.sh dev seed-users

# Access PocketBase
# API: http://127.0.0.1:8090
# Admin UI: http://127.0.0.1:8090/_/
\`\`\`

## Testing

\`\`\`bash
# Start test server
./pb.sh test start --quiet --reset

# Setup test environment
./pb.sh test setup
./pb.sh test seed-users

# Run your tests here

# Stop test server
./pb.sh test stop
\`\`\`

## Configuration

- \`dev/dev-users.json\` - Development environment users
- \`test/test-users.json\` - Test environment users
- \`pb_hooks/\` - JavaScript event hooks and custom routes (shared between envs)
- \`pb_migrations/\` - JavaScript database migrations (shared between envs)
- \`.pb-project\` - Points to main pb-tools installation

## JavaScript Extensions

- **Hooks**: Add custom server-side logic in \`pb_hooks/*.pb.js\` files
- **Migrations**: Manage database schema in \`pb_migrations/*.js\` files
- **Documentation**: [PocketBase JS Overview](https://pocketbase.io/docs/js-overview/)

## Environment Settings

- **Dev**: Port 8090, Host 127.0.0.1
- **Test**: Port 8091, Host 127.0.0.1
EOF

echo_success "pb-tools initialized successfully!"
echo ""
echo "Created:"
echo "  📁 $POCKETBASE_DIR/"
echo "  🔧 $POCKETBASE_DIR/pb.sh (wrapper script)"
echo "  📁 $POCKETBASE_DIR/dev/ (with template users from pb-tools)"
echo "  📁 $POCKETBASE_DIR/test/ (with template users from pb-tools)"
echo "  🪝 $POCKETBASE_DIR/pb_hooks/ (JavaScript hooks from pb-tools)"
echo "  🗄️  $POCKETBASE_DIR/pb_migrations/ (JavaScript migrations from pb-tools)"
echo "  ⚙️  $POCKETBASE_DIR/.pb-project (configuration)"
echo "  📖 $POCKETBASE_DIR/README.md (usage guide)"
echo ""
echo "Next steps:"
echo "  1. cd $POCKETBASE_DIR"
echo "  2. ./pb.sh install"
echo "  3. ./pb.sh dev start"
echo ""
echo "Add to your package.json scripts:"
echo '  "pb:install": "./pocketbase/pb.sh install",'
echo '  "pb:dev": "./pocketbase/pb.sh dev start",'
echo '  "pb:test:start": "./pocketbase/pb.sh test start --quiet --reset",'
echo '  "pb:test:setup": "./pocketbase/pb.sh test setup && ./pocketbase/pb.sh test seed-users",'
echo '  "pb:test:stop": "./pocketbase/pb.sh test stop"'
