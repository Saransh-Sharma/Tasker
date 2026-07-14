#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASE_SHA="${TOKEN_LAW_BASE_SHA:-}"
if [[ -z "$BASE_SHA" ]] || ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  BASE_SHA="HEAD"
fi

UI_DIRS=(
  "LifeBoard/View"
  "LifeBoard/Views"
  "LifeBoard/ViewControllers"
  "LifeBoard/Presentation/Views"
  "LifeBoard/LLM/Views"
)

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" && "$file" == *.swift ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only "$BASE_SHA" -- "${UI_DIRS[@]}"; git ls-files --others --exclude-standard -- "${UI_DIRS[@]}")

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "✅ Token-law guardrails passed (no changed UI files)."
  exit 0
fi

FAILED=0

scan_added_lines() {
  local title="$1"
  local regex="$2"
  shift 2
  local -a excludes=("$@")
  local matched=0
  local file

  for file in "${CHANGED_FILES[@]}"; do
    local skip=0
    local exclude
    for exclude in "${excludes[@]-}"; do
      if [[ -n "$exclude" && "$file" =~ $exclude ]]; then
        skip=1
        break
      fi
    done
    [[ $skip -eq 1 ]] && continue

    local additions
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      additions="$(git diff --unified=0 "$BASE_SHA" -- "$file" | rg '^\+[^+]' || true)"
    else
      additions="$(sed 's/^/+/' "$file")"
    fi
    local output
    output="$(printf '%s\n' "$additions" | rg -n "$regex" || true)"
    if [[ -n "$output" ]]; then
      if [[ $matched -eq 0 ]]; then
        echo ""
        echo "❌ $title"
      fi
      matched=1
      printf '%s\n' "$output" | sed "s#^#$file:#"
    fi
  done

  if [[ $matched -eq 1 ]]; then
    FAILED=1
  fi
}

scan_added_lines \
  "Token Law: no raw UIColor constructors in UI modules" \
  '\bUIColor\s*\('

scan_added_lines \
  "Token Law: no UIFont.systemFont / SwiftUI .font(.system...) in UI modules" \
  'UIFont\.systemFont|\.font\(\.system\('

scan_added_lines \
  "Token Law: no ad-hoc shadows outside DesignSystem components" \
  'layer\.shadow(Color|Opacity|Offset|Radius|Path)|\.shadow\(' \
  'LifeBoard/View/LiquidGlass/LGBaseView.swift'

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Token-law guardrails failed on newly added violations. Existing debt remains baselined in git history."
  exit 1
fi

echo "✅ Token-law guardrails passed for changed UI lines."
