#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EVIDENCE_PATH="${1:-docs/cloudkit-smoke-evidence/latest.md}"

if [[ ! -f "$EVIDENCE_PATH" ]]; then
  echo "Missing smoke evidence file: $EVIDENCE_PATH"
  exit 1
fi

rg -n "^## Test Matrix" "$EVIDENCE_PATH"
rg -n "^## Device A Timeline" "$EVIDENCE_PATH"
rg -n "^## Device B Timeline" "$EVIDENCE_PATH"
rg -n "^## Result" "$EVIDENCE_PATH"

if rg -n "PENDING|REPLACE_WITH_" "$EVIDENCE_PATH"; then
  echo "Smoke evidence contains placeholder content"
  exit 1
fi

if ! rg -n "Overall:\\s*`(PASS|FAIL)`" "$EVIDENCE_PATH"; then
  echo "Smoke evidence must include Overall PASS/FAIL result"
  exit 1
fi

if [[ "$(rg -c '`(PASS|FAIL)`' "$EVIDENCE_PATH")" -lt 6 ]]; then
  echo "Smoke evidence must include PASS/FAIL for every scenario and final result"
  exit 1
fi

if ! rg -n "^- Devices:|^1\\. `.+`|^2\\. `.+`" "$EVIDENCE_PATH" >/dev/null; then
  echo "Smoke evidence must include non-empty device metadata"
  exit 1
fi
