#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lifeboard-paths.env
source "$SCRIPT_DIR/lifeboard-paths.env"

export LIFEBOARD_ROOT_DIR
export LIFEBOARD_MODULE_ADJACENCY="$SCRIPT_DIR/module-adjacency.tsv"
export LIFEBOARD_MODULE_BOUNDARY_EXCEPTIONS="$SCRIPT_DIR/module-boundary-exceptions.txt"

exec ruby "$SCRIPT_DIR/check_module_boundaries.rb" "$@"
