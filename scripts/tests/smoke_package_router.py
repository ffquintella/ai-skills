#!/usr/bin/env python3
"""Exercise a native distribution outside the source tree, without account access."""

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path


def smoke(archive: Path, windows: bool) -> None:
    checksum = archive.with_suffix(".zip.sha256").read_text().split()[0]
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == checksum, "archive checksum mismatch"
    executable = "agent-router.exe" if windows else "agent-router"
    expected = {f"agent-router/{name}" for name in
                (executable, "models.yaml", "README.md", "SCHEMA.md")}
    with tempfile.TemporaryDirectory(prefix="router isolated smoke ") as directory:
        root = Path(directory)
        with zipfile.ZipFile(archive) as bundle:
            assert set(bundle.namelist()) == expected, "unexpected distribution files"
            bundle.extractall(root)
        binary = root / "agent-router" / executable
        if not windows:
            binary.chmod(0o755)

        def run(*args: str, code: int = 0) -> dict:
            result = subprocess.run([os.fspath(binary), "--provider", "openai", "--task", "lookup", *args],
                                    cwd=root, capture_output=True, text=True, timeout=15, check=False)
            assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
            assert len(result.stdout.splitlines()) == 1, "decision must be compact JSON"
            return json.loads(result.stdout)

        for remaining, mode in (("80", "normal"), ("25", "economy"), ("10", "extreme")):
            decision = run("--daily-remaining", remaining)
            assert decision["model"] == "gpt-6-luna"
            assert decision["mode"] == mode
        security = run("--security-sensitive", "--weekly-remaining", "5")
        assert security["model"] == "gpt-6.1-sol" and security["effort"] == "xhigh"
        blocked = run("--weekly-remaining", "0", code=3)
        assert blocked["model"] is None and blocked["mode"] == "blocked"
        policy = binary.parent / "models.yaml"
        policy.write_text(policy.read_text().replace("gpt-6-luna", "new-model-without-recompile"),
                          encoding="utf-8")
        assert run()["model"] == "new-model-without-recompile"
    print(f"Packaged binary smoke passed: {archive.name} (6 scenarios, adjacent YAML)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True)
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[2]
    version = (repository / "VERSION").read_text().strip()
    archive = repository / "dist" / f"agent-router-{version}-{args.target}.zip"
    smoke(archive, "windows" in args.target)


if __name__ == "__main__":
    main()
