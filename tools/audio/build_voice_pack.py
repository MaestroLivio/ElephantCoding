#!/usr/bin/env python3
"""Build and verify the Italian voice pack.

The game never downloads audio and never ships an unverified recording. This
tool is the single gate for voice assets:

*   ``--manifest``  rewrite ``data/locales/it/voice_manifest.json`` from the
    current mission/world data while preserving already installed packs;
*   ``--script``    write a CSV recording script with every line and its id;
*   ``--check``     validate licences, attribution and SHA-256 of every clip;
*   ``--install``   copy a verified pack into ``godot/assets/audio/voice/it/``
    and register it in the manifest.

Only CC BY 4.0, CC BY-SA 4.0 and CC0 1.0 clips are accepted, and every clip
must carry an author, a source URL and an attribution line. That keeps the
project's CC BY 4.0 distribution compatible and auditable.

Usage:
    python3 tools/audio/build_voice_pack.py --check
    python3 tools/audio/build_voice_pack.py --manifest --script
    python3 tools/audio/build_voice_pack.py --install /path/to/pack --metadata /path/to/clips.json

Metadata format for --install::

    {"clips": [
      {"id": "p1-01", "file": "p1-01.ogg", "voice": "Nome voce",
       "author": "Autore o studio", "source": "https://esempio.it/voce",
       "license": "CC BY 4.0",
       "attribution": "Voce: Nome voce (Autore), CC BY 4.0, URL"}
    ]}
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
GAME_VOICE_DIR = ROOT / "godot" / "assets" / "audio" / "voice" / "it"
MANIFEST = DATA / "locales" / "it" / "voice_manifest.json"
RECORDING_SCRIPT = DATA / "locales" / "it" / "recording_script.csv"

ALLOWED_LICENSES = ("CC BY 4.0", "CC BY-SA 4.0", "CC0 1.0")
AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac", ".m4a"}
FIXED_LINES = {
    "benvenuto": "Ciao! Sono Nilo. Insieme impareremo a programmare viaggiando per nove mondi.",
    "officina": "Benvenuto nell'officina dei robot. Scrivi un programma libero: Nilo lo eseguirà sulla griglia.",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def mission_files() -> list[dict]:
    out = []
    for path in sorted((DATA / "missions").glob("*.json")):
        if path.name == "source_catalog.json":
            continue
        out.append(load_json(path))
    return out


def world_files() -> list[dict]:
    return [load_json(p) for p in sorted((DATA / "worlds").glob("*.json"))]


def expected_lines() -> list[dict]:
    """Every line id the game asks Narration to speak, in a stable order."""
    lines: list[dict] = []
    for key, text in FIXED_LINES.items():
        lines.append({"id": key, "kind": "system", "ref": "ui", "text": text})
    lines.append({
        "id": "errore",
        "kind": "system",
        "ref": "ui",
        "text": "C'è un errore nel programma. Controlla il comando e riprova.",
    })
    for world in world_files():
        lines.append({
            "id": "mondo_" + str(world["id"]),
            "kind": "world",
            "ref": str(world["id"]),
            "text": f"{world['title']}. {world['description']}",
        })
    for mission in mission_files():
        base = str(mission["id"]).lower()
        lines.append({
            "id": base,
            "kind": "narration",
            "ref": str(mission["id"]),
            "text": str(mission["narration_line"]),
        })
        lines.append({
            "id": base + "_ok",
            "kind": "success",
            "ref": str(mission["id"]),
            "text": str(mission["success_text"]),
        })
        for hint in mission.get("hints", []):
            lines.append({
                "id": f"{base}_hint{int(hint['level'])}",
                "kind": "hint",
                "ref": str(mission["id"]),
                "text": str(hint["text"]),
            })
    return lines


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 256), b""):
            digest.update(block)
    return digest.hexdigest()


def base_manifest(lines: list[dict], packs: list[dict]) -> dict:
    kinds: dict[str, int] = {}
    for line in lines:
        kinds[line["kind"]] = kinds.get(line["kind"], 0) + 1
    return {
        "schema_version": 1,
        "locale": "it",
        "directory": "res://assets/audio/voice/it",
        "naming": "<line_id>.ogg",
        "policy": {
            "allowed_licenses": list(ALLOWED_LICENSES),
            "requires_attribution": True,
            "notes": [
                "Sono ammessi solo clip con licenza compatibile con la distribuzione CC BY 4.0 del progetto.",
                "Ogni clip deve indicare autore, URL della fonte e riga di attribuzione.",
                "Nessun audio di terze parti non verificato è incluso nel repository.",
                "Se un clip manca, il gioco mostra i sottotitoli e può usare la voce di sistema.",
            ],
        },
        "fallback": {
            "subtitles": True,
            "system_tts": "DisplayServer.tts (voce italiana del dispositivo)",
            "notes": "La voce del sistema non viene redistribuita con il gioco.",
        },
        "expected_lines": len(lines),
        "kinds": kinds,
        "bundled": any(pack.get("clips") for pack in packs),
        "packs": packs,
    }


def write_manifest() -> int:
    existing_packs: list[dict] = []
    if MANIFEST.is_file():
        try:
            existing_packs = list(load_json(MANIFEST).get("packs", []))
        except json.JSONDecodeError:
            print("warning: existing manifest is invalid, starting from an empty pack list")
    manifest = base_manifest(expected_lines(), existing_packs)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {MANIFEST.relative_to(ROOT)} ({manifest['expected_lines']} lines)")
    return 0


def write_script() -> int:
    lines = expected_lines()
    RECORDING_SCRIPT.parent.mkdir(parents=True, exist_ok=True)
    with RECORDING_SCRIPT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["line_id", "kind", "reference", "text"])
        for line in lines:
            writer.writerow([line["id"], line["kind"], line["ref"], line["text"]])
    print(f"wrote {RECORDING_SCRIPT.relative_to(ROOT)} ({len(lines)} lines)")
    return 0


def check(require_full: bool = False) -> int:
    problems: list[str] = []
    if not MANIFEST.is_file():
        print("voice manifest missing: run --manifest")
        return 1
    try:
        manifest = load_json(MANIFEST)
    except json.JSONDecodeError as exc:
        print(f"voice manifest is invalid JSON: {exc}")
        return 1

    if manifest.get("schema_version") != 1:
        problems.append("schema_version must be 1")
    if manifest.get("locale") != "it":
        problems.append("locale must be 'it'")

    policy = manifest.get("policy", {})
    allowed = tuple(policy.get("allowed_licenses", []))
    if not allowed:
        problems.append("policy.allowed_licenses is empty")
    for licence in allowed:
        if licence not in ALLOWED_LICENSES:
            problems.append(f"policy allows a licence outside the project policy: {licence}")
    if not policy.get("requires_attribution", False):
        problems.append("policy.requires_attribution must be true")

    lines = {line["id"]: line for line in expected_lines()}
    if int(manifest.get("expected_lines", -1)) != len(lines):
        problems.append(
            f"expected_lines is {manifest.get('expected_lines')}, content now needs {len(lines)}; run --manifest"
        )

    declared: dict[str, dict] = {}
    for pack_index, pack in enumerate(manifest.get("packs", [])):
        pack_name = pack.get("name") or f"pack #{pack_index + 1}"
        if not pack.get("clips"):
            problems.append(f"{pack_name}: no clips listed")
        for clip in pack.get("clips", []):
            clip_id = str(clip.get("id", ""))
            if clip_id not in lines:
                problems.append(f"{pack_name}: unknown line id {clip_id!r}")
            if clip_id in declared:
                problems.append(f"line {clip_id} is declared twice")
            declared[clip_id] = clip
            licence = clip.get("license")
            if licence not in allowed:
                problems.append(f"{clip_id}: licence {licence!r} is not allowed")
            for field in ("author", "source", "attribution"):
                if not str(clip.get(field, "")).strip():
                    problems.append(f"{clip_id}: missing {field}")
            if not str(clip.get("source", "")).startswith(("http://", "https://")):
                problems.append(f"{clip_id}: source must be an http(s) URL")
            file_name = str(clip.get("file", ""))
            if not file_name.endswith(".ogg"):
                problems.append(f"{clip_id}: shipped clips must be Ogg Vorbis (.ogg)")
            target = GAME_VOICE_DIR / file_name
            if not target.is_file():
                problems.append(f"{clip_id}: missing file {target.relative_to(ROOT)}")
                continue
            expected_hash = str(clip.get("sha256", ""))
            actual_hash = sha256(target)
            if not expected_hash:
                problems.append(f"{clip_id}: sha256 is required")
            elif expected_hash != actual_hash:
                problems.append(f"{clip_id}: sha256 mismatch (file changed)")

    installed: set[str] = set()
    if GAME_VOICE_DIR.is_dir():
        for path in GAME_VOICE_DIR.iterdir():
            if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS:
                installed.add(path.name)
    for name in sorted(installed):
        if not any(str(clip.get("file", "")) == name for clip in declared.values()):
            problems.append(f"unregistered audio file in the game folder: {name}")
    for clip in declared.values():
        name = str(clip.get("file", ""))
        if name and name not in installed:
            problems.append(f"declared clip is not installed: {name}")

    coverage = len(declared) / max(1, len(lines))
    print(f"voice coverage: {len(declared)}/{len(lines)} lines ({coverage * 100:.1f}%)")
    if require_full and coverage < 1.0:
        problems.append("full voice coverage is required for this release")

    if problems:
        print(f"voice pack check FAILED with {len(problems)} problem(s):")
        for problem in problems:
            print("  -", problem)
        return 1
    print("voice pack check passed.")
    return 0


def install(source: Path, metadata: Path) -> int:
    if not source.is_dir():
        print(f"source folder not found: {source}")
        return 1
    if not metadata.is_file():
        print(f"metadata file not found: {metadata}")
        return 1
    data = load_json(metadata)
    clips = data.get("clips", [])
    if not clips:
        print("metadata contains no clips")
        return 1

    line_ids = {line["id"] for line in expected_lines()}
    problems: list[str] = []
    prepared: list[dict] = []
    for clip in clips:
        clip_id = str(clip.get("id", ""))
        if clip_id not in line_ids:
            problems.append(f"unknown line id: {clip_id}")
            continue
        licence = clip.get("license")
        if licence not in ALLOWED_LICENSES:
            problems.append(f"{clip_id}: licence {licence!r} not allowed")
        for field in ("author", "source", "attribution"):
            if not str(clip.get(field, "")).strip():
                problems.append(f"{clip_id}: missing {field}")
        if not str(clip.get("source", "")).startswith(("http://", "https://")):
            problems.append(f"{clip_id}: source must be an http(s) URL")
        file_name = str(clip.get("file", ""))
        src = source / file_name
        if src.suffix.lower() != ".ogg":
            problems.append(f"{clip_id}: only .ogg clips can be installed")
        if not src.is_file():
            problems.append(f"{clip_id}: file not found: {src}")
        prepared.append({"id": clip_id, "src": src, "meta": clip})

    if problems:
        print("cannot install the pack:")
        for problem in problems:
            print("  -", problem)
        return 1

    GAME_VOICE_DIR.mkdir(parents=True, exist_ok=True)
    installed_clips = []
    for item in prepared:
        clip_id = item["id"]
        src = item["src"]
        target = GAME_VOICE_DIR / f"{clip_id}.ogg"
        shutil.copy2(src, target)
        meta = dict(item["meta"])
        meta["file"] = target.name
        meta["sha256"] = sha256(target)
        meta["bytes"] = target.stat().st_size
        installed_clips.append(meta)
        print(f"installed {clip_id}.ogg")

    write_manifest()
    manifest = load_json(MANIFEST)
    pack = {
        "name": data.get("name", "Italian voice pack"),
        "voice": data.get("voice", ""),
        "author": data.get("author", ""),
        "license": data.get("license", ""),
        "source": data.get("source", ""),
        "attribution": data.get("attribution", ""),
        "clips": sorted(installed_clips, key=lambda c: c["id"]),
    }
    packs = [p for p in manifest.get("packs", []) if p.get("name") != pack["name"]]
    packs.append(pack)
    manifest["packs"] = packs
    manifest["bundled"] = True
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"registered pack '{pack['name']}' in {MANIFEST.relative_to(ROOT)}")
    return check()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", action="store_true", help="rewrite the voice manifest from current content")
    parser.add_argument("--script", action="store_true", help="write the CSV recording script")
    parser.add_argument("--check", action="store_true", help="verify licences, attribution and hashes")
    parser.add_argument("--require-full", action="store_true", help="with --check: every line must have a clip")
    parser.add_argument("--install", type=Path, metavar="DIR", help="install verified .ogg clips from DIR")
    parser.add_argument("--metadata", type=Path, metavar="FILE", help="clip metadata JSON for --install")
    args = parser.parse_args()

    if args.install:
        if not args.metadata:
            parser.error("--install requires --metadata")
        return install(args.install, args.metadata)

    status = 0
    if args.manifest:
        status |= write_manifest()
    if args.script:
        status |= write_script()
    if args.check or not (args.manifest or args.script):
        status |= check(args.require_full)
    return status


if __name__ == "__main__":
    sys.exit(main())
