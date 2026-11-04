"""M449 regression: old notes must block PRs, not signed APKs after build."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/qa/m449_release_notes_ancestry.py"


class ReleaseNotesAncestryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "qa@example.invalid")
        self.git("config", "user.name", "Waffra QA")
        self.write("lib/main.dart", "void main() {}\n")
        self.write("docs/release/WAFFRA_APPROVED_CHANGES.txt", "approved original app\n")
        self.commit("original app with approved notes")

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.root, text=True, capture_output=True,
            check=True,
        ).stdout.strip()

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def commit(self, description):
        self.git("add", "-A")
        self.git("commit", "-qm", description)

    def check(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT)], cwd=self.root,
            text=True, capture_output=True,
        )

    def test_old_notes_block_new_app_code_before_main_build(self):
        self.write("lib/main.dart", "void main() { print('new'); }\n")
        self.commit("app changed without a changelog")
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("BLOCKED M449", result.stderr)
        self.assertIn("older than app-code", result.stderr)

    def test_new_notes_after_app_code_pass(self):
        self.write("lib/main.dart", "void main() { print('new'); }\n")
        self.commit("app changed")
        self.write("docs/release/WAFFRA_APPROVED_CHANGES.txt", "approved original app\napproved new app\n")
        self.commit("reviewed release notes updated after app")
        self.assertEqual(self.check().returncode, 0)

    def test_test_only_change_does_not_force_new_notes(self):
        self.write("test/qa/sample_test.py", "assert True\n")
        self.commit("test only")
        self.assertEqual(self.check().returncode, 0)

    def test_android_and_pubspec_changes_require_notes(self):
        for path in ("android/app/src/main/AndroidManifest.xml", "pubspec.yaml", "lib/pages/home.dart"):
            with self.subTest(path=path):
                self.write(path, "changed\n")
                self.commit("source changed: " + path)
                self.assertEqual(self.check().returncode, 1)
                self.write("docs/release/WAFFRA_APPROVED_CHANGES.txt",
                           (self.root / "docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text()
                           + "approved " + path + "\n")
                self.commit("approved source change: " + path)
                self.assertEqual(self.check().returncode, 0)

    def test_deleted_notes_are_rejected(self):
        (self.root / "docs/release/WAFFRA_APPROVED_CHANGES.txt").unlink()
        self.commit("remove release notes")
        self.assertEqual(self.check().returncode, 1)


if __name__ == "__main__":
    unittest.main()
