#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ruby reads Swift sources that contain em dashes; a US-ASCII shell locale
# makes it abort as if a rule had failed.
export LANG="${LANG:-en_US.UTF-8}" LC_ALL="${LC_ALL:-en_US.UTF-8}"

exec ruby "$SCRIPT_DIR/check_launch_contracts.rb" "$@"
