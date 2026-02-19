#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_SWIFT_ROOT="To Do ListTests"

check_banned_symbol() {
  local label="$1"
  local pattern="$2"

  if rg -n -P "$pattern" "$TEST_SWIFT_ROOT" --glob '*.swift'; then
    echo "Banned legacy test symbol detected: $label"
    exit 1
  fi
}

check_banned_symbol "TaskRepositoryProtocol" '\\bTaskRepositoryProtocol\\b'
check_banned_symbol "UpdateTaskRequest" '\\bUpdateTaskRequest\\b'
check_banned_symbol "TaskSliceResult" '\\bTaskSliceResult\\b'
check_banned_symbol "DomainTask" '\\bDomainTask\\b'
check_banned_symbol "v2Enabled" '\\bv2Enabled\\b'
check_banned_symbol "LegacyTaskReadModelAdapter" '\\bLegacyTaskReadModelAdapter\\b'
check_banned_symbol "LegacyTaskDefinitionRepositoryAdapter" '\\bLegacyTaskDefinitionRepositoryAdapter\\b'
