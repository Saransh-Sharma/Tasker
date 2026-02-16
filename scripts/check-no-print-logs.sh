#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if rg -n "\\b(?:Swift\\.)?print\\s*\\(" "To Do List" -g '*.swift' -g '!To Do ListTests/**' -g '!To Do ListUITests/**'; then
  echo ""
  echo "Direct print() usage found in production app sources. Use LoggingService APIs instead."
  exit 1
fi

echo "No direct print() calls found in app sources."
