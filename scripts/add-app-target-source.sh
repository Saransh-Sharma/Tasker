#!/usr/bin/env bash
#
# Add one Swift file to the LifeBoard app target's Sources phase.
#
# The project is still objectVersion 60 — no filesystem-synchronized groups — so
# a new file under LifeBoard/ compiles only if four separate entries exist:
# a PBXBuildFile, a PBXFileReference, a group child, and a Sources phase member.
# Doing that by hand four times per file is how a target-membership gap ships.
#
# Usage: bash scripts/add-app-target-source.sh LifeBoard/DesignSystem/Foo.swift
#
# Note on quoting: the `name`/`path` values are written unquoted, which is only
# safe because this script rejects any basename outside [A-Za-z0-9_.]. A bare `+`
# or space in a pbxproj value corrupts the whole file rather than just that line.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REL_PATH="${1:?usage: add-app-target-source.sh <path-relative-to-repo-root>}"
PBXPROJ="LifeBoard.xcodeproj/project.pbxproj"

[[ -f "$REL_PATH" ]] || { echo "❌ No such file: $REL_PATH" >&2; exit 1; }

BASENAME="${REL_PATH##*/}"
if [[ ! "$BASENAME" =~ ^[A-Za-z0-9_]+\.swift$ ]]; then
  echo "❌ Refusing: '$BASENAME' has characters that need pbxproj quoting." >&2
  exit 1
fi

if rg -q "path = ${REL_PATH};" "$PBXPROJ"; then
  echo "✅ $REL_PATH is already a member."
  exit 0
fi

# Next two IDs in the repo's own A310…-prefixed series.
LAST_HEX="$(rg -o 'A310000000000000000([0-9A-F]{5})' -r '$1' "$PBXPROJ" | sort -u | tail -1)"
NEXT=$((16#$LAST_HEX + 1))
FILE_REF="$(printf 'A310000000000000000%05X' "$NEXT")"
BUILD_FILE="$(printf 'A310000000000000000%05X' "$((NEXT + 1))")"

# The group and Sources-phase anchors: reuse the ones TokenBridge.swift sits in,
# which is the DesignSystem group and the app target's Sources phase.
ANCHOR_REF="$(rg -o 'A310000000000000000[0-9A-F]{5} /\* LifeBoardTokenBridge\.swift \*/' "$PBXPROJ" | head -1 | cut -d' ' -f1)"
ANCHOR_BUILD="$(rg -n 'A310000000000000000[0-9A-F]{5} /\* LifeBoardTokenBridge\.swift in Sources \*/ = \{isa = PBXBuildFile' "$PBXPROJ" | head -1 | grep -o 'A310000000000000000[0-9A-F]\{5\}' | head -1)"

python3 - "$PBXPROJ" "$REL_PATH" "$BASENAME" "$FILE_REF" "$BUILD_FILE" "$ANCHOR_REF" "$ANCHOR_BUILD" <<'PY'
import sys

pbx, rel, base, file_ref, build_file, anchor_ref, anchor_build = sys.argv[1:8]
text = open(pbx).read()

build_line = f"\t\t{build_file} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref} /* {base} */; }};\n"
ref_line = (f"\t\t{file_ref} /* {base} */ = {{isa = PBXFileReference; includeInIndex = 1; "
            f"lastKnownFileType = sourcecode.swift; name = {base}; path = {rel}; sourceTree = SOURCE_ROOT; }};\n")

# 1. PBXBuildFile section, immediately before the anchor's build entry.
marker = f"\t\t{anchor_build} /* LifeBoardTokenBridge.swift in Sources */ = {{isa = PBXBuildFile"
idx = text.index(marker)
text = text[:idx] + build_line + text[idx:]

# 2. PBXFileReference section.
marker = f"\t\t{anchor_ref} /* LifeBoardTokenBridge.swift */ = {{isa = PBXFileReference"
idx = text.index(marker)
text = text[:idx] + ref_line + text[idx:]

# 3. Group children, and 4. Sources build phase — both are plain child lists.
text = text.replace(
    f"\t\t\t\t{anchor_ref} /* LifeBoardTokenBridge.swift */,\n",
    f"\t\t\t\t{anchor_ref} /* LifeBoardTokenBridge.swift */,\n\t\t\t\t{file_ref} /* {base} */,\n",
    1,
)
text = text.replace(
    f"\t\t\t\t{anchor_build} /* LifeBoardTokenBridge.swift in Sources */,\n",
    f"\t\t\t\t{anchor_build} /* LifeBoardTokenBridge.swift in Sources */,\n\t\t\t\t{build_file} /* {base} in Sources */,\n",
    1,
)

open(pbx, "w").write(text)
PY

# A malformed pbxproj is unrecoverable by hand, so prove it still parses.
plutil -lint "$PBXPROJ" >/dev/null
echo "✅ Added $REL_PATH (fileRef $FILE_REF, buildFile $BUILD_FILE)"
