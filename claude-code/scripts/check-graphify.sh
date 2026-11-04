#!/usr/bin/env bash
# Check if graphify is installed and has a knowledge graph for the target.
# Usage: check-graphify.sh <target_directory>
# Exit codes:
#   0 - graphify installed, graph exists at <target>/graphify-out/graph.json
#   1 - graphify installed, but no graph exists yet
#   2 - graphify is not installed
#   3 - error (target not found, etc.)

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
    echo "ERROR: Target directory not found: $TARGET" >&2
    exit 3
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" && pwd)"

# Check if graphify CLI is available
GRAPHIFY_BIN="$(which graphify 2>/dev/null || echo '')"
PYTHON=""

if [ -n "$GRAPHIFY_BIN" ]; then
    # Check if graphify Python module is importable
    _SHEBANG=$(head -1 "$GRAPHIFY_BIN" 2>/dev/null | tr -d '#!' || echo '')
    case "$_SHEBANG" in
        *[!a-zA-Z0-9/_.@-]*) PYTHON="python3" ;;
        *) PYTHON="$_SHEBANG" ;;
    esac
fi

if [ -z "$PYTHON" ]; then
    PYTHON="python3"
fi

if ! "$PYTHON" -c "import graphify" 2>/dev/null; then
    echo "graphify not installed" >&2
    exit 2
fi

# graphify is installed. Check if a graph already exists.
if [ -f "$TARGET/graphify-out/graph.json" ]; then
    echo "graphify: installed, graph exists at $TARGET/graphify-out/graph.json"
    exit 0
else
    echo "graphify: installed, no graph found for $TARGET"
    exit 1
fi
