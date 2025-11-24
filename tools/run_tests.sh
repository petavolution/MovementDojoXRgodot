#!/bin/bash
# Movement Dojo XR - Test Runner
# Runs all tests headlessly via Godot CLI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/godot_project"
TEST_SCRIPT="res://tests/test_runner.gd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default Godot path (can be overridden via GODOT_PATH env var)
GODOT="${GODOT_PATH:-godot}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -g, --godot PATH    Path to Godot executable"
    echo "  -v, --verbose       Verbose output"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  GODOT_PATH          Path to Godot executable"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run with default godot"
    echo "  $0 -g /path/to/godot            # Specify Godot path"
    echo "  GODOT_PATH=/path/to/godot $0    # Via environment variable"
}

VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--godot)
            GODOT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check Godot exists
if ! command -v "$GODOT" &> /dev/null; then
    echo -e "${RED}Error: Godot executable not found at: $GODOT${NC}"
    echo "Please install Godot 4.x or specify path with -g option"
    exit 1
fi

# Get Godot version
GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1 || echo "unknown")
echo -e "${YELLOW}Using Godot: $GODOT (version: $GODOT_VERSION)${NC}"

# Check project exists
if [ ! -f "$PROJECT_DIR/project.godot" ]; then
    echo -e "${RED}Error: project.godot not found in $PROJECT_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}Running tests...${NC}"
echo ""

# Run tests headlessly
cd "$PROJECT_DIR"

if [ "$VERBOSE" = true ]; then
    "$GODOT" --headless --script "$TEST_SCRIPT" 2>&1
else
    "$GODOT" --headless --script "$TEST_SCRIPT" 2>&1 | grep -v "^Godot Engine"
fi

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Some tests failed!${NC}"
fi

exit $EXIT_CODE
