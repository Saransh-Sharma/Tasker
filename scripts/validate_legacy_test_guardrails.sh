#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_SWIFT_ROOTS=("LifeBoardTests" "LifeBoardUITests")
UI_TEST_SWIFT_ROOT="LifeBoardUITests"

check_banned_symbol() {
  local label="$1"
  local pattern="$2"

  if rg -n -P "$pattern" "${TEST_SWIFT_ROOTS[@]}" --glob '*.swift'; then
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

if rg -n -P 'legacyView|legacyComposer|legacyIdentifier|legacyProjectFilter|Legacy Why|legacy fallback|AccessibilityIdentifiers\.(ProjectManagement|NewProject)|home\.projectFilterButton' "$UI_TEST_SWIFT_ROOT" --glob '*.swift'; then
  echo "Banned legacy UI-test fallback detected"
  exit 1
fi
