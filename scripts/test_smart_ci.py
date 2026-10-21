"""Self-tests for Waffra Smart CI: failing closed is mandatory."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import smart_ci


class SmartCiTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        for directory in ("lib", "test", "assets"):
            (self.root / directory).mkdir()
        (self.root / "lib/waffra_amount_formatter.dart").write_text(
            "const amount=1;", encoding="utf-8")
        (self.root / "lib/unrelated.dart").write_text(
            "const unrelated=1;", encoding="utf-8")
        (self.root / "test/waffra_amount_formatter_test.dart").write_text(
            "import 'package:waffra/waffra_amount_formatter.dart';\n"
            "void main() {}\n", encoding="utf-8")
        (self.root / "test/ordinary_view_test.dart").write_text(
            "import 'package:waffra/unrelated.dart';\nvoid main() {}\n",
            encoding="utf-8")

    def plan(self, previous=None):
        return smart_ci.determine_plan(
            self.root, previous or {}, "flutter-SDK-test")

    def test_financial_tests_execute_even_if_identical(self):
        hashes, executed, _ = self.plan()
        _, repeat, reused = self.plan({"fingerprints": hashes})
        self.assertIn("test/waffra_amount_formatter_test.dart", repeat)
        self.assertIn("test/ordinary_view_test.dart", reused)

    def test_unrelated_module_does_not_invalidate_independent_suite(self):
        hashes, _, _ = self.plan()
        (self.root / "lib/waffra_amount_formatter.dart").write_text(
            "const amount=2;", encoding="utf-8")
        _, executed, reused = self.plan({"fingerprints": hashes})
        self.assertIn("test/waffra_amount_formatter_test.dart", executed)
        self.assertIn("test/ordinary_view_test.dart", reused)

    def test_imported_source_change_invalidates(self):
        hashes, _, _ = self.plan()
        (self.root / "lib/unrelated.dart").write_text(
            "const unrelated=2;", encoding="utf-8")
        _, executed, _ = self.plan({"fingerprints": hashes})
        self.assertIn("test/ordinary_view_test.dart", executed)

    def test_assets_change_invalidates_all(self):
        hashes, _, _ = self.plan()
        (self.root / "assets/new_icon.png").write_bytes(b"new bytes")
        _, executed, reused = self.plan({"fingerprints": hashes})
        self.assertEqual(len(executed), 2)
        self.assertEqual(len(reused), 0)

    def test_full_validation_invalidates_all(self):
        hashes, _, _ = self.plan()
        _, executed, reused = smart_ci.determine_plan(
            self.root, {"fingerprints": hashes},
            "flutter-SDK-test", full=True)
        self.assertEqual(len(executed), 2)
        self.assertEqual(reused, [])

    def test_change_in_flutter_version_invalidates_all(self):
        hashes, _, _ = self.plan()
        _, executed, _ = smart_ci.determine_plan(
            self.root, {"fingerprints": hashes},
            "flutter-new-version")
        self.assertEqual(len(executed), 2)

    def test_unknown_local_import_fails_closed(self):
        hashes, _, _ = self.plan()
        (self.root / "test/ordinary_view_test.dart").write_text(
            "import 'package:waffra/missing_module.dart';\n",
            encoding="utf-8")
        _, executed, _ = self.plan({"fingerprints": hashes})
        self.assertIn("test/ordinary_view_test.dart", executed)

    def test_main_import_tracks_all_library_code(self):
        (self.root / "lib/main.dart").write_text(
            "const main=1;", encoding="utf-8")
        (self.root / "test/ordinary_view_test.dart").write_text(
            "import 'package:waffra/main.dart';\n",
            encoding="utf-8")
        hashes, _, _ = self.plan()
        (self.root / "lib/unrelated.dart").write_text(
            "const unrelated=3;", encoding="utf-8")
        _, executed, _ = self.plan({"fingerprints": hashes})
        self.assertIn("test/ordinary_view_test.dart", executed)

    def test_missing_or_tampered_manifest_is_not_trusted(self):
        manifest = self.root / "cache.json"
        self.assertEqual(smart_ci.verified_baseline(manifest), {})
        manifest.write_text(json.dumps({
            "schema": smart_ci.SCHEMA, "branch": "main",
            "all_tests_passed": False, "fingerprints": {"x": "y"}
        }), encoding="utf-8")
        self.assertEqual(smart_ci.verified_baseline(manifest), {})
        manifest.write_text("{broken", encoding="utf-8")
        self.assertEqual(smart_ci.verified_baseline(manifest), {})


if __name__ == "__main__":
    unittest.main()
