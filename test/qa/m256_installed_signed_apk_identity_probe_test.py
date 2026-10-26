"""M256: wholly synthetic command fixtures, never physical-phone evidence."""
from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/qa"))
import m256_installed_signed_apk_identity_probe as m256

APK_SHA = "a" * 64
CERT_SHA = "b" * 64
COMMIT_SHA = "c" * 40
PATH = "/data/app/~~code/COM.waffra.app-ABC=/base.apk"
SERIALS = ("TEST_DEVICE_A", "TEST_DEVICE_B")


def signed_report():
    return {
        "milestone": "M190",
        "status": "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO",
        "apk_signature_preflight_passed": True,
        "package": "com.waffra.app",
        "apk_sha256": APK_SHA,
        "certificate_sha256": CERT_SHA,
        "version_code": 706,
        "physical_android_devices_verified": False,
        "device_installed_apk_byte_identity_verified": False,
        "cross_device_encrypted_restore_verified": False,
        "live_finance_routes_24_of_24_verified": False,
        "production_sqlcipher_cutover_permitted": False,
        "google_play_publication_permitted": False,
    }


class FakeAdb:
    def __init__(self, mode="ok"):
        self.mode = mode
        self.calls = []
        self.device_lists = 0
        self.paths = 0

    def __call__(self, argv: list[str]) -> str:
        self.calls.append(tuple(argv))
        if argv == ["devices", "-l"]:
            self.device_lists += 1
            if self.mode == "one_device":
                return "List of devices attached\nTEST_DEVICE_A device usb:1"
            if self.mode == "changed" and self.device_lists >= 3:
                return ("List of devices attached\nTEST_DEVICE_A device usb:1\n"
                        "OTHER_PHONE device usb:2")
            return ("List of devices attached\nTEST_DEVICE_A device usb:1\n"
                    "TEST_DEVICE_B device usb:2")
        if len(argv) < 5 or argv[0] != "-s" or argv[2] != "shell":
            raise AssertionError("Unexpected ADB call shape")
        serial = argv[1]
        if serial not in SERIALS:
            raise AssertionError("Unknown synthetic device")
        if argv[3] == "getprop":
            name = argv[4]
            if name == "ro.kernel.qemu":
                return "1" if self.mode == "emulator" else "0"
            if name == "ro.hardware":
                return "kalama"
            if name == "ro.build.version.sdk":
                return "35"
            if name == "ro.build.fingerprint":
                return "synthetic/manufacturer/model:16/test/release-keys/" + serial
            raise AssertionError("Unexpected getprop")
        if argv[3:5] == ["pm", "path"]:
            self.paths += 1
            if self.mode == "split":
                return "package:" + PATH + "\npackage:/data/app/other/split.apk"
            if self.mode == "unsafe_path":
                return "package:/data/app/unsafe/$(touch hacked)/base.apk"
            if self.mode == "path_changed" and self.paths > 3:
                return "package:/data/app/other/else/base.apk"
            return "package:" + PATH
        if argv[3] == "sha256sum":
            digest = "0" * 64 if self.mode == "different_hash" else APK_SHA
            file_path = "/data/app/else/other/base.apk" if (
                self.mode == "wrong_output_path") else argv[4]
            return digest + "  " + file_path
        raise AssertionError("Unexpected ADB read")


def review(adb=None, signed=None, sha=COMMIT_SHA):
    return m256.review(
        Path("synthetic-not-on-disk.apk"),
        expected_apk_sha256=APK_SHA,
        expected_cert_sha256=CERT_SHA,
        reviewed_commit_sha=sha,
        command=adb if adb is not None else FakeAdb(),
        apk_attester=lambda *args, **kwargs:
            signed if signed is not None else signed_report(),
    )


class M256InstalledIdentityTest(unittest.TestCase):
    def test_matching_mocked_hashes_still_refuse_production_release(self):
        adb = FakeAdb()
        report = review(adb)
        self.assertEqual(report["connected_device_count_observed_via_adb"], 2)
        self.assertTrue(report["local_adb_installed_apk_hash_match_observed"])
        self.assertFalse(report["independent_installed_binary_attestation"])
        self.assertFalse(report["source_commit_bound_to_signed_binary"])
        self.assertFalse(report["cross_device_restore_attested"])
        self.assertFalse(report["production_sqlcipher_cutover_permitted"])
        self.assertFalse(report["apk_release_permitted"])
        self.assertFalse(report["human_release_approved"])
        self.assertEqual(report["status"], "LOCAL_ADB_HASH_OBSERVATION_ONLY_RELEASE_NO_GO")
        self.assertGreaterEqual(len(report["blockers"]), 12)
        serialized = json.dumps(report)
        self.assertNotIn("TEST_DEVICE_A", serialized)
        self.assertNotIn("TEST_DEVICE_B", serialized)
        self.assertNotIn("/data/app/", serialized)
        self.assertFalse(any("pull" in command or "install" in command or
                             "logcat" in command for args in adb.calls
                             for command in args))

    def test_single_device_and_emulator_cannot_pass(self):
        for mode in ("one_device", "emulator"):
            with self.subTest(mode=mode):
                with self.assertRaises(m256.HardwareEvidenceRefused):
                    review(FakeAdb(mode))

    def test_changed_adb_device_inventory_refuses(self):
        with self.assertRaises(m256.DevicePackageRefused):
            review(FakeAdb("changed"))

    def test_wrong_device_apk_hash_refuses(self):
        with self.assertRaises(m256.DevicePackageRefused):
            review(FakeAdb("different_hash"))

    def test_split_apk_installation_refuses_instead_of_ignoring_splits(self):
        adb = FakeAdb("split")
        with self.assertRaises(m256.DevicePackageRefused):
            review(adb)
        self.assertFalse(any("sha256sum" in args for args in adb.calls))

    def test_unsafe_shell_path_is_never_passed_to_sha256sum(self):
        adb = FakeAdb("unsafe_path")
        with self.assertRaises(m256.DevicePackageRefused):
            review(adb)
        self.assertFalse(any("sha256sum" in args for args in adb.calls))

    def test_checksum_output_must_bind_to_exact_installed_path(self):
        with self.assertRaises(m256.DevicePackageRefused):
            review(FakeAdb("wrong_output_path"))

    def test_installed_apk_path_change_refuses(self):
        with self.assertRaises(m256.DevicePackageRefused):
            review(FakeAdb("path_changed"))

    def test_wrong_local_signed_report_is_not_accepted(self):
        bad = signed_report()
        bad["certificate_sha256"] = "d" * 64
        with self.assertRaises(m256.DevicePackageRefused):
            review(signed=bad)

    def test_review_sha_must_be_exact_lowercase_hex(self):
        for bad in ("main", "c" * 39, "C" * 40, "f" * 64):
            with self.subTest(sha=bad), self.assertRaises(m256.DevicePackageRefused):
                review(sha=bad)

    def test_no_adb_commands_run_if_signer_preflight_fails(self):
        adb = FakeAdb()
        with self.assertRaises(m256.SignedApkPreflightRefused):
            m256.review(
                Path("synthetic.apk"),
                expected_apk_sha256=APK_SHA,
                expected_cert_sha256=CERT_SHA,
                reviewed_commit_sha=COMMIT_SHA,
                command=adb,
                apk_attester=lambda *args, **kwargs: (_ for _ in ()).throw(
                    m256.SignedApkPreflightRefused("not verified")),
            )
        self.assertEqual(adb.calls, [])

    def test_local_private_report_is_exclusive_and_owner_private(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "private.json"
            m256._write_private_report(output, review())
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError):
                m256._write_private_report(output, {"status": "forged-go"})


if __name__ == "__main__":
    unittest.main()
