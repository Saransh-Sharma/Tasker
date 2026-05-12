#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if rg -n "\\b(?:Swift\\.)?print\\s*\\(" "LifeBoard" -g '*.swift' -g '!LifeBoardTests/**' -g '!LifeBoardUITests/**'; then
  echo ""
  echo "Direct print() usage found in production app sources. Use LoggingService APIs instead."
  exit 1
fi

echo "No direct print() calls found in app sources."
