"""Prevent floating SQLCipher binary release/hook overrides in Waffra builds.

sqlite3 3.7.0 is an immutable official release, published 2026-09-30.
The package's native hook still verifies each binary against its built-in
SHA-256; this test never accepts a substituted checksum or disables crypto.
Official GitHub release 3.7.0 x64 Linux sqlite3mc SHA-256:
3dfe8bcd00e34c705de14acd1c1a0d283b9fd7d20fbd49b0aa0196b85a1d7741
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SqliteAssetPinTest(unittest.TestCase):
    def test_sqlite3mc_version_does_not_float_across_ci_runs(self):
        pub = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        self.assertIn("  sqlite3: 3.7.0", pub)
        self.assertNotIn("  sqlite3: ^", pub)
        self.assertIn("    sqlite3:\n      source: sqlite3mc", pub)
        self.assertNotIn("url_pattern:", pub)
        self.assertNotIn("source: system", pub)

    def test_release_build_retains_signed_source_and_sqlcipher_security_gates(self):
        native = (ROOT / ".github/workflows/android.yml").read_text(encoding="utf-8")
        self.assertIn("verify-same-sha-checks:", native)
        self.assertIn("Run every Flutter regression including future test files", native)
        self.assertIn("Verify final APK uses Firebase-registered Waffra release signing", native)


if __name__ == "__main__":
    unittest.main()
