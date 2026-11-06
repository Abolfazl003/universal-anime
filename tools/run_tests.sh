#!/usr/bin/env bash
# Run the headless test suite. Usage: ./tools/run_tests.sh [path-to-godot]
set -euo pipefail
GODOT_BIN="${1:-${GODOT_BIN:-godot}}"
set +e
"$GODOT_BIN" --headless --path "$(cd "$(dirname "$0")/.." && pwd)" res://tests/test_runner.tscn
status=$?
echo "test exit code: $status"
exit "$status"
