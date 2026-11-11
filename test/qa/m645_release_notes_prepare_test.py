"""M645: approved notes must follow app code, with actual source SHA."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREPARE = ROOT / "scripts/qa/m449_prepare_release_notes.py"
M449 = ROOT / "scripts/qa/m449_release_notes_ancestry.py"
NOTES = "docs/release/WAFFRA_APPROVED_CHANGES.txt"
REVIEW = [
    "--issue", "566", "--pr", "568",
    "--summary", "Verified savings account selection is displayed and committed once.",
]


class ReleaseNotesPreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "qa@example.invalid")
        self.git("config", "user.name", "Waffra QA")
        self.write("lib/main.dart", "void main() {}\n")
        self.write(NOTES, "Current verified Saudi finance features.\n")
        self.write("scripts/qa/m449_release_notes_ancestry.py",
                   M449.read_text(encoding="utf-8"))
        self.git("add", "-A")
        self.git("commit", "-qm", "baseline app and reviewed notes")

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.root, text=True,
            capture_output=True, check=True).stdout.strip()

    def write(self, path, data):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(data, encoding="utf-8")

    def prep(self, *args):
        return subprocess.run(
            [sys.executable, str(PREPARE), *args],
            cwd=self.root, text=True, capture_output=True)

    def change_app(self):
        self.write("lib/main.dart", "void main() { print('new'); }\n")
        self.git("add", "--", "lib/main.dart")
        self.git("commit", "-qm", "verified app change")
        return self.git("rev-parse", "HEAD")

    def test_preview_does_not_mutate_or_silence_stale_m449(self):
        sha = self.change_app()
        notes_before = (self.root / NOTES).read_text()
        result = self.prep(*REVIEW)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("M645 PREVIEW ONLY", result.stdout)
        self.assertIn(sha, result.stdout)
        self.assertEqual((self.root / NOTES).read_text(), notes_before)
        self.assertNotEqual(self.prep("--verify-only").returncode, 0)

    def test_committed_notes_reference_source_sha_and_pass_m449(self):
        sha = self.change_app()
        result = self.prep(*REVIEW, "--commit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("M645 COMMITTED", result.stdout)
        notes = (self.root / NOTES).read_text(encoding="utf-8")
        self.assertIn(sha, notes)
        self.assertIn("ISSUE #566", notes)
        self.assertIn("PR #568", notes)
        self.assertEqual(self.prep("--verify-only").returncode, 0)
        self.assertEqual(self.git("show", "--pretty=", "--name-only", "HEAD"), NOTES)

    def test_dirty_application_source_is_rejected(self):
        self.write("lib/main.dart", "void main() { print('dirty'); }\n")
        result = self.prep(*REVIEW, "--commit")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Commit all app changes first", result.stderr)

    def test_blank_fake_or_unidentified_reviews_rejected(self):
        self.change_app()
        for args in (
            ["--issue", "566", "--summary", "Reviewed savings change"],
            ["--issue", "566", "--pr", "568", "--summary", "TODO placeholder review"],
            ["--issue", "-1", "--pr", "568", "--summary", "Reviewed savings change"],
            ["--issue", "566", "--pr", "568", "--summary", "tiny"],
        ):
            with self.subTest(args=args):
                self.assertNotEqual(self.prep(*args, "--commit").returncode, 0)
        self.assertEqual(self.prep("--verify-only").returncode, 0)

    def test_test_only_changes_make_no_extra_notes_commit(self):
        self.write("test/example_test.dart", "void main() {}\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "test-only change")
        sha = self.git("rev-parse", "HEAD")
        result = self.prep(*REVIEW, "--commit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("M645 UP TO DATE", result.stdout)
        self.assertEqual(self.git("rev-parse", "HEAD"), sha)

    def test_missing_notes_are_never_auto_recreated_without_review(self):
        (self.root / NOTES).unlink()
        result = self.prep(*REVIEW, "--commit")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing current release notes", result.stderr)


if __name__ == "__main__":
    unittest.main()
