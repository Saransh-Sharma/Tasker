#!/usr/bin/env python3
"""Add new Swift files to the Xcode project.pbxproj file."""

import re
import secrets

PBXPROJ = "/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcodeproj/project.pbxproj"

FILES_TO_ADD = [
    "HomeDateHeaderView.swift",
    "WeeklyCalendarStripView.swift",
    "NextActionModule.swift",
]

REFERENCE_FILE = "HomeForedropView.swift"
REFERENCE_FILEREF_ID = "BF5D7161411B42651DF00D60"
REFERENCE_BUILDFILE_ID = "355015C0A77A72D864F1AC64"


def gen_id(existing_ids: set) -> str:
    while True:
        new_id = secrets.token_hex(12).upper()
        if new_id not in existing_ids:
            existing_ids.add(new_id)
            return new_id


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()

    existing_ids = set(re.findall(r'([0-9A-Fa-f]{24})', content))

    lines = content.split("\n")

    file_entries = []
    for filename in FILES_TO_ADD:
        fileref_id = gen_id(existing_ids)
        buildfile_id = gen_id(existing_ids)
        file_entries.append({
            "name": filename,
            "fileref_id": fileref_id,
            "buildfile_id": buildfile_id,
        })

    # 1. Add PBXBuildFile entries
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if REFERENCE_BUILDFILE_ID in line and "PBXBuildFile" in line:
            for entry in file_entries:
                new_lines.append(
                    '\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };'
                    % (entry["buildfile_id"], entry["name"], entry["fileref_id"], entry["name"])
                )
    lines = new_lines

    # 2. Add PBXFileReference entries
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if REFERENCE_FILEREF_ID in line and "PBXFileReference" in line:
            for entry in file_entries:
                new_lines.append(
                    '\t\t%s /* %s */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = %s; path = %s; sourceTree = "<group>"; };'
                    % (entry["fileref_id"], entry["name"], entry["name"], entry["name"])
                )
    lines = new_lines

    # 3. Add to PBXGroup (children list only, not PBXFileReference or PBXBuildFile lines)
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if REFERENCE_FILEREF_ID in line and "PBXFileReference" not in line and "PBXBuildFile" not in line and "isa" not in line:
            for entry in file_entries:
                new_lines.append('\t\t\t\t%s /* %s */,' % (entry["fileref_id"], entry["name"]))
    lines = new_lines

    # 4. Add to PBXSourcesBuildPhase
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if REFERENCE_BUILDFILE_ID in line and "PBXBuildFile" not in line and "isa" not in line:
            for entry in file_entries:
                new_lines.append('\t\t\t\t%s /* %s in Sources */,' % (entry["buildfile_id"], entry["name"]))
    lines = new_lines

    result = "\n".join(lines)

    with open(PBXPROJ, "w") as f:
        f.write(result)

    print("Successfully added files to project.pbxproj:")
    for entry in file_entries:
        print("  %s" % entry["name"])
        print("    FileRef ID:   %s" % entry["fileref_id"])
        print("    BuildFile ID: %s" % entry["buildfile_id"])


if __name__ == "__main__":
    main()
