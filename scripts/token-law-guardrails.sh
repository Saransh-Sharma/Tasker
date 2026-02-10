#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UI_DIRS=(
  "To Do List/View"
  "To Do List/Views"
  "To Do List/ViewControllers"
  "To Do List/Presentation/Views"
  "To Do List/LLM/Views"
)

UI_FILES=()
while IFS= read -r file; do
  UI_FILES+=("$file")
done < <(rg --files "${UI_DIRS[@]}" -g '*.swift')

if [[ ${#UI_FILES[@]} -eq 0 ]]; then
  echo "No UI files found for token-law guardrails."
  exit 0
fi

FAILED=0

scan_rule() {
  local title="$1"
  local regex="$2"
  shift 2
  local -a excludes=()
  if [[ $# -gt 0 ]]; then
    excludes=("$@")
  fi
  local matched=0

  for file in "${UI_FILES[@]}"; do
    local skip=0
    for exclude in "${excludes[@]-}"; do
      if [[ "$file" =~ $exclude ]]; then
        skip=1
        break
      fi
    done
    if [[ $skip -eq 1 ]]; then
      continue
    fi

    local output
    output="$(rg -nH "$regex" "$file" || true)"
    if [[ -n "$output" ]]; then
      if [[ $matched -eq 0 ]]; then
        echo ""
        echo "❌ $title"
      fi
      matched=1
      echo "$output"
    fi
  done

  if [[ $matched -eq 1 ]]; then
    FAILED=1
  fi
}

scan_rule \
  "Token Law: no raw UIColor constructors in UI modules" \
  '\bUIColor\s*\('

scan_rule \
  "Token Law: no UIFont.systemFont / SwiftUI .font(.system...) in UI modules" \
  'UIFont\.systemFont|\.font\(\.system\('

scan_rule \
  "Token Law: no ad-hoc shadows outside DesignSystem components" \
  'layer\.shadow(Color|Opacity|Offset|Radius|Path)|\.shadow\(' \
  'To Do List/View/LiquidGlass/LGBaseView.swift'

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Token-law guardrails failed."
  exit 1
fi

echo "✅ Token-law guardrails passed."
