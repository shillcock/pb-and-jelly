#!/bin/bash

# PocketBase Server Stop Script
# Stops running dev and/or test PocketBase servers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

show_help() {
    echo "PocketBase Server Stop"
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environment:"
    echo "  dev     Stop development server"
    echo "  test    Stop test server"
    echo "  all     Stop both servers (default if no environment specified)"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Stop dev server"
    echo "  $0 test                   # Stop test server"
    echo "  $0 all                    # Stop both servers"
    echo "  $0                        # Stop both servers (default)"
}

# Parse command line arguments
ENVIRONMENT=""

if [ $# -eq 0 ]; then
    ENVIRONMENT="all"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|test|all)
            if [ -z "$ENVIRONMENT" ]; then
                ENVIRONMENT="$1"
            else
                echo_error "Multiple environments specified. Use 'all' to stop both."
                exit 1
            fi
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default to all if no environment specified
if [ -z "$ENVIRONMENT" ]; then
    ENVIRONMENT="all"
fi

echo_info "PocketBase Server Stop"
echo_debug "Environment: $ENVIRONMENT"

case $ENVIRONMENT in
    dev)
        stop_pocketbase "dev"
        ;;
    test)
        stop_pocketbase "test"
        ;;
    all)
        echo_info "Stopping all PocketBase servers..."
        stop_pocketbase "dev" || true
        stop_pocketbase "test" || true
        ;;
    *)
        echo_error "Invalid environment: $ENVIRONMENT"
        show_help
        exit 1
        ;;
esac

echo_success "Stop complete!"