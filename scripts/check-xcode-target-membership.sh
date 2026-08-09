#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lifeboard-paths.env
source "$SCRIPT_DIR/lifeboard-paths.env"

export LIFEBOARD_ROOT_DIR LIFEBOARD_PROJECT_FILE LIFEBOARD_TARGET_MEMBERSHIP_ALLOWLIST
export LIFEBOARD_TARGET_MEMBERSHIP_EXCLUSIONS
export LIFEBOARD_SWIFT_SOURCE_ROOTS="$(IFS=:; echo "${LIFEBOARD_SWIFT_SOURCE_ROOTS[*]}")"

exec ruby "$SCRIPT_DIR/check_xcode_target_membership.rb" "$@"
