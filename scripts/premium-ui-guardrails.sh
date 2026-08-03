#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FAILED=0

fail_if_matches() {
  local title="$1"
  local regex="$2"
  shift 2
  local output
  output="$(rg -n "$regex" "$@" || true)"
  if [[ -n "$output" ]]; then
    echo "❌ $title"
    printf '%s\n' "$output"
    FAILED=1
  fi
}

fail_if_matches \
  "Clear Liquid Glass is not permitted on production surfaces" \
  'lifeBoardSystemGlass\(\.clear|glassEffect\(\.clear' \
  LifeBoard \
  --glob '*.swift' \
  --glob '!**/SwiftUI+TokenAdapters.swift'

fail_if_matches \
  "The canonical secondary destination scaffold cannot recreate legacy scenery or material cards" \
  'LinearGradient|ultraThinMaterial|thinMaterial|regularMaterial' \
  LifeBoard/View/SunriseDestinationScaffold.swift

fail_if_matches \
  "LBGlassCard is now a compatibility clay surface and cannot own blur material" \
  'ultraThinMaterial|thinMaterial|regularMaterial' \
  LifeBoard/LifeBoardDesign/Components/LBGlassCard.swift

if ! rg -q 'LifeBoardScreenScaffold' LifeBoard/View/SunriseDestinationScaffold.swift; then
  echo "❌ Secondary destinations must use LifeBoardScreenScaffold"
  FAILED=1
fi

if ! rg -q 'LifeBoardScreenScaffold' LifeBoard/Views/Settings/SettingsRootView.swift; then
  echo "❌ Settings must use LifeBoardScreenScaffold"
  FAILED=1
fi

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi

echo "✅ Premium clay, glass, and motion guardrails passed."
