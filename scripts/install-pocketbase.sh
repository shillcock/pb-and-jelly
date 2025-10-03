#!/bin/bash

# PocketBase installer script
# Downloads the latest PocketBase binary for macOS if not already present

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
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
    VERSION=$("$PB_BINARY" --version 2>/dev/null || echo "unknown")
    echo_info "Current version: $VERSION"
    read -p "Do you want to update to the latest version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Skipping download"
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

# Get latest release info from GitHub API
echo_info "Fetching latest PocketBase release information..."
RELEASE_INFO=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest)

if [ $? -ne 0 ]; then
    echo_error "Failed to fetch release information"
    exit 1
fi

# Extract version and download URL
VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "v[^"]*' | cut -d'"' -f4)
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "https://github.com/pocketbase/pocketbase/releases/download/${VERSION}/pocketbase_[^\"]*_darwin_${ARCH}\.zip" | head -1)

if [ -z "$VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo_error "Could not parse release information"
    exit 1
fi

echo_info "Latest version: $VERSION"
echo_info "Download URL: $DOWNLOAD_URL"

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