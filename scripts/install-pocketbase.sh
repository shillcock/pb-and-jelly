#!/bin/bash

# PocketBase installer script
# Downloads the latest PocketBase binary for macOS if not already present

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load environment variables (including PB_VERSION)
load_env

PROJECT_DIR="$(get_project_dir)"
BIN_DIR="$PROJECT_DIR/bin"
PB_BINARY="$BIN_DIR/pocketbase"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PocketBase already exists
if [ -f "$PB_BINARY" ]; then
    echo_info "PocketBase already exists at $PB_BINARY"
    # Check version
    CURRENT_VERSION=$("$PB_BINARY" --version 2>/dev/null | head -1 || echo "unknown")
    echo_info "Current version: $CURRENT_VERSION"
    echo_info "Target version: v$PB_VERSION"
    
    if echo "$CURRENT_VERSION" | grep -q "$PB_VERSION"; then
        echo_info "Target version v$PB_VERSION is already installed"
        exit 0
    fi
    
    read -p "Do you want to install version v$PB_VERSION? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Skipping installation"
        exit 0
    fi
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    arm64)
        ARCH="arm64"
        ;;
    *)
        echo_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo_info "Detected architecture: $ARCH"

# Use pinned version from environment
VERSION="v$PB_VERSION"
echo_info "Installing pinned version: $VERSION"

# Construct download URL for specific version
DOWNLOAD_URL="https://github.com/pocketbase/pocketbase/releases/download/${VERSION}/pocketbase_${PB_VERSION}_darwin_${ARCH}.zip"
echo_info "Download URL: $DOWNLOAD_URL"

# Verify the release exists by checking the download URL
echo_info "Verifying release exists..."
HTTP_STATUS=$(curl -s -I "$DOWNLOAD_URL" | head -n 1 | cut -d' ' -f2)
if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "302" ]; then
    echo_error "Version $VERSION not found or download URL invalid"
    echo_error "Please check if version $PB_VERSION exists at: https://github.com/pocketbase/pocketbase/releases"
    exit 1
fi
echo_info "Release verified"

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Download and extract PocketBase
TEMP_DIR=$(mktemp -d)
TEMP_FILE="$TEMP_DIR/pocketbase.zip"

echo_info "Downloading PocketBase $VERSION..."
curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
    echo_error "Failed to download PocketBase"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo_info "Extracting PocketBase..."
unzip -q "$TEMP_FILE" -d "$TEMP_DIR"

# Move binary to bin directory
mv "$TEMP_DIR/pocketbase" "$PB_BINARY"
chmod +x "$PB_BINARY"

# Cleanup
rm -rf "$TEMP_DIR"

echo_info "PocketBase $VERSION installed successfully to $PB_BINARY"

# Verify installation
if "$PB_BINARY" --version >/dev/null 2>&1; then
    echo_info "Installation verified!"
else
    echo_error "Installation verification failed"
    exit 1
fi