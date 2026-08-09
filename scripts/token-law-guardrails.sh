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
trap 'rm -f "$BASE_TREE_LIST"' EXIT
git ls-tree -r --name-only "$BASE_SHA" > "$BASE_TREE_LIST"

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

    local additions
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      additions="$(git diff --unified=0 "$BASE_SHA" -- "$file" | rg '^\+[^+]' || true)"
    else
      additions="$(sed 's/^/+/' "$file")"
    fi
    local output
    output="$(printf '%s\n' "$additions" | rg -n "$regex" || true)"

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
      base_blob="$(git show "$BASE_SHA:$file" 2>/dev/null || true)"
      if [[ -z "$base_blob" ]]; then
        # The file is new at this path — usually a rename. Comparing against a
        # path that did not exist makes every relocated violation look new, which
        # is precisely the false positive this block exists to prevent. Fall back
        # to the same basename anywhere in the base tree.
        local base_path
        # Literal comparison: basenames contain `+` (e.g.
        # MessageView+AssistantAndUserBubble.swift), which a regex reads as a
        # quantifier and silently fails to match.
        base_path="$(awk -v b="${file##*/}" 'index($0, "/" b) && substr($0, length($0) - length(b) + 1) == b' "$BASE_TREE_LIST" | head -1 || true)"
        [[ -n "$base_path" ]] && base_blob="$(git show "$BASE_SHA:$base_path" 2>/dev/null || true)"
      fi
      if [[ -n "$base_blob" ]]; then
        base_count="$(printf '%s' "$base_blob" | rg -c "$regex" || true)"
        current_count="$(rg -c "$regex" "$file" || true)"
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

scan_added_lines \
  "Token Law: no raw UIColor constructors in UI modules" \
  '\bUIColor\s*\(' \
  'LifeBoard/Foundation/Design/LifeBoardDaypartTokens.swift'

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
  'LifeBoard/DesignSystem/'

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
scan_added_lines \
  "Token Law: new code uses semantic colour roles, not the legacy vocabularies" \
  'LBColorTokens\.' \
  'LifeBoard/LifeBoardDesign/Tokens/LBColorTokens.swift'

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Token-law guardrails failed on newly added violations. Existing debt remains baselined in git history."
  exit 1
fi

echo "✅ Token-law guardrails passed for changed UI lines."
