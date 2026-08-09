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
  LifeBoard/Shared/UI/DestinationScaffold.swift

fail_if_matches \
  "LBGlassCard is now a compatibility clay surface and cannot own blur material" \
  'ultraThinMaterial|thinMaterial|regularMaterial' \
  LifeBoard/LifeBoardDesign/Components/GlassCard.swift

if ! rg -q 'ScreenScaffold' LifeBoard/Shared/UI/DestinationScaffold.swift; then
  echo "❌ Secondary destinations must use ScreenScaffold"
  FAILED=1
fi

if ! rg -q 'ScreenScaffold' LifeBoard/Features/Settings/SettingsRootView.swift; then
  echo "❌ Settings must use ScreenScaffold"
  FAILED=1
fi

# --- Clay composer kit ratchets -------------------------------------------------
#
# Two regressions this suite exists to prevent, both of which are invisible until
# they hurt:
#
#   1. A migrated composer quietly going back to `Form`. `Form` owns its own row
#      insets, separators, control chrome and grouped background, so a single
#      reintroduced `Form` undoes the whole surface for that screen while still
#      compiling and still looking "fine" to a reviewer skimming a diff.
#
#   2. A composer body inlining its sections instead of using one struct each.
#      At -Onone that is the shape which walks the 1 MB main-thread stack and
#      crashes on the guard page AT LAUNCH, before a pixel is drawn — so it never
#      shows up in a Release smoke test, and it does not appear until roughly the
#      fifth thing lands in the body. See LifeBoardTrackFoundationViews.swift:193.

MIGRATED_COMPOSER_FILES=(
  LifeBoard/Features/Track/UI/LifeBoardTrackFoundationViews.swift
  LifeBoard/Features/Health/UI/LifeBoardPhaseVIViews.swift
)

for file in "${MIGRATED_COMPOSER_FILES[@]}"; do
  # A Form may survive only with an explicit marker on the line above it, so the
  # exception is a decision someone wrote down rather than something that drifted
  # back in. RoutineComposer is the current holder: its step list depends on List
  # semantics (.onDelete / .onMove / editMode) that a ScrollView cannot provide,
  # and converting it would silently remove reorder and swipe-delete.
  form_count=$(rg -c '^\s*Form \{' "$file" || true)
  allow_count=$(rg -c 'composer-kit:allow-form' "$file" || true)
  form_count=${form_count:-0}
  allow_count=${allow_count:-0}
  if [[ "$form_count" -gt "$allow_count" ]]; then
    echo "❌ Clay composer kit: $file has $form_count Form(s) but only $allow_count documented allowance(s)."
    echo "   Use LifeBoardComposerScaffold (presented) or LifeBoardComposerPage (pushed),"
    echo "   or add '// composer-kit:allow-form <reason>' above a deliberate exception."
    rg -n '^\s*Form \{' "$file"
    FAILED=1
  fi
done

# The scaffold's content closure should reference section structs, not build
# controls inline. A `LifeBoardComposerSection(` opening directly inside a
# scaffold's trailing closure is the inlining pattern rule 2 forbids.
if rg -qU 'LifeBoardComposerScaffold\([^)]*\)\s*\{\s*\n\s*LifeBoardComposerSection\(' \
     LifeBoard/Foundation LifeBoard/Features 2>/dev/null; then
  echo "❌ Clay composer kit: a composer inlines LifeBoardComposerSection into its scaffold closure."
  echo "   Extract one 'private struct <Name>Section: View' per section (stack-budget rule)."
  rg -nU 'LifeBoardComposerScaffold\([^)]*\)\s*\{\s*\n\s*LifeBoardComposerSection\(' \
     LifeBoard/Foundation LifeBoard/Features 2>/dev/null | head -5
  FAILED=1
fi

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi

echo "✅ Premium clay, glass, and motion guardrails passed."
