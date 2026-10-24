"""M189: only real online hardware can produce even preliminary device evidence."""
from __future__ import annotations

import datetime as dt
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/m189_physical_device_source_probe.py"
spec = importlib.util.spec_from_file_location("m189_device", SCRIPT)
assert spec is not None and spec.loader is not None
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

SOURCE = (ROOT / "lib/storage/waffra_production_finance_routing_gate.dart"
          ).read_text(encoding="utf-8")


def mock_adb(args: list[str], *, mode: str = "valid") -> str:
    if args == ["devices", "-l"]:
        if mode == "one":
            return "List of devices attached\nANDROID_A device usb:1"
        if mode == "duplicate":
            return ("List of devices attached\nANDROID_A device usb:1\n"
                    "ANDROID_A device usb:2")
        if mode == "unauthorized":
            return ("List of devices attached\nANDROID_A unauthorized\n"
                    "ANDROID_B device")
        return ("List of devices attached\nANDROID_A device usb:1\n"
                "ANDROID_B device usb:2")
    serial = args[2]
    name = args[-1]
    if serial not in ("ANDROID_A", "ANDROID_B"):
        raise AssertionError("ADB serial unexpectedly changed")
    if args[3:5] == ["getprop", "ro.kernel.qemu"]:
        return "1" if mode == "emulator" else "0"
    if args[3:5] == ["getprop", "ro.hardware"]:
        return "ranchu" if mode == "virtualized" else "kalama"
    if args[3:5] == ["getprop", "ro.build.version.sdk"]:
        return "35" if mode != "old" else "25"
    if args[3:5] == ["getprop", "ro.build.fingerprint"]:
        return ("samsung/physical/phone:16/UP1A/test:user/release-keys"
                if serial == "ANDROID_A"
                else "google/physical/phone:16/UP1A/test:user/release-keys")
    if args[3:5] == ["pm", "path"]:
        return "" if mode == "no_package" else "package:/data/app/base.apk"
    raise AssertionError("ADB command not allowed " + repr(args))


class M189PhysicalWitnessTests(unittest.TestCase):
    def test_exact_source_route_contract_is_all_twenty_four(self) -> None:
        routes = m.routes_from_repo(SOURCE)
        self.assertEqual(len(routes), 24)
        self.assertEqual(len(set(routes)), 24)
        self.assertIn("widgetBalanceRefresh", routes)
        self.assertIn("backupRestore", routes)
        self.assertIn("fullFinanceReset", routes)

    def test_unknown_route_requires_independent_security_reaudit(self) -> None:
        corrupted = SOURCE.replace("appStartup,", "inventedStartup,")
        with self.assertRaises(m.HardwareEvidenceRefused):
            m.routes_from_repo(corrupted)

    def test_two_mock_phones_are_not_release_certification(self) -> None:
        evidence = m.capture(
            lambda args: mock_adb(args),
            now=lambda: dt.datetime(2026, 10, 24, tzinfo=dt.timezone.utc),
            nonce=lambda: "synthetic-secret-test-only",
            source=SOURCE,
        )
        self.assertEqual(evidence["hardware_detected"], 2)
        self.assertEqual(len(evidence["route_inventory"]), 24)
        self.assertEqual(evidence["route_execution_witnesses"], [])
        self.assertFalse(evidence["source_cutover_attested"])
        self.assertFalse(evidence["store_publication_permitted"])
        self.assertFalse(evidence["backup_restore_across_two_real_devices_attested"])
        self.assertFalse(evidence["os_backed_key_recovery_attested"])
        self.assertFalse(evidence["human_release_approval"])
        raw = json.dumps(evidence)
        self.assertNotIn("ANDROID_A", raw)
        self.assertNotIn("ANDROID_B", raw)
        self.assertNotIn("synthetic-secret-test-only", raw)
        self.assertNotIn("waffra account", raw.lower())

    def test_same_serial_or_single_device_cannot_count_as_two(self) -> None:
        for mode in ("one", "duplicate", "unauthorized"):
            with self.subTest(mode=mode):
                with self.assertRaises(m.HardwareEvidenceRefused):
                    m.capture(lambda args: mock_adb(args, mode=mode),
                              source=SOURCE)

    def test_emulator_or_virtual_android_is_never_physical(self) -> None:
        for mode in ("emulator", "virtualized"):
            with self.subTest(mode=mode):
                with self.assertRaises(m.HardwareEvidenceRefused):
                    m.capture(lambda args: mock_adb(args, mode=mode),
                              source=SOURCE)

    def test_unsupported_os_or_uninstalled_apk_refuses_evidence(self) -> None:
        for mode in ("old", "no_package"):
            with self.subTest(mode=mode):
                with self.assertRaises(m.HardwareEvidenceRefused):
                    m.capture(lambda args: mock_adb(args, mode=mode),
                              source=SOURCE)

    def test_device_probes_cannot_leak_raw_serial_or_read_finance(self) -> None:
        calls = []
        def runner(args: list[str]) -> str:
            calls.append(args)
            return mock_adb(args)
        evidence = m.capture(runner, source=SOURCE)
        self.assertEqual(evidence["status"],
                         "PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO")
        allowed = {"devices", "getprop", "pm"}
        self.assertTrue(all(
            args[0] == "devices" or (
                args[0] == "-s" and args[2] == "shell"
                and args[3] in allowed
            ) for args in calls
        ))
        self.assertFalse(any(
            "pull" in args or "logcat" in args or "run-as" in args or
            "shell su" in " ".join(args)
            for args in calls
        ))


if __name__ == "__main__":
    unittest.main()
