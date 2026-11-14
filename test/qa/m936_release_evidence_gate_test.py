"""M936: hostile source-gate tests; no private files or actual Android devices."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/qa/m936_release_evidence_gate.py"
spec = importlib.util.spec_from_file_location("m936_gate", SCRIPT)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class M936ReleaseEvidenceGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="m936-source-only-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for rel, markers in gate.SOURCE_CONTRACTS.items():
            file = self.root / rel
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("\n".join(markers), encoding="utf-8")
        self.sha = "a" * 40

    def test_all_source_contracts_pass_but_production_remains_no_go(self):
        result = gate.inspect(self.root, self.sha)
        self.assertTrue(result["source_contract_passed"])
        self.assertEqual(result["source_sha"], self.sha)
        for key in ("physical_android_verified",
                    "owner_backup_financial_parity_verified",
                    "signed_artifact_released",
                    "production_sqlcipher_cutover_permitted",
                    "google_play_publication_permitted"):
            self.assertIs(result[key], False, key)
        self.assertIn("NO_GO", result["release_status"])
        self.assertEqual(len(result["blockers"]), 5)

    def test_missing_source_guard_is_rejected(self):
        target = self.root / "scripts/qa/m190_signed_apk_preflight.py"
        target.unlink()
        result = gate.inspect(self.root, self.sha)
        self.assertFalse(result["source_contract_passed"])
        self.assertIs(result["source_contract_checks"][
            "scripts/qa/m190_signed_apk_preflight.py"], False)

    def test_existing_signed_apk_guard_cannot_be_replaced_with_noop(self):
        target = self.root / "scripts/qa/m190_signed_apk_preflight.py"
        target.write_text("def attest(*a): return True", encoding="utf-8")
        self.assertFalse(gate.inspect(self.root, self.sha)["source_contract_passed"])

    def test_play_source_review_guard_cannot_be_removed(self):
        target = self.root / "scripts/qa/m171_release_candidate_source_audit.py"
        target.write_text("readyForProduction = True", encoding="utf-8")
        self.assertFalse(gate.inspect(self.root, self.sha)["source_contract_passed"])

    def test_hardware_checklist_cannot_disappear_while_source_passes(self):
        target = self.root / "docs/qa/M935_PHASE_TWO_ANDROID_ACCEPTANCE.md"
        target.write_text("CI passed, ship to everyone", encoding="utf-8")
        self.assertFalse(gate.inspect(self.root, self.sha)["source_contract_passed"])

    def test_symlink_is_rejected(self):
        target = self.root / "scripts/qa/m279_app_security_gate.py"
        outside = self.root / "untrusted-marker-file"
        outside.write_text("\n".join(gate.SOURCE_CONTRACTS[
            "scripts/qa/m279_app_security_gate.py"]), encoding="utf-8")
        target.unlink()
        target.symlink_to(outside)
        self.assertFalse(gate.inspect(self.root, self.sha)["source_contract_passed"])

    def test_non_exact_sha_cannot_be_reported_as_candidate(self):
        for bad in ("a" * 39, "A" * 40, "main", "", "a" * 41):
            with self.subTest(bad=bad):
                with self.assertRaises(gate.ReleaseSourceRefused):
                    gate.inspect(self.root, bad)


if __name__ == "__main__":
    unittest.main()
