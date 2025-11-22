#!/bin/bash
# Test Runner - Executes all unit and integration tests
# Usage: ./tools/run_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running test suite..."
echo "Project: $PROJECT_DIR"
echo ""

# Check if Godot is available
if ! command -v godot &> /dev/null; then
    echo "Error: 'godot' command not found"
    echo "Please ensure Godot 4.x is installed and in PATH"
    exit 1
fi

cd "$PROJECT_DIR"

# Run the test runner
godot --headless --script tests/test_runner.gd

exit $?
