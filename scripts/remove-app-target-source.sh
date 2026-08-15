#!/usr/bin/env bash
#
# Remove one Swift file from the LifeBoard app target's Sources phase.
#
# The inverse of `add-app-target-source.sh`, and the reason it exists: the
# project is objectVersion 60 with no filesystem-synchronized groups, so a file
# is wired in through four separate pbxproj entries (PBXBuildFile,
# PBXFileReference, group child, Sources phase member). Deleting a file without
# removing all four leaves "Build input file cannot be found", and doing it by
# hand across a dozen files is how a project file gets corrupted — especially
# for the `Foo+Bar.swift` names this repo uses, which `add-app-target-source.sh`
# refuses precisely because a bare `+` needs pbxproj quoting.
#
# Unlike the add script, this one accepts any basename: it never *writes* a
# name or path, it only deletes lines that already exist.
#
# Usage: bash scripts/remove-app-target-source.sh LifeBoard/Features/Foo/Bar.swift
#        bash scripts/remove-app-target-source.sh --dry-run <path>

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

REL_PATH="${1:?usage: remove-app-target-source.sh [--dry-run] <path-relative-to-repo-root>}"
PBXPROJ="LifeBoard.xcodeproj/project.pbxproj"

python3 - "$PBXPROJ" "$REL_PATH" "$DRY_RUN" <<'PY'
import re, sys

pbx, rel, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
text = open(pbx).read()
lines = text.split("\n")

# The file reference is the anchor. Two wiring conventions coexist in this
# project and both have to be recognised:
#
#   path = LifeBoard/Features/.../Foo.swift;              sourceTree = SOURCE_ROOT
#   path = "Features/.../Foo+Bar.swift";                  sourceTree = "<group>"
#
# The second is quoted (a bare `+` needs it) and group-relative, so an exact
# `path = {rel};` match silently finds nothing — which reads as "already
# removed" and leaves all four entries in place.
#
# Matching still requires the basename to be identical *and* the declared path
# to be a suffix of the real one, so two same-named files in different
# directories cannot delete each other's entries.
basename = rel.rsplit("/", 1)[-1]

def declared_path(line):
    m = re.search(r'\bpath = (?:"([^"]*)"|([^;\s]+));', line)
    if not m:
        return None
    return m.group(1) or m.group(2)

file_ref = None
for line in lines:
    if "isa = PBXFileReference" not in line:
        continue
    declared = declared_path(line)
    if declared is None or declared.rsplit("/", 1)[-1] != basename:
        continue
    if declared == rel or rel.endswith("/" + declared):
        m = re.match(r"\s*([0-9A-F]{24})\s", line)
        if m:
            file_ref = m.group(1)
            break

if file_ref is None:
    print(f"✅ {rel} is not a member (nothing to remove).")
    sys.exit(0)

# The build-file entry points at the file reference; find its id too.
build_file = None
for line in lines:
    if f"fileRef = {file_ref} " in line and "isa = PBXBuildFile" in line:
        m = re.match(r"\s*([0-9A-F]{24})\s", line)
        if m:
            build_file = m.group(1)
            break

doomed = {file_ref}
if build_file:
    doomed.add(build_file)

kept, removed = [], []
for line in lines:
    m = re.search(r"\b([0-9A-F]{24})\b", line)
    if m and m.group(1) in doomed:
        removed.append(line.strip())
        continue
    kept.append(line)

print(f"{'[dry-run] ' if dry else ''}{rel}")
print(f"  fileRef={file_ref} buildFile={build_file or '(none)'}  removing {len(removed)} lines")
for r in removed:
    print(f"    - {r[:110]}")

if len(removed) != 4:
    # 4 is the expected shape. Anything else means the file was wired up
    # unusually (or is referenced by a second target), and a blind delete could
    # silently drop another target's membership.
    print(f"  ⚠️  expected 4 lines, found {len(removed)} — inspect before trusting this.", file=sys.stderr)

if not dry:
    open(pbx, "w").write("\n".join(kept))
PY
