#!/usr/bin/env python3
"""Create a Debian package from a staged filesystem tree.

This avoids depending on dpkg-deb, which is not available on macOS.  The
resulting archive follows the Debian binary package format: an ``ar`` archive
containing ``debian-binary``, ``control.tar.gz`` and ``data.tar.gz``.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import os
import tarfile
import time
from pathlib import Path

AR_MAGIC = b"!<arch>\n"


def _ar_member(name: str, data: bytes, mtime: int) -> bytes:
    header = (
        f"{name:<16}{mtime:<12}{0:<6}{0:<6}{0o100644:<8o}{len(data):<10}`\n".encode("ascii")
    )
    padding = b"\n" if len(data) % 2 else b""
    return header + data + padding


def _tar_gz(root: Path, entries: list[tuple[str, Path, int]], mtime: int) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for arcname, source, mode in sorted(entries, key=lambda item: item[0]):
            info = tarfile.TarInfo(arcname)
            info.mtime = mtime
            info.uid = 0
            info.gid = 0
            info.uname = "root"
            info.gname = "root"
            info.mode = mode
            if source.is_dir():
                info.type = tarfile.DIRTYPE
                tar.addfile(info)
            else:
                info.type = tarfile.REGTYPE
                info.size = source.stat().st_size
                with source.open("rb") as handle:
                    tar.addfile(info, handle)
    return gzip.compress(buffer.getvalue(), mtime=mtime, compresslevel=9)


def build(root: Path, out: Path, version: str, arch: str, epoch: int) -> None:
    entries: list[tuple[str, Path, int]] = []
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root).as_posix()
        mode = 0o755 if path.is_dir() or os.access(path, os.X_OK) else 0o644
        entries.append((f"./{rel}", path, mode))

    data_tar = _tar_gz(root, entries, epoch)

    installed_kb = sum(
        path.stat().st_size for path in root.rglob("*") if path.is_file()
    ) // 1024
    control = (
        "Package: elephantcoding\n"
        f"Version: {version}\n"
        "Section: games\n"
        "Priority: optional\n"
        f"Architecture: {arch}\n"
        "Maintainer: ElephantCoding contributors <elephantcoding@example.org>\n"
        f"Installed-Size: {installed_kb}\n"
        "Depends: libc6, libstdc++6, libx11-6, libxcursor1, libxinerama1, libxi6, "
        "libxrandr2, libgl1, libasound2\n"
        "Description: Nilo l'elefantino che programma\n"
        " Gioco educativo 3D per imparare il pensiero computazionale, la logica\n"
        " e la matematica dalla scuola dell'infanzia alla secondaria.\n"
        " Include 90 missioni in 9 mondi, tre viste 3D, editor a blocchi e\n"
        " testuale, area insegnante e sottotitoli.\n"
    ).encode("utf-8")

    md5_lines = []
    for path in sorted(root.rglob("*")):
        if path.is_file():
            rel = path.relative_to(root).as_posix()
            md5_lines.append(f"{hashlib.md5(path.read_bytes()).hexdigest()}  {rel}\n")
    md5sums = "".join(md5_lines).encode("utf-8")

    control_buffer = io.BytesIO()
    with tarfile.open(fileobj=control_buffer, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for arcname, data in (("./control", control), ("./md5sums", md5sums)):
            info = tarfile.TarInfo(arcname)
            info.mtime = epoch
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            info.mode = 0o644
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    control_tar = gzip.compress(control_buffer.getvalue(), mtime=epoch, compresslevel=9)

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("wb") as handle:
        handle.write(AR_MAGIC)
        # Member names must not carry the trailing slash GNU ar uses for its
        # own archives: dpkg looks up "control.tar.gz" literally and rejects
        # the package otherwise.
        handle.write(_ar_member("debian-binary", b"2.0\n", epoch))
        handle.write(_ar_member("control.tar.gz", control_tar, epoch))
        handle.write(_ar_member("data.tar.gz", data_tar, epoch))
    print(f"wrote {out}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path, help="staged filesystem root")
    parser.add_argument("--out", required=True, type=Path, help="output .deb")
    parser.add_argument("--version", required=True)
    parser.add_argument("--arch", default="amd64")
    parser.add_argument(
        "--source-date-epoch",
        type=int,
        default=int(os.environ.get("SOURCE_DATE_EPOCH", str(int(time.time())))),
    )
    args = parser.parse_args()
    build(args.root, args.out, args.version, args.arch, args.source_date_epoch)


if __name__ == "__main__":
    main()
