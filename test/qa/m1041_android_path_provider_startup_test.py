"""M1041 P0 Android startup regression: source-only plus required real emulator CI.

This does not claim that source inspection proves a physical phone now opens.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class AndroidEncryptedStartupTest(unittest.TestCase):
    def test_path_provider_android_pre_jni_version_is_exact(self):
        deps = read("pubspec.yaml")
        self.assertRegex(deps, r"(?m)^  path_provider: \^2\.1\.5\s*$")
        self.assertRegex(deps, r"(?m)^  path_provider_android: 2\.2\.23\s*$")
        self.assertNotIn("dependency_overrides:", deps)
        self.assertEqual(
            len(re.findall(r"(?m)^  path_provider_android:", deps)), 1
        )

    def test_compiled_preview_rejects_missing_finance_elf_and_version_drift(self):
        build = read(".github/workflows/m147-final-main-review-gate.yml")
        self.assertIn("Refuse APK missing native runtime libraries", build)
        self.assertIn("pubspec.lock", build)
        self.assertIn("jni_flutter", build)
        self.assertIn("path_provider_android", build)
        self.assertIn(r'2\.2\.23', build)
        for library in ("libapp.so", "libflutter.so", "libsqlite3mc.so"):
            self.assertIn(library, build)
        self.assertIn("libdartjni.so", build)
        self.assertIn("if jni_required:", build)
        self.assertLess(
            build.index("Refuse APK missing native runtime libraries"),
            build.index("Attach unapproved-for-production APK for device QA"),
        )
        qa = read("scripts/qa/m268_scope_review.py")
        self.assertIn("path_provider_android: 2.2.23", qa)
        self.assertIn("Refuse APK missing native runtime libraries", qa)

    def test_real_install_source_and_fail_closed_paths_unchanged(self):
        startup = read("lib/storage/waffra_fresh_install_source.dart")
        app = read("lib/main.dart")
        self.assertIn("getApplicationSupportDirectory()", startup)
        self.assertIn("WaffraFreshInstallSource.prepare()", app)
        self.assertIn("runApp(MaterialApp(home:Scaffold", app)
        self.assertIn("Incomplete encrypted installation.", startup)
        self.assertIn("Unexpected fresh-install cipher key format.", startup)
        self.assertNotIn("delete(recursive:true)", startup)
        self.assertTrue((ROOT / "integration_test/encrypted_storage_android_test.dart").is_file())
        self.assertTrue((ROOT / "integration_test/fresh_install_production_binding_android_test.dart").is_file())


if __name__ == "__main__":
    unittest.main()
