#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASE_SHA="${TOKEN_LAW_BASE_SHA:-}"
if [[ -z "$BASE_SHA" ]] || ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  BASE_SHA="HEAD"
fi

UI_DIRS=(
  # `View/`, `Views/`, `ViewControllers/` and `Presentation/` were dissolved
  # into these three; naming a directory that no longer exists makes `git diff`
  # return nothing for it, which reads as "no violations" rather than "no scope".
  "LifeBoard/Foundation"
  "LifeBoard/Features"
  "LifeBoard/Shared"
  "LifeBoard/App"
  # The design system was out of scope until now, which is exactly backwards:
  # the two worst glass violations in the repo lived in `LifeBoardDesign`, and
  # `DesignSystem` was measured at 48% off-grid spacing. A law the lawgiver is
  # exempt from is not a law. Rules that legitimately belong to the visual layer
  # (raw shadows, `.glassEffect`, raw springs) keep their per-rule exclusions
  # below, so this widens coverage without banning the primitives from doing
  # their job.
  "LifeBoard/DesignSystem"
  "LifeBoard/LifeBoardDesign"
  "Packages"
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

# One listing of the base tree, reused by the rename fallback below. Recomputing
# it per file per rule made this script take minutes.
BASE_TREE_LIST="$(mktemp)"
CACHE_DIR="$(mktemp -d)"
trap 'rm -f "$BASE_TREE_LIST"; rm -rf "$CACHE_DIR"' EXIT
git ls-tree -r --name-only "$BASE_SHA" > "$BASE_TREE_LIST"

# Per-file work, done once.
#
# `scan_added_lines` used to shell out to `git diff` and `git show` for every
# file on every rule. At 43 files and 16 rules that is ~1,400 git processes and
# roughly two and a half minutes of wall clock — slow enough that the gate was
# timing out rather than failing, which is indistinguishable from passing if you
# are not watching. Both are now computed once and read from disk.
cache_key() { printf '%s' "$1" | tr '/' '_'; }

for file in "${CHANGED_FILES[@]}"; do
  [[ -f "$file" ]] || continue
  key="$(cache_key "$file")"
  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    git diff --unified=0 "$BASE_SHA" -- "$file" | rg '^\+[^+]' > "$CACHE_DIR/$key.add" 2>/dev/null || true
  else
    sed 's/^/+/' "$file" > "$CACHE_DIR/$key.add"
  fi
  # Matches inside comments are not violations. These rules necessarily name the
  # constructs they forbid, and so does any comment explaining why one was
  # removed — a doc comment recording that a modifier drew glass on content used
  # to fail the very rule it documented, and the only workaround was to write
  # worse prose.
  awk '{ text = $0
         sub(/^\+/, "", text)
         sub(/^[[:space:]]+/, "", text)
         if (text ~ /^\/\// || text ~ /^\*/) next
         print }' "$CACHE_DIR/$key.add" > "$CACHE_DIR/$key.code" || true

  base_blob="$(git show "$BASE_SHA:$file" 2>/dev/null || true)"
  if [[ -z "$base_blob" ]]; then
    base_path="$(awk -v b="${file##*/}" 'index($0, "/" b) && substr($0, length($0) - length(b) + 1) == b' "$BASE_TREE_LIST" | head -1 || true)"
    [[ -n "$base_path" ]] && base_blob="$(git show "$BASE_SHA:$base_path" 2>/dev/null || true)"
  fi
  printf '%s' "$base_blob" > "$CACHE_DIR/$key.base"
  # The suppression counter has to see the same thing the matcher sees. It used
  # to count raw lines while the matcher skipped comments, so writing a comment
  # that *names* a construct inflated the current count above the base and
  # reported the untouched code line beside it as new. Both sides are
  # comment-stripped now.
  awk '{ text = $0
         sub(/^[[:space:]]+/, "", text)
         if (text ~ /^\/\// || text ~ /^\*/) next
         print }' "$CACHE_DIR/$key.base" > "$CACHE_DIR/$key.basecode" || true
  awk '{ text = $0
         sub(/^[[:space:]]+/, "", text)
         if (text ~ /^\/\// || text ~ /^\*/) next
         print }' "$file" > "$CACHE_DIR/$key.filecode" || true
done

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

    # A renamed or deleted file still appears in `git diff --name-only`, but its
    # old path is gone from both the index and the working tree. There are no
    # added lines to inspect at a path that no longer exists.
    [[ -f "$file" ]] || continue

    local key
    key="$(cache_key "$file")"
    [[ -f "$CACHE_DIR/$key.code" ]] || continue
    local output
    output="$(rg -n "$regex" "$CACHE_DIR/$key.code" || true)"

    # Moving a line is not adding a violation.
    #
    # This gate reads `+` lines out of the diff, so a pure code-motion change —
    # which is what every file split in the structural refactor produces —
    # re-reports every pre-existing violation it relocates. Suppress that by
    # comparing the file's total against the base: only a genuine *increase*
    # fails. A file that carries its debt from one line to another is unchanged
    # as far as this law is concerned, and the per-rule totals in
    # scripts/swiftlint-baseline.txt remain the ratchet that drives it down.
    # Note this runs for untracked files too. It used to be gated on
    # `git ls-files --error-unmatch`, which meant a brand-new file — every file
    # produced by splitting a god file, before anything is committed — skipped
    # suppression entirely and reported all of its inherited debt as new.
    if [[ -n "$output" ]]; then
      local base_count current_count base_blob
      base_blob="$(cat "$CACHE_DIR/$key.base" 2>/dev/null || true)"
      if [[ -n "$base_blob" ]]; then
        base_count="$(rg -c "$regex" "$CACHE_DIR/$key.basecode" || true)"
        current_count="$(rg -c "$regex" "$CACHE_DIR/$key.filecode" || true)"
        if [[ "${current_count:-0}" -le "${base_count:-0}" ]]; then
          output=""
        fi
      else
        # Still no counterpart: this path is new *and* its basename never
        # existed, which is what splitting one god file into a dozen new names
        # looks like. Counting cannot help — there is nothing to count against —
        # so fall back to the only question that matters for code motion: did
        # this exact line already exist somewhere under the UI directories at
        # the base commit? Lines that did are relocated debt; lines that did not
        # are genuinely new and still fail.
        local surviving="" offending
        while IFS= read -r offending; do
          [[ -n "$offending" ]] || continue
          # `output` rows are `<n>:+<source line>`; recover the source text.
          local text="${offending#*:+}"
          local trimmed="${text#"${text%%[![:space:]]*}"}"
          # `-e` is required: without it git reads the first `--` as the end of
          # options and mis-parses the pattern, so every lookup silently misses
          # and every moved line is reported as new.
          if [[ -n "$trimmed" ]] && git grep -qF -e "$trimmed" "$BASE_SHA" 2>/dev/null; then
            continue
          fi
          surviving+="${offending}"$'\n'
        done <<< "$output"
        output="${surviving%$'\n'}"
      fi
    fi

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

# Literal construction only. The old pattern was a bare `UIColor\s*(`, which
# also matched `UIColor(someSwiftUIColor)` — a *conversion*, not a hardcoded
# appearance, and the thing you have to do to measure a colour you were handed.
# The rule is "do not write an appearance into a view", so it names the
# constructors that write one.
#
# The token layer is excluded because defining the palette is its entire job:
# somewhere the hexes have to live, and that somewhere is pinned against
# DESIGN.md by DesignContractTests rather than by this grep.
scan_added_lines \
  "Token Law: no raw UIColor constructors in UI modules" \
  'UIColor\(\s*(red|white|hue|displayP3Red)\s*:|UIColor\(lifeboardHex:' \
  'LifeBoard/Foundation/Design/LifeBoardDaypartTokens.swift' \
  'Packages/LifeBoardTokens/'

scan_added_lines \
  "Token Law: no UIFont.systemFont / SwiftUI .font(.system...) in UI modules" \
  'UIFont\.systemFont|\.font\(\.system\(' \
  'LifeBoard/Foundation/Design/LifeBoardAtmosphereRenderer.swift'

scan_added_lines \
  "Token Law: no ad-hoc shadows outside DesignSystem components" \
  'layer\.shadow(Color|Opacity|Offset|Radius|Path)|\.shadow\(' \
  'LifeBoard/Foundation/Design/LifeBoardAtmosphereRenderer.swift'

scan_added_lines \
  "Token Law: no direct named SwiftUI colors in UI modules" \
  'Color\.(red|blue|green|orange|yellow|purple|pink|white|black)\b|foregroundStyle\(\.(red|blue|green|orange|yellow|purple|pink|white|black)\b'

scan_added_lines \
  "Token Law: Liquid Glass is applied only by the shared visual layer" \
  '\.glassEffect\(' \
  'LifeBoard/Foundation/Design/LifeBoardAtmosphereRenderer.swift' \
  'LifeBoard/DesignSystem/' \
  'Packages/LifeBoardTokens/'

# The rule above bans the SwiftUI primitive, which feature code never calls
# directly — it calls `lifeBoardSystemGlass`, the app's own wrapper. So the
# glass law was unenforceable in exactly the place it mattered, and 16 feature
# files reached for glass on ordinary content while CI stayed green. DESIGN.md
# gives glass to the hero, the dock, the composer and the lens rails; those all
# live in the shell and the design system, which are excluded here.
#
# A ratchet like every other rule: the existing sites stay, no new one may join
# them.
scan_added_lines \
  "Token Law: glass belongs to the hero and to chrome, not to feature content" \
  'lifeBoardSystemGlass\(|lifeBoardGlassSurface\(' \
  'LifeBoard/DesignSystem/' \
  'LifeBoard/LifeBoardDesign/' \
  'LifeBoard/Foundation/Navigation/' \
  'LifeBoard/Foundation/Design/' \
  'LifeBoard/Shared/UI/' \
  'Packages/'

scan_added_lines \
  "Token Law: production chrome must not introduce Clear Liquid Glass" \
  'lifeBoardSystemGlass\(\.clear|glassEffect\(\.clear'

scan_added_lines \
  "Motion Law: feature code uses semantic motion tokens, not raw springs" \
  '\.spring\(' \
  'LifeBoard/DesignSystem/'

scan_added_lines \
  "Motion Law: retired generic motion aliases cannot return" \
  'LifeBoardMotionProfile\.(bouncy|snappy|expressive)|LifeBoardAnimation\.(bouncy|snappy|expressive)'

# A ratchet, not a gate on the endpoint. The app has four vocabularies for one
# palette; the canonical one is `Color.lifeboard(_ role:)`. Existing call sites
# stay put — there are ~1,200 of them and rewriting them in one pass is a
# merge-conflict machine — but no NEW line may add to the debt. See
# LifeBoard/DesignSystem/TokenBridge.swift for the mapping, and
# TokenBridgeEquivalenceTests for the proof that migrating is a rename.
#
# This rule used to name `LBColorTokens`, a symbol with zero occurrences
# anywhere in the repository — so it had been passing vacuously for as long as
# it had existed while the vocabulary that actually carries the debt,
# `ClayColorTokens` (438 call sites, self-documented as legacy), went ungated.
scan_added_lines \
  "Token Law: new code uses semantic colour roles, not the legacy vocabularies" \
  'ClayColorTokens\.' \
  'LifeBoard/LifeBoardDesign/Tokens/ClayColorTokens.swift'

# --- Shape, rhythm and stock-chrome ratchets ---------------------------------
#
# None of the drift below was visible to CI, and all of it is large:
# 244 of 507 corner radii and roughly 1,319 of 2,510 spacing literals were off
# their respective scales. These are seeded at the existing counts, so nothing
# has to be fixed to land a change — but nothing new may be added either.
#
# The bad values are enumerated rather than negated because `rg` uses the Rust
# regex engine, which has no lookahead.

scan_added_lines \
  "Shape Law: corner radii come from the DESIGN.md vocabulary (14/16/20/24/28/30/pill)" \
  'cornerRadius: ?(0|1|2|3|4|5|6|7|8|9|10|11|12|13|15|17|18|19|21|22|23|25|26|27|29|31|32|33|34|35|36)\b'

scan_added_lines \
  "Rhythm Law: spacing uses the 4/8/12/16/20/24/32/40 scale" \
  'padding\((\.[a-zA-Z]+, ?)?(1|2|3|5|6|7|9|10|11|13|14|15|17|18|19|21|22|23|25|26|27|28|29|30|31|33|34|35|36|37|38|39)\)|spacing: ?(1|2|3|5|6|7|9|10|11|13|14|15|17|18|19|21|22|23|25|26|27|28|29|30|31|33|34|35|36|37|38|39)\b'

# DESIGN.md: "Never shrink type to preserve a card grid or one-line toolbar."
# At accessibility sizes the fix is to reflow, not to scale the glyphs down.
scan_added_lines \
  "Type Law: text reflows rather than shrinking to fit" \
  '\.minimumScaleFactor\('

# DESIGN.md: "Do not use uppercase for personality or hierarchy."
scan_added_lines \
  "Type Law: no uppercase for hierarchy" \
  '\.textCase\(\.uppercase\)|\.uppercased\(\)' \
  'LifeBoard/Foundation/LifeOSFoundationContracts.swift'

# Stock iOS controls render as system chrome, not as clay: a `Toggle` is the
# green iOS switch, which is the most visually foreign element in a cocoa and
# sun palette. The design-system replacements are the work of a later phase;
# this stops the debt growing while that happens.
scan_added_lines \
  "Surface Law: interactive controls come from the design system, not from stock UIKit chrome" \
  '\.buttonStyle\(\.bordered|\.buttonStyle\(\.borderedProminent\)|^\s*Form \{|^\s*List \{'

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Token-law guardrails failed on newly added violations. Existing debt remains baselined in git history."
  exit 1
fi

echo "✅ Token-law guardrails passed for changed UI lines."
