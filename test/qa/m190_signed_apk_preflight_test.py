"""M190 negative tests use synthetic ZIP and mocked Android SDK tools only."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import stat
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/qa/m190_signed_apk_preflight.py"
spec = importlib.util.spec_from_file_location("m190_signed_apk_preflight", SCRIPT)
assert spec and spec.loader
m190 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m190)

CERT = "a" * 64
APK_SIGN = (
    "Verifies\n"
    "Verified using v1 scheme (JAR signing): true\n"
    "Verified using v2 scheme (APK Signature Scheme v2): true\n"
    "Verified using v3 scheme (APK Signature Scheme v3): false\n"
    "Signer #1 certificate SHA-256 digest: " + CERT + "\n"
)
BADGING = "package: name='com.waffra.app' versionCode='13' versionName='1.0'\n"


class M190SignedApkPreflightTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="m190-synthetic-")
        self.addCleanup(self.temp.cleanup)
        self.apk = Path(self.temp.name) / "review.apk"
        with zipfile.ZipFile(self.apk, "w") as z:
            z.writestr("AndroidManifest.xml", b"synthetic-not-a-real-apk" * 10)
        self.sha = hashlib.sha256(self.apk.read_bytes()).hexdigest()

    def check(self, *, signer=APK_SIGN, badging=BADGING, sha=None, cert=CERT):
        def command(args):
            if args[0] == "apksigner":
                return signer
            if args[0] == "aapt":
                return badging
            raise AssertionError("Unexpected external tool")
        return m190.attest(
            self.apk,
            expected_apk_sha256=sha or self.sha,
            expected_cert_sha256=cert,
            command=command,
        )

    def test_matching_pinned_apk_is_still_release_no_go(self):
        report = self.check()
        self.assertTrue(report["apk_signature_preflight_passed"])
        for key in (
            "physical_android_devices_verified",
            "device_installed_apk_byte_identity_verified",
            "cross_device_encrypted_restore_verified",
            "live_finance_routes_24_of_24_verified",
            "production_sqlcipher_cutover_permitted",
            "google_play_publication_permitted",
        ):
            self.assertFalse(report[key], key)
        self.assertEqual(report["status"], "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO")

    def test_wrong_apk_sha_refuses_even_if_signer_is_correct(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(sha="b" * 64)

    def test_wrong_signer_pin_refuses(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(cert="b" * 64)

    def test_debug_certificate_refuses(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(signer=APK_SIGN + "Signer #1 certificate DN: CN=Android Debug,O=Android\n")

    def test_v1_only_signature_refuses(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(signer=APK_SIGN.replace(
                "Verified using v2 scheme (APK Signature Scheme v2): true",
                "Verified using v2 scheme (APK Signature Scheme v2): false",
            ))

    def test_multiple_signers_refuse(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(signer=APK_SIGN + "Signer #2 certificate SHA-256 digest: " + CERT + "\n")

    def test_unexpected_package_refuses(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(badging=BADGING.replace("com.waffra.app", "com.other.app"))

    def test_symlink_or_invalid_zip_refuses(self):
        other = Path(self.temp.name) / "link.apk"
        other.symlink_to(self.apk)
        self.apk = other
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check()
        self.apk.unlink()
        self.apk.write_bytes(b"not a real zip" * 30)
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(sha=hashlib.sha256(self.apk.read_bytes()).hexdigest())

    def test_invalid_hash_encoding_refuses(self):
        with self.assertRaises(m190.SignedApkPreflightRefused):
            self.check(cert="not a sha")

    def test_missing_android_sdk_tool_fails_closed(self):
        def command(_):
            raise m190.SignedApkPreflightRefused("Android SDK signature/package tool failed.")
        with self.assertRaises(m190.SignedApkPreflightRefused):
            m190.attest(
                self.apk,
                expected_apk_sha256=self.sha,
                expected_cert_sha256=CERT,
                command=command,
            )


    def test_signed_evidence_output_is_exclusive_and_owner_only(self):
        output = Path(self.temp.name) / "signed.json"
        m190._write_private_report(output, {"status": "NO_GO"})
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8")),
                         {"status": "NO_GO"})
        with self.assertRaises(FileExistsError):
            m190._write_private_report(output, {"status": "FORGED_GO"})

    def test_signed_evidence_output_refuses_symlink(self):
        target = Path(self.temp.name) / "existing.json"
        target.write_text("{}", encoding="utf-8")
        alias = Path(self.temp.name) / "link.json"
        alias.symlink_to(target)
        with self.assertRaises(OSError):
            m190._write_private_report(alias, {"status": "NO_GO"})
        self.assertEqual(target.read_text(encoding="utf-8"), "{}")


if __name__ == "__main__":
    unittest.main()
