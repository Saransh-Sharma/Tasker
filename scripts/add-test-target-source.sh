#!/usr/bin/env bash
#
# Add one Swift file to the LifeBoardTests target's Sources phase.
#
# The sibling of scripts/add-app-target-source.sh. The project is objectVersion
# 60 — no filesystem-synchronized groups — so a new test file compiles only if
# four separate entries exist: a PBXBuildFile, a PBXFileReference, a group
# child, and a Sources phase member. A missing fourth entry is silent: the file
# sits in the repo, the suite goes green, and the test never ran.
#
# Usage: bash scripts/add-test-target-source.sh LifeBoardTests/Foo/BarTests.swift

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REL_PATH="${1:?usage: add-test-target-source.sh <path-relative-to-repo-root>}"
PBXPROJ="LifeBoard.xcodeproj/project.pbxproj"

[[ -f "$REL_PATH" ]] || { echo "❌ No such file: $REL_PATH" >&2; exit 1; }

BASENAME="${REL_PATH##*/}"
# Same quoting guard as the app-target script: a bare `+` or space in a pbxproj
# value corrupts the whole file rather than just that line.
if [[ ! "$BASENAME" =~ ^[A-Za-z0-9_]+\.swift$ ]]; then
  echo "❌ Refusing: '$BASENAME' has characters that need pbxproj quoting." >&2
  exit 1
fi

if rg -q "path = ${REL_PATH};" "$PBXPROJ"; then
  echo "✅ $REL_PATH is already a member."
  exit 0
fi

LAST_HEX="$(rg -o 'A310000000000000000([0-9A-F]{5})' -r '$1' "$PBXPROJ" | sort -u | tail -1)"
NEXT=$((16#$LAST_HEX + 1))
FILE_REF="$(printf 'A310000000000000000%05X' "$NEXT")"
BUILD_FILE="$(printf 'A310000000000000000%05X' "$((NEXT + 1))")"

ANCHOR="SetupCenterFocusTests.swift"
ANCHOR_REF="$(rg -o "A310000000000000000[0-9A-F]{5} /\* ${ANCHOR} \*/ = \{isa = PBXFileReference" "$PBXPROJ" | head -1 | grep -o 'A310000000000000000[0-9A-F]\{5\}')"
ANCHOR_BUILD="$(rg -o "A310000000000000000[0-9A-F]{5} /\* ${ANCHOR} in Sources \*/ = \{isa = PBXBuildFile" "$PBXPROJ" | head -1 | grep -o 'A310000000000000000[0-9A-F]\{5\}')"

python3 - "$PBXPROJ" "$REL_PATH" "$BASENAME" "$FILE_REF" "$BUILD_FILE" "$ANCHOR_REF" "$ANCHOR_BUILD" "$ANCHOR" <<'PY'
import sys

pbx, rel, base, file_ref, build_file, anchor_ref, anchor_build, anchor = sys.argv[1:9]
text = open(pbx).read()

build_line = f"\t\t{build_file} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref} /* {base} */; }};\n"
ref_line = (f"\t\t{file_ref} /* {base} */ = {{isa = PBXFileReference; includeInIndex = 1; "
            f"lastKnownFileType = sourcecode.swift; name = {base}; path = {rel}; sourceTree = SOURCE_ROOT; }};\n")

marker = f"\t\t{anchor_build} /* {anchor} in Sources */ = {{isa = PBXBuildFile"
idx = text.index(marker)
text = text[:idx] + build_line + text[idx:]

marker = f"\t\t{anchor_ref} /* {anchor} */ = {{isa = PBXFileReference"
idx = text.index(marker)
text = text[:idx] + ref_line + text[idx:]

before = text
text = text.replace(
    f"\t\t\t\t{anchor_ref} /* {anchor} */,\n",
    f"\t\t\t\t{anchor_ref} /* {anchor} */,\n\t\t\t\t{file_ref} /* {base} */,\n",
    1,
)
assert text != before, "group child anchor not found"

before = text
text = text.replace(
    f"\t\t\t\t{anchor_build} /* {anchor} in Sources */,\n",
    f"\t\t\t\t{anchor_build} /* {anchor} in Sources */,\n\t\t\t\t{build_file} /* {base} in Sources */,\n",
    1,
)
assert text != before, "Sources phase anchor not found"

open(pbx, "w").write(text)
PY

plutil -lint "$PBXPROJ" >/dev/null
echo "✅ Added $REL_PATH (fileRef $FILE_REF, buildFile $BUILD_FILE)"
