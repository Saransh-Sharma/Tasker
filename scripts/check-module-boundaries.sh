#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lifeboard-paths.env
source "$SCRIPT_DIR/lifeboard-paths.env"
cd "$LIFEBOARD_ROOT_DIR"

failed=0

EXCEPTIONS_FILE="$SCRIPT_DIR/module-boundary-exceptions.txt"

# An exception is keyed on `<path>\t<import>` so it suppresses one banned import
# in one file and nothing else. A file that later grows a *second* violation
# still fails, which is the property that keeps this from decaying into a
# blanket allowlist.
is_excepted() {
  local file="$1" module="$2"
  [[ -f "$EXCEPTIONS_FILE" ]] || return 1
  grep -qxF "${file}	${module}" "$EXCEPTIONS_FILE"
}

fail_matches() {
  local label="$1"
  local pattern="$2"
  shift 2
  local matches unexcepted=""
  matches="$(rg -n "$pattern" "$@" -g '*.swift' || true)"
  [[ -n "$matches" ]] || return 0

  local line file module
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    file="${line%%:*}"
    module="${line##*import }"
    if ! is_excepted "$file" "$module"; then
      unexcepted+="${line}"$'\n'
    fi
  done <<< "$matches"

  if [[ -n "$unexcepted" ]]; then
    printf 'error: %s\n%s' "$label" "$unexcepted" >&2
    failed=1
  fi
}

# The current monolith already has a useful, enforceable core boundary. Keep
# it intact while package extraction is staged.
# Domain is now Packages/LifeBoardDomain. The rule is the same and the compiler
# enforces most of it, but the import ban is still worth asserting: nothing here
# may reach for a UI or persistence framework.
fail_matches \
  'LifeBoardDomain must not import UI or persistence frameworks.' \
  '^import (SwiftUI|UIKit|CoreData)$' \
  Packages/LifeBoardDomain/Sources

fail_matches \
  'LifeBoardTokens must not import CoreData.' \
  '^import CoreData$' \
  Packages/LifeBoardTokens/Sources

fail_matches \
  'LifeBoardContracts must not import UI or persistence frameworks.' \
  '^import (SwiftUI|UIKit|CoreData)$' \
  Packages/LifeBoardContracts/Sources

# Feature targets are added one at a time. These checks deliberately activate
# only once a feature exists, allowing the script to land before the package
# migration without a fictional baseline.
# Features live under LifeBoard/, not the repo root. Pointed at the wrong path
# these rules silently never ran.
if [[ -d LifeBoard/Features ]]; then
  while IFS= read -r -d '' domain; do
    fail_matches "${domain} must not import UI or persistence frameworks." '^import (SwiftUI|UIKit|CoreData)$' "$domain"
  done < <(find LifeBoard/Features -type d -path '*/Domain' -print0)

  while IFS= read -r -d '' data; do
    fail_matches "${data} must not import UI frameworks." '^import (SwiftUI|UIKit)$' "$data"
  done < <(find LifeBoard/Features -type d -path '*/Data' -print0)

  while IFS= read -r -d '' ui; do
    fail_matches "${ui} must not import CoreData directly." '^import CoreData$' "$ui"
  done < <(find LifeBoard/Features -type d -path '*/UI' -print0)
fi

# The persistence boundary.
#
# `LifeBoardPersistence` could not be extracted as a SwiftPM package: eleven
# entities use Core Data `class` codegen, and classes generated inside a package
# are internal to it, so the app would lose access to `HabitDefinition` and its
# siblings. Converting those eleven to Manual/None and hand-writing public
# classes is a real change to the layer that owns user data, and is not a file
# move.
#
# The boundary itself does not depend on the package. Core Data may be imported
# from the persistence layer, from a feature's own `Data/` folder, and nowhere
# else. That is the same rule the package would have enforced, checked here
# instead of by the compiler.
CORE_DATA_OWNERS='^LifeBoard/(Persistence/|Features/[A-Za-z]+/Data/)'
trespassers=""
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  [[ "$file" =~ $CORE_DATA_OWNERS ]] && continue
  is_excepted "$file" "CoreData" && continue
  trespassers+="${file}"$'\n'
done < <(rg -l '^import CoreData$' --glob '*.swift' LifeBoard 2>/dev/null || true)

if [[ -n "$trespassers" ]]; then
  printf 'error: CoreData may only be imported from LifeBoard/Persistence/ or a feature Data/ folder.\n%s' "$trespassers" >&2
  failed=1
fi

if (( failed != 0 )); then
  exit 1
fi

echo 'Module-boundary check passed.'
