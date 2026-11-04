"""M267: disposable fixtures prove exact APK identity checks fail closed."""
from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "qa"))
import m267_signed_two_phone_apk_probe as m  # noqa: E402

SHA = "a" * 40
CERT = "b" * 64


class M267TwoPhoneIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="m267-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "app-release.apk"
        self.receipt = self.root / "receipt.txt"
        self.write_apk()
        self.write_receipt()

    def write_apk(self, *, sha=SHA, branch="main", build_type="qa-android-arm64"):
        with zipfile.ZipFile(self.apk, "w") as z:
            z.writestr(m.IDENTITY_ASSET, json.dumps({
                "commit_sha": sha, "branch": branch, "workflow_run": "12345678",
                "build_type": build_type,
            }))
            z.writestr("assets/dummy.txt", "synthetic bytes only")

    def write_receipt(self, *, hash_override=None, sha=SHA):
        self.receipt.write_text(
            "Source commit: " + sha + "\n" +
            "Source branch: main\n" +
            "GitHub Actions run: 12345678\n" +
            "APK sha256: " + (hash_override or hashlib.sha256(
                self.apk.read_bytes()).hexdigest()) + "\n",
            encoding="utf-8",
        )

    def tool(self, argv):
        if argv[0] == "apksigner":
            return ("Verifies\n"
                    "Verified using v2 scheme (APK Signature Scheme v2): true\n"
                    "Signer #1 certificate SHA-256 digest: " + CERT + "\n")
        if argv[0] == "aapt":
            return "package: name='com.waffra.app' versionCode='700'\n"
        raise AssertionError("Unknown tool " + str(argv))

    def adb(self, argv, *, mode="valid"):
        if argv == ["devices", "-l"]:
            if mode == "one":
                return "List of devices attached\nANDROID_A device usb:1\n"
            return ("List of devices attached\nANDROID_A device usb:1\n"
                    "ANDROID_B device usb:2\n")
        serial = argv[1]
        if serial not in {"ANDROID_A", "ANDROID_B"}:
            raise AssertionError("Unexpected serial")
        if argv[2:4] == ["shell", "getprop"]:
            prop = argv[4]
            return {
                "ro.kernel.qemu": "1" if mode == "emulator" else "0",
                "ro.hardware": "kalama",
                "ro.build.version.sdk": "35",
                "ro.build.fingerprint": "example/test/phone:16/UP1A/user/release-keys-" + serial,
            }[prop]
        if argv[2:5] == ["shell", "pm", "path"]:
            if mode == "split":
                return ("package:/data/app/waffra/base.apk\n"
                        "package:/data/app/waffra/split_config.apk\n")
            return "package:/data/app/waffra/base.apk"
        raise AssertionError("Disallowed ADB action " + repr(argv))

    def copy(self, serial, remote_path, dest):
        self.assertIn(serial, {"ANDROID_A", "ANDROID_B"})
        self.assertEqual(remote_path, "/data/app/waffra/base.apk")
        dest.write_bytes(self.apk.read_bytes())

    def verify(self, *, adb=None, copier=None, tool=None):
        return m.capture(
            self.apk, self.receipt, SHA, CERT,
            command=adb or self.adb,
            copier=copier or self.copy,
            tool=tool or self.tool,
        )

    def test_both_installed_apks_match_exact_signed_main_without_certifying_finance(self):
        outcome = self.verify()
        self.assertTrue(outcome["physical_apk_identity_matched"])
        self.assertEqual(outcome["main_sha"], SHA)
        self.assertEqual(outcome["apk_sha256"], hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(len(outcome["devices"]), 2)
        self.assertFalse(outcome["production_release_allowed"])
        self.assertFalse(outcome["production_sqlcipher_activated"])
        self.assertFalse(outcome["two_phone_sqlcipher_restore_attested"])
        self.assertFalse(outcome["source_backed_24_routes_attested"])
        self.assertEqual(outcome["live_finance_route_witnesses"], [])
        serialized = json.dumps(outcome)
        self.assertNotIn("ANDROID_A", serialized)
        self.assertNotIn("ANDROID_B", serialized)
        self.assertNotIn("/data/app/", serialized)
        self.assertNotIn("bank", serialized.lower())

    def test_wrong_source_branch_and_stale_main_are_refused(self):
        self.write_apk(sha="f" * 40)
        self.write_receipt()
        with self.assertRaises(m.IdentityRefused):
            self.verify()
        self.write_apk(branch="old-feature")
        self.write_receipt()
        with self.assertRaises(m.IdentityRefused):
            self.verify()

    def test_stale_receipt_and_tampered_apk_bytes_are_refused(self):
        self.write_receipt(hash_override="c" * 64)
        with self.assertRaises(m.IdentityRefused):
            self.verify()
        self.write_receipt()
        with self.apk.open("ab") as stream:
            stream.write(b"tamper")
        with self.assertRaises(m.IdentityRefused):
            self.verify()

    def test_wrong_signer_or_incomplete_signature_fails_closed(self):
        with self.assertRaises(m.IdentityRefused):
            m.verify_local_apk(self.apk, self.receipt, SHA, "c" * 64,
                               tool=self.tool)
        def unsigned(argv):
            if argv[0] == "apksigner":
                return "Signer #1 certificate SHA-256 digest: " + CERT + "\n"
            return self.tool(argv)
        with self.assertRaises(m.IdentityRefused):
            self.verify(tool=unsigned)

    def test_manifest_package_spoof_is_rejected(self):
        def wrong_package(argv):
            if argv[0] == "aapt":
                return "package: name='com.example.fake'"
            return self.tool(argv)
        with self.assertRaises(m.IdentityRefused):
            self.verify(tool=wrong_package)

    def test_emulator_and_one_physical_device_cannot_fake_two(self):
        for mode in ("one", "emulator"):
            with self.subTest(mode=mode):
                with self.assertRaises(m.hardware.HardwareEvidenceRefused):
                    self.verify(adb=lambda args: self.adb(args, mode=mode))

    def test_installed_split_package_or_mismatched_apk_is_refused(self):
        with self.assertRaises(m.IdentityRefused):
            self.verify(adb=lambda args: self.adb(args, mode="split"))
        def changed(serial, remote_path, dest):
            dest.write_bytes(b"different APK!")
        with self.assertRaises(m.IdentityRefused):
            self.verify(copier=changed)

    def test_not_reading_phone_finances_or_raw_device_identifiers(self):
        calls = []
        def track(argv):
            calls.append(argv)
            return self.adb(argv)
        self.verify(adb=track)
        self.assertTrue(all(
            a == ["devices", "-l"] or
            a[2:4] == ["shell", "getprop"] or
            a[2:5] == ["shell", "pm", "path"]
            for a in calls
        ))
        self.assertFalse(any(
            forbidden in " ".join(a)
            for a in calls
            for forbidden in ("run-as", "logcat", "settings", "content", "shared_prefs",
                              "shell cat", "databases", "sms", "backup")
        ))


if __name__ == "__main__":
    unittest.main()
