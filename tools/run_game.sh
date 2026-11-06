#!/usr/bin/env bash
# Launch the game. Usage: ./tools/run_game.sh [path-to-godot]
set -euo pipefail
GODOT_BIN="${1:-${GODOT_BIN:-godot}}"
"$GODOT_BIN" --path "$(cd "$(dirname "$0")/.." && pwd)"
