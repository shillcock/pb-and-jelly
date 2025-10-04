#!/bin/bash

# pb-and-jelly wrapper script for project-specific PocketBase management
# This script calls the main pb-and-jelly installation but uses local directories

set -e

# Get the directory containing this script
WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read pb-and-jelly location (absolute path, gitignored)
if [ ! -f "$WRAPPER_DIR/.pb-core" ]; then
    echo "Error: .pb-core config file not found"
    echo "This file should contain the absolute path to your pb-and-jelly installation"
    echo "Run pb-and-jelly init again to set up this project"
    exit 1
fi

PB_CORE_PATH="$(cat "$WRAPPER_DIR/.pb-core")"

# Verify pb-and-jelly installation exists
if [ ! -f "$PB_CORE_PATH/pb.sh" ]; then
    echo "Error: pb-and-jelly not found at: $PB_CORE_PATH"
    echo "Update pb-and-jelly location or reinstall pb-and-jelly"
    exit 1
fi

# Set environment variable to tell pb-and-jelly to use this project's directories
export PB_PROJECT_DIR="$WRAPPER_DIR"

# Call the main pb-and-jelly script with all arguments
exec "$PB_CORE_PATH/pb.sh" "$@"
