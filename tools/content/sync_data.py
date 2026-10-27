#!/usr/bin/env python3
"""Mirror the runtime content from data/ into godot/data/.

`data/` is the source of truth used by the generation and validation tools.
Godot can only load resources from inside the project folder, so the game
reads its missions and worlds from `godot/data/`. This script keeps the two
copies byte-identical and fails when they drift.

Usage:
    python3 tools/content/sync_data.py           # copy data/ -> godot/data/
    python3 tools/content/sync_data.py --check   # exit 1 if they differ
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data"
TARGET = ROOT / "godot" / "data"
RUNTIME_DIRS = ("missions", "worlds")


def iter_source_files():
    for name in RUNTIME_DIRS:
        folder = SOURCE / name
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                yield path.relative_to(SOURCE)


def check() -> int:
    problems: list[str] = []
    expected = set()
    for rel in iter_source_files():
        expected.add(rel)
        target = TARGET / rel
        if not target.is_file():
            problems.append(f"missing in godot/data: {rel}")
        elif not filecmp.cmp(SOURCE / rel, target, shallow=False):
            problems.append(f"out of date: {rel}")

    for name in RUNTIME_DIRS:
        folder = TARGET / name
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                rel = path.relative_to(TARGET)
                if rel not in expected:
                    problems.append(f"extra file in godot/data: {rel}")

    if problems:
        print("godot/data is not in sync with data/:")
        for problem in problems[:40]:
            print("  -", problem)
        if len(problems) > 40:
            print(f"  ... and {len(problems) - 40} more")
        print("Run: python3 tools/content/sync_data.py")
        return 1
    print(f"godot/data is in sync ({len(expected)} files).")
    return 0


def sync() -> int:
    changed = 0
    for rel in iter_source_files():
        src = SOURCE / rel
        dst = TARGET / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.is_file() and filecmp.cmp(src, dst, shallow=False):
            continue
        shutil.copy2(src, dst)
        changed += 1
        print("updated", rel)

    expected = set(iter_source_files())
    for name in RUNTIME_DIRS:
        folder = TARGET / name
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*")):
            if path.is_file() and path.relative_to(TARGET) not in expected:
                path.unlink()
                changed += 1
                print("removed", path.relative_to(TARGET))

    print(f"sync complete: {changed} file(s) changed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="only verify, do not copy")
    args = parser.parse_args()
    return check() if args.check else sync()


if __name__ == "__main__":
    sys.exit(main())
