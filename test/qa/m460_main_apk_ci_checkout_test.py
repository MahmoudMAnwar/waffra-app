"""M460: the APK same-SHA audit must check out the repo before importing QA helpers."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class MainApkCiCheckoutTest(unittest.TestCase):
    def test_same_sha_audit_checks_out_python_source_before_import(self):
        workflow = (ROOT / ".github/workflows/android.yml").read_text(encoding="utf-8")
        self.assertIn("\n  verify-same-sha-checks:\n", workflow)
        audit = workflow.split("\n  verify-same-sha-checks:\n", 1)[1].split("\n  build:\n", 1)[0]
        self.assertIn("uses: actions/checkout@v4", audit)
        self.assertIn("persist-credentials: false", audit)
        self.assertLess(audit.index("uses: actions/checkout@v4"),
                        audit.index("from scripts.qa.m456_optional_retry_audit import"))
        self.assertTrue((ROOT / "scripts/qa/m456_optional_retry_audit.py").is_file())


if __name__ == "__main__":
    unittest.main()
