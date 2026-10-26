"""M254 negative tests use wholly fabricated report dictionaries; no phone proof."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/m254_physical_release_evidence_review.py"
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("m254_check", SCRIPT)
assert spec and spec.loader
m254 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m254)
from m189_physical_device_source_probe import REQUIRED_ROUTES


def physical():
    return {
        "milestone": "M189",
        "status": "PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO",
        "hardware_detected": 2,
        "devices": [
            {"device_token": "1" * 64, "build_fingerprint_token": "3" * 64,
             "sdk": 35, "package_present": True,
             "qemu_getprop": "0_or_unset", "device_read_only": True},
            {"device_token": "2" * 64, "build_fingerprint_token": "4" * 64,
             "sdk": 35, "package_present": True,
             "qemu_getprop": "0_or_unset", "device_read_only": True},
        ],
        "route_inventory": list(REQUIRED_ROUTES),
        "route_execution_witnesses": [],
        "os_backed_key_recovery_attested": False,
        "backup_restore_across_two_real_devices_attested": False,
        "encrypted_receipt_byte_parity_attested": False,
        "signed_release_apk_attested": False,
        "source_cutover_attested": False,
        "privacy_and_account_deletion_attested": False,
        "human_release_approval": False,
        "store_publication_permitted": False,
    }


def signed():
    return {
        "milestone": "M190",
        "status": "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO",
        "apk_signature_preflight_passed": True,
        "package": "com.waffra.app",
        "apk_sha256": "a" * 64,
        "certificate_sha256": "b" * 64,
        "version_code": 705,
        "physical_android_devices_verified": False,
        "device_installed_apk_byte_identity_verified": False,
        "cross_device_encrypted_restore_verified": False,
        "live_finance_routes_24_of_24_verified": False,
        "production_sqlcipher_cutover_permitted": False,
        "google_play_publication_permitted": False,
    }


def review(p=None, a=None, sha="1a957d06ce51a9e20b04bfa4856db87e22fafb4f"):
    return m254.inspect(
        physical() if p is None else p,
        signed() if a is None else a,
        source_sha=sha,
        expected_routes=REQUIRED_ROUTES,
    )


class M254IndependentPhysicalEvidenceTest(unittest.TestCase):
    def test_even_matching_synthetic_reports_are_not_release_approval(self):
        report = review()
        self.assertTrue(report["report_consistency_passed"])
        self.assertEqual(report["physical_device_presence_records"], 2)
        self.assertFalse(report["source_cutover_authorized"])
        self.assertFalse(report["release_apk_authorized"])
        self.assertFalse(report["physical_runtime_route_attestation"])
        self.assertFalse(report["google_play_publication_permitted"])
        self.assertEqual(report["status"],
                         "REPORTS_CONSISTENT_BUT_PRODUCTION_RELEASE_NO_GO")
        self.assertGreaterEqual(len(report["blockers"]), 12)

    def test_wrong_reviewed_sha_is_blocked(self):
        for sha in ("main", "a" * 39, "A" * 40, "c" * 64):
            with self.subTest(sha=sha), self.assertRaises(m254.EvidenceRefused):
                review(sha=sha)

    def test_duplicate_hardware_cannot_pass(self):
        p = physical()
        p["devices"][1]["device_token"] = p["devices"][0]["device_token"]
        with self.assertRaises(m254.EvidenceRefused):
            review(p=p)

    def test_emulator_or_unsupported_device_cannot_pass(self):
        for key, value in (("qemu_getprop", "1"), ("sdk", 26),
                           ("package_present", False), ("device_read_only", False)):
            p = physical()
            p["devices"][0][key] = value
            with self.subTest(key=key), self.assertRaises(m254.EvidenceRefused):
                review(p=p)

    def test_hardware_count_and_route_inventory_are_exact(self):
        for key, value in (("hardware_detected", 1), ("route_inventory", []),
                           ("route_execution_witnesses", ["fake-witness"])):
            p = physical()
            p[key] = value
            with self.subTest(key=key), self.assertRaises(m254.EvidenceRefused):
                review(p=p)

    def test_collector_must_not_claim_recovery(self):
        for key in ("signed_release_apk_attested", "os_backed_key_recovery_attested",
                    "backup_restore_across_two_real_devices_attested",
                    "store_publication_permitted"):
            p = physical()
            p[key] = True
            with self.subTest(key=key), self.assertRaises(m254.EvidenceRefused):
                review(p=p)

    def test_signer_package_or_certificate_mismatch_is_refused(self):
        for key, value in (("package", "com.evil.app"),
                           ("certificate_sha256", ""),
                           ("apk_sha256", "not-sha"),
                           ("apk_signature_preflight_passed", False),
                           ("version_code", 0)):
            a = signed()
            a[key] = value
            with self.subTest(key=key), self.assertRaises(m254.EvidenceRefused):
                review(a=a)

    def test_premature_signer_report_go_is_refused(self):
        for key in ("production_sqlcipher_cutover_permitted",
                    "cross_device_encrypted_restore_verified",
                    "device_installed_apk_byte_identity_verified"):
            a = signed()
            a[key] = True
            with self.subTest(key=key), self.assertRaises(m254.EvidenceRefused):
                review(a=a)

    def test_security_evidence_duplicate_json_keys_refused(self):
        with self.assertRaises(m254.EvidenceRefused):
            m254._unique_items([("signed", False), ("signed", True)])

    def test_symlink_private_report_refused(self):
        with tempfile.TemporaryDirectory() as d:
            data = Path(d) / "report.json"
            data.write_text("{}", encoding="utf-8")
            alias = Path(d) / "alias"
            alias.symlink_to(data)
            with self.assertRaises(m254.EvidenceRefused):
                m254._load_private_report(alias)

    def test_missing_fields_and_forged_report_types_refused(self):
        with self.assertRaises(m254.EvidenceRefused):
            review(p=[])
        with self.assertRaises(m254.EvidenceRefused):
            review(a=[])
        p = physical()
        del p["devices"][1]["build_fingerprint_token"]
        with self.assertRaises(m254.EvidenceRefused):
            review(p=p)


if __name__ == "__main__":
    unittest.main()
