"""Portable distribution contract, using fixture files rather than a compiler."""

import hashlib
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "package-router.py"
SPEC = importlib.util.spec_from_file_location("package_router", SCRIPT)
package_router = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package_router)


class PackageTests(unittest.TestCase):
    def test_archive_contains_executable_policy_and_instructions_with_checksum(self):
        with tempfile.TemporaryDirectory(prefix="router package ") as temp:
            root = Path(temp)
            for name in ("agent-router.exe", "models.yaml", "README.md", "SCHEMA.md"):
                (root / name).write_text(name, encoding="utf-8")
            archive = package_router.package(
                root / "agent-router.exe", root, root / "output", "x86_64-pc-windows-msvc", "0.3.0"
            )
            self.assertIsInstance(archive, Path, "packaging must create an archive")
            self.assertTrue(archive.is_file())
            with zipfile.ZipFile(archive) as contents:
                self.assertEqual(
                    contents.namelist(),
                    ["agent-router/agent-router.exe", "agent-router/models.yaml",
                     "agent-router/README.md", "agent-router/SCHEMA.md"],
                )
                self.assertEqual(contents.read("agent-router/models.yaml"), b"models.yaml")
            expected = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual(archive.with_suffix(".zip.sha256").read_text(), f"{expected}  {archive.name}\n")

    def test_missing_policy_fails_before_creating_distribution(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "agent-router.exe").write_bytes(b"fixture")
            with self.assertRaisesRegex(ValueError, "models.yaml"):
                package_router.package(root / "agent-router.exe", root, root / "output",
                                       "x86_64-pc-windows-msvc", "0.3.0")
            self.assertFalse((root / "output").exists())

    def test_unknown_target_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaisesRegex(ValueError, "target"):
                package_router.package(root / "agent-router", root, root / "output", "../bad", "0.3.0")


if __name__ == "__main__":
    unittest.main()
