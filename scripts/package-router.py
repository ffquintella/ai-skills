#!/usr/bin/env python3
"""Bundle a built binary and its editable policy; no compiler or network used."""

import argparse
import hashlib
import re
import zipfile
from pathlib import Path

TARGETS = (
    "x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu",
    "x86_64-apple-darwin", "aarch64-apple-darwin",
)


def package(binary: Path, source: Path, output: Path, target: str, version: str) -> Path:
    """Validate inputs first, then produce a zip and a standard SHA256 receipt."""
    if target not in TARGETS:
        raise ValueError(f"unsupported target: {target}")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("version must be major.minor.patch")
    executable = "agent-router.exe" if "windows" in target else "agent-router"
    files = [(binary, executable)] + [(source / name, name) for name in
                                     ("models.yaml", "README.md", "SCHEMA.md")]
    for path, _ in files:
        if not path.is_file():
            raise ValueError(f"required distribution file missing: {path}")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"agent-router-{version}-{target}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as contents:
        for path, name in files:
            contents.write(path, f"agent-router/{name}")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(
        f"{checksum}  {archive.name}\n", encoding="utf-8", newline="\n"
    )
    return archive


def main() -> None:
    repository = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, choices=TARGETS)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--source", type=Path, default=repository / "tools" / "agent-router")
    parser.add_argument("--output", type=Path, default=repository / "dist")
    parser.add_argument("--version", default=(repository / "VERSION").read_text().strip())
    args = parser.parse_args()
    try:
        archive = package(args.binary, args.source, args.output, args.target, args.version)
    except (OSError, ValueError) as error:
        parser.exit(2, f"packaging failed: {error}\n")
    print(archive)


if __name__ == "__main__":
    main()
