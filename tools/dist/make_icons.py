#!/usr/bin/env python3
"""Build the Windows icon and the Linux desktop icon from the SVG artwork.

The script is intentionally macOS-only: the release pipeline runs on macOS
because it also produces the signed/notarised macOS bundle.  It renders the
source SVG with Quick Look, resizes with ``sips`` and packs a multi-resolution
``.ico`` (PNG-compressed entries, supported by Windows Vista and later).

Usage:
    python3 tools/dist/make_icons.py \
        --source godot/assets/icons/icon.svg \
        --ico godot/assets/icons/icon.ico \
        --png godot/build/icons/elephantcoding-256.png
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import tempfile
from pathlib import Path

SIZES = (16, 32, 48, 64, 128, 256)


def run(*args: str) -> None:
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def render_svg(source: Path, work: Path) -> Path:
    run("qlmanage", "-t", "-s", "1024", "-o", str(work), str(source))
    rendered = work / (source.name + ".png")
    if not rendered.exists():
        raise SystemExit(f"Quick Look did not render {source}")
    return rendered


def resize(png: Path, size: int, out: Path) -> Path:
    run("sips", "-s", "format", "png", "-z", str(size), str(size), str(png), "--out", str(out))
    return out


def build_ico(images: list[tuple[int, Path]], out: Path) -> None:
    """Pack PNG images into an ICO container.

    Each directory entry uses width/height 0 for 256 px, as required by the
    ICO format; the payload is a complete PNG file.
    """
    payloads = [(size, path.read_bytes()) for size, path in images]
    header = struct.pack("<HHH", 0, 1, len(payloads))
    offset = 6 + 16 * len(payloads)
    entries = []
    for size, data in payloads:
        entries.append(
            struct.pack(
                "<BBBBHHII",
                0 if size >= 256 else size,
                0 if size >= 256 else size,
                0,
                0,
                1,
                32,
                len(data),
                offset,
            )
        )
        offset += len(data)
    out.write_bytes(header + b"".join(entries) + b"".join(data for _, data in payloads))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="source SVG")
    parser.add_argument("--ico", type=Path, help="output .ico")
    parser.add_argument("--png", type=Path, help="optional 256 px PNG for Linux")
    args = parser.parse_args()
    if not args.ico and not args.png:
        parser.error("at least one of --ico or --png is required")

    with tempfile.TemporaryDirectory(prefix="ec-icons-") as tmp:
        work = Path(tmp)
        base = render_svg(args.source, work)
        images: list[tuple[int, Path]] = []
        for size in SIZES:
            target = resize(base, size, work / f"icon-{size}.png")
            images.append((size, target))
            if args.png and size == 256:
                args.png.parent.mkdir(parents=True, exist_ok=True)
                args.png.write_bytes(target.read_bytes())
        if args.ico:
            args.ico.parent.mkdir(parents=True, exist_ok=True)
            build_ico(images, args.ico)
    outputs = [str(path) for path in (args.ico, args.png) if path]
    print("wrote " + ", ".join(outputs))


if __name__ == "__main__":
    main()
