"""M969: real Android finance-test failures must survive QEMU teardown.

These tests protect the exact M120 source script and executable GitHub job
without pretending to execute a physical handset or encrypted user archive.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".github/scripts/run-m120-android-receipt-reopen.sh"
WORKFLOW = ROOT / ".github/workflows/m120-android-receipt-cold-reopen.yml"


class M969AndroidEmulatorShutdownTest(unittest.TestCase):
    def test_shutdown_trap_preserves_actual_flutter_driver_exit_code(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("trap _m969ShutdownDisposableEmulator EXIT", source)
        self.assertIn("local test_status=$?", source)
        self.assertIn("trap - EXIT", source)
        self.assertIn('exit "$test_status"', source)
        self.assertIn('timeout --signal=TERM --kill-after=2s 8s', source)
        self.assertIn("pkill -TERM -f '[q]emu-system-x86_64'", source)
        self.assertIn("pkill -KILL -f '[q]emu-system-x86_64'", source)
        self.assertIn('echo "M120_RECEIPT_ANDROID_PASS:real_encrypted_receipt_cold_reopen"',
                      source)
        self.assertLess(source.index("if (( code == 0 )); then"),
                        source.index("if grep -Eq '(Test failed"))
        self.assertIn('exit "$code"', source)
        self.assertIn("VMServiceFlutterDriver: Connected to Flutter application.",
                      source)

    def test_workflow_runs_actual_android_reopen_and_bounded_teardown(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL: '5'", workflow)
        self.assertIn("reactivecircus/android-emulator-runner@v2", workflow)
        self.assertIn("script: bash .github/scripts/run-m120-android-receipt-reopen.sh",
                      workflow)
        self.assertIn("m969_m120_emulator_shutdown_test.py", workflow)
        self.assertIn("dart analyze integration_test/m120_verified_receipt_reopen_android_test.dart",
                      workflow)
        self.assertIn("github.event.pull_request.head.sha || github.sha", workflow)
        self.assertIn("timeout-minutes: 45", workflow)


if __name__ == "__main__":
    unittest.main()
