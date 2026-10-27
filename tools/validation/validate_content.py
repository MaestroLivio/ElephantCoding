#!/usr/bin/env python3
"""Structural validation for the mission and world content.

This is a fast, dependency-free gate that runs before the Godot test suite.
It checks that every mission is well formed and that the nine worlds reference
exactly the 90 missions, with no orphan or duplicated id.

Usage:
    python3 tools/validation/validate_content.py
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MISSIONS_DIR = ROOT / "data" / "missions"
WORLDS_DIR = ROOT / "data" / "worlds"

MISSION_ID = re.compile(r"^(INF|P[1-5]|S[1-3])-\d{2}$")
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")

REQUIRED_MISSION_KEYS = {
    "schema_version", "id", "world", "school_level", "age_hint", "title",
    "editor", "narrative", "coding_goal", "math_objective", "success_text",
    "grid", "spawn", "goal", "reference_program", "tests", "hints",
    "narration_line", "scene_theme",
}
REQUIRED_WORLD_KEYS = {
    "id", "code", "title", "age", "language", "editor", "description",
    "mission_ids", "theme", "lab",
}
EDITORS = {"icons", "beads", "text", "structured", "coordinates", "pseudocode", "systems", "data"}
GOAL_KEYS = {
    "reach", "collect_all", "activate_all", "photo_all", "visit_order",
    "trace_closed", "vars", "min_vars", "event_counts",
}

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def load(folder: Path, label: str) -> list[dict]:
    items = []
    for path in sorted(folder.glob("*.json")):
        if path.name == "source_catalog.json":
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail(f"{label} {path.name}: invalid JSON ({exc})")
            continue
        data["_file"] = path.name
        items.append(data)
    return items


def check_color(where: str, value, key: str) -> None:
    if not isinstance(value, str) or not HEX_COLOR.match(value):
        fail(f"{where}: scene_theme.{key} must be a #rrggbb string, got {value!r}")


def check_mission(m: dict) -> None:
    where = f"mission {m.get('id', m.get('_file'))}"
    missing = REQUIRED_MISSION_KEYS - set(m)
    if missing:
        fail(f"{where}: missing keys {sorted(missing)}")
        return

    if not MISSION_ID.match(str(m["id"])):
        fail(f"{where}: invalid id")
    if m["schema_version"] != 1:
        fail(f"{where}: unsupported schema_version {m['schema_version']}")
    if m["editor"] not in EDITORS:
        fail(f"{where}: unknown editor {m['editor']!r}")

    grid = m["grid"]
    for key in ("min_x", "min_y", "max_x", "max_y"):
        if not isinstance(grid.get(key), int):
            fail(f"{where}: grid.{key} must be an integer")
    if grid.get("max_x", 0) < grid.get("min_x", 0) or grid.get("max_y", 0) < grid.get("min_y", 0):
        fail(f"{where}: empty grid")

    spawn = m.get("spawn", {})
    cell = spawn.get("cell", [])
    if len(cell) != 2 or not all(isinstance(v, int) for v in cell):
        fail(f"{where}: spawn.cell must be [x, y]")
    elif not (grid["min_x"] <= cell[0] <= grid["max_x"] and grid["min_y"] <= cell[1] <= grid["max_y"]):
        fail(f"{where}: spawn.cell {cell} is outside the grid")
    if spawn.get("heading") not in {"N", "E", "S", "W"}:
        fail(f"{where}: spawn.heading must be N/E/S/W")

    for entity in m.get("entities", []):
        ecell = entity.get("cell", [])
        if len(ecell) != 2:
            fail(f"{where}: entity {entity.get('id')} has no cell")
        elif not (grid["min_x"] <= ecell[0] <= grid["max_x"] and grid["min_y"] <= ecell[1] <= grid["max_y"]):
            fail(f"{where}: entity {entity.get('id')} is outside the grid")

    goal = m["goal"]
    if not (set(goal) & GOAL_KEYS):
        fail(f"{where}: goal has no recognised condition")
    if "reach" in goal and len(goal["reach"]) != 2:
        fail(f"{where}: goal.reach must be [x, y]")

    if not str(m["reference_program"]).strip():
        fail(f"{where}: empty reference_program")
    if not m["tests"]:
        fail(f"{where}: no tests")
    for test in m["tests"]:
        if not test.get("name") or "program" not in test or "expect_success" not in test:
            fail(f"{where}: malformed test {test!r}")

    hints = m["hints"]
    if len(hints) < 3:
        fail(f"{where}: expected at least 3 hints, found {len(hints)}")
    if [h.get("level") for h in hints] != list(range(1, len(hints) + 1)):
        fail(f"{where}: hint levels must be sequential from 1")

    theme = m["scene_theme"]
    for key in ("sky", "ground", "accent"):
        check_color(where, theme.get(key), key)
    if not theme.get("prop"):
        fail(f"{where}: scene_theme.prop is required")


def check_world(w: dict, missions: dict[str, dict]) -> None:
    where = f"world {w.get('id', '?')}"
    missing = REQUIRED_WORLD_KEYS - set(w)
    if missing:
        fail(f"{where}: missing keys {sorted(missing)}")
        return
    if w["editor"] not in EDITORS:
        fail(f"{where}: unknown editor {w['editor']!r}")
    ids = w.get("mission_ids", [])
    if len(ids) != 10:
        fail(f"{where}: expected 10 missions, found {len(ids)}")
    if len(set(ids)) != len(ids):
        fail(f"{where}: duplicate mission ids")
    for mission_id in ids:
        if mission_id not in missions:
            fail(f"{where}: references unknown mission {mission_id}")
        elif missions[mission_id]["world"] != w["id"]:
            fail(f"{where}: mission {mission_id} declares world {missions[mission_id]['world']!r}")
    for key in ("sky", "ground", "accent"):
        check_color(where, w.get("theme", {}).get(key), key)


def main() -> int:
    missions = load(MISSIONS_DIR, "mission")
    worlds = load(WORLDS_DIR, "world")

    if len(missions) != 90:
        fail(f"expected 90 missions, found {len(missions)}")
    if len(worlds) != 9:
        fail(f"expected 9 worlds, found {len(worlds)}")

    by_id: dict[str, dict] = {}
    for m in missions:
        mission_id = str(m.get("id", ""))
        if mission_id in by_id:
            fail(f"duplicate mission id {mission_id}")
        by_id[mission_id] = m
        check_mission(m)

    listed: Counter[str] = Counter()
    for w in worlds:
        check_world(w, by_id)
        listed.update(w.get("mission_ids", []))
    for mission_id in by_id:
        if listed[mission_id] == 0:
            fail(f"mission {mission_id} is not listed in any world")
        elif listed[mission_id] > 1:
            fail(f"mission {mission_id} is listed in {listed[mission_id]} worlds")

    if errors:
        print(f"Content validation FAILED with {len(errors)} problem(s):")
        for error in errors:
            print("  -", error)
        return 1

    print(f"Content validation passed: {len(by_id)} missions, {len(worlds)} worlds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
