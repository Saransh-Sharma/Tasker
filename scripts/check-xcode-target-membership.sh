#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/LifeBoard.xcodeproj/project.pbxproj"
ALLOWLIST_FILE="$ROOT_DIR/scripts/xcode-target-membership-allowlist.txt"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "error: missing project file: $PROJECT_FILE" >&2
  exit 1
fi

allowlisted_paths=()
if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    allowlisted_paths+=("$line")
  done < "$ALLOWLIST_FILE"
fi

is_allowlisted() {
  local candidate="$1"
  local allowlisted
  for allowlisted in "${allowlisted_paths[@]}"; do
    [[ "$candidate" == "$allowlisted" ]] && return 0
  done
  return 1
}

swift_roots=(
  "LifeBoard"
  "LifeBoardTests"
  "LifeBoardUITests"
  "LifeBoardWatch"
  "LifeBoardWatchWidgets"
  "LifeBoardWidgets"
  "Shared"
)

swift_files=()
for root in "${swift_roots[@]}"; do
  [[ -d "$ROOT_DIR/$root" ]] || continue
  while IFS= read -r file; do
    swift_files+=("$file")
  done < <(cd "$ROOT_DIR" && find "$root" -type f -name "*.swift" | sort)
done

missing_paths=()
allowed_missing_paths=()
for file in "${swift_files[@]}"; do
  basename="${file##*/}"
  if ! grep -Fq "$basename" "$PROJECT_FILE"; then
    if is_allowlisted "$file"; then
      allowed_missing_paths+=("$file")
    else
      missing_paths+=("$file")
    fi
  fi
done

if (( ${#allowed_missing_paths[@]} > 0 )); then
  echo "Allowed Swift files not referenced by LifeBoard.xcodeproj:"
  printf '  %s\n' "${allowed_missing_paths[@]}"
fi

if (( ${#missing_paths[@]} > 0 )); then
  echo "error: Swift files not referenced by LifeBoard.xcodeproj:" >&2
  printf '  %s\n' "${missing_paths[@]}" >&2
  echo "Resolve each file by adding it to a target, moving it to test support, deleting it, or adding a justified allowlist entry." >&2
  exit 1
fi

echo "Xcode target membership check passed."
