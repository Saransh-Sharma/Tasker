#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/.flow/bin/flowctl"

if [[ ! -f "$TARGET" ]]; then
  echo "Missing .flow/bin/flowctl"
  echo "Run scripts/install_flowctl.sh"
  exit 1
fi

if [[ ! -x "$TARGET" ]]; then
  echo ".flow/bin/flowctl exists but is not executable"
  exit 1
fi

VERSION_OUTPUT="$("$TARGET" --version 2>/dev/null || true)"
if [[ -z "$VERSION_OUTPUT" ]]; then
  echo "flowctl --version failed"
  exit 1
fi

if [[ "$VERSION_OUTPUT" == *"shim"* ]]; then
  if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
    echo "flowctl shim is not allowed in CI"
    exit 1
  fi
  if [[ "${FLOWCTL_ALLOW_SHIM:-0}" != "1" ]]; then
    echo "flowctl shim detected; set FLOWCTL_ALLOW_SHIM=1 to acknowledge local fallback"
    exit 1
  fi
fi

echo "flowctl verification passed: $TARGET"
