#!/bin/bash
# Lang CLI - Command line language tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if dart is available
if ! command -v dart &> /dev/null; then
    echo "Error: dart is not installed"
    exit 1
fi

# Run the CLI
dart run "$PROJECT_DIR/cli/bin/lang.dart" "$@"