#!/usr/bin/env python3
"""Audit LifeBoard image assets against source and project references.

The default command is read-only and emits a reviewable JSON manifest. Use
--fail-on-orphans in CI. Deletion is intentionally not automated: the manifest
must be reviewed before catalog folders are removed from source control.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


SOURCE_SUFFIXES = {
    ".swift", ".m", ".mm", ".h", ".storyboard", ".xib", ".plist",
    ".pbxproj", ".xcstrings", ".json", ".md",
}

PROTECTED_NAMES = {
    "LifeBoardLogo",
    "LifeBoardSplashIcon",
}

PROTECTED_PREFIXES = (
    "AppIcon",
    "Launch",
)

PROTECTED_PATH_PARTS = (
    # Mood artwork is addressed through a runtime stem/size table.
    ("LifeBoardJournal", "Moods"),
)

SUPERSEDED = {
    "HomeScenicNoSun",
    "PlanScenicNoSun",
    "SunDay",
    "SunDayPlan",
}


def source_corpus(root: Path, catalog: Path) -> str:
    chunks: list[str] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if catalog in path.parents or ".git" in path.parts:
            continue
        try:
            chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            continue
    return "\n".join(chunks)


def is_referenced(name: str, corpus: str) -> bool:
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", corpus) is not None


def audit(root: Path, catalog: Path) -> dict[str, object]:
    corpus = source_corpus(root, catalog)
    entries: list[dict[str, object]] = []
    for imageset in sorted(catalog.rglob("*.imageset")):
        name = imageset.stem
        protected = (
            name in PROTECTED_NAMES
            or name.startswith(PROTECTED_PREFIXES)
            or any(all(part in imageset.parts for part in path_parts) for path_parts in PROTECTED_PATH_PARTS)
        )
        referenced = is_referenced(name, corpus)
        status = (
            "superseded" if name in SUPERSEDED else
            "protected" if protected else
            "referenced" if referenced else
            "unreachable"
        )
        entries.append({
            "name": name,
            "path": str(imageset.relative_to(root)),
            "status": status,
            "referenced": referenced,
            "protected": protected,
        })

    return {
        "catalog": str(catalog.relative_to(root)),
        "counts": {
            status: sum(1 for entry in entries if entry["status"] == status)
            for status in ("referenced", "protected", "superseded", "unreachable")
        },
        "entries": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--catalog", type=Path, default=Path("LifeBoard/Assets.xcassets"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--fail-on-orphans", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    catalog = args.catalog if args.catalog.is_absolute() else root / args.catalog
    manifest = audit(root, catalog.resolve())
    payload = json.dumps(manifest, indent=2) + "\n"
    if args.output:
        output = args.output if args.output.is_absolute() else root / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")

    if args.fail_on_orphans and manifest["counts"]["unreachable"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
