#!/usr/bin/env bash
# Static check for every GDScript file (requires: pip install gdtoolkit).
set -euo pipefail
cd "$(dirname "$0")/.."
gdlint scripts tests
