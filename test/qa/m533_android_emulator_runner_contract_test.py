"""M533: fail-closed regression for recurring Android Emulator host crashes.

These checks MUST NOT substitute for running the actual API35 emulator UI test.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / ".github/workflows/m274-production-ui-golden.yml").read_text()
SCRIPT = (ROOT / ".github/scripts/run-m274-android-tap-smoke.sh").read_text()


class M533AndroidEmulatorStabilityContractTest(unittest.TestCase):
    def test_emulator_binary_is_deterministic_stable_and_vulkan_is_disabled(self):
        self.assertIn("emulator-build: 15004761", WORKFLOW)
        self.assertIn("emulator-options: -no-window -no-audio -no-snapshot "
                      "-gpu swiftshader -feature -Vulkan -no-boot-anim", WORKFLOW)
        self.assertNotIn("-gpu software", WORKFLOW)
        self.assertNotIn("-gpu swiftshader_indirect", WORKFLOW)
        self.assertIn("36.4.10.0 (build_id 15004761)", WORKFLOW)
        self.assertIn("36.4.10.0 (build_id 15004761)", SCRIPT)

    def test_preserves_exact_flutter_driver_and_real_android_ui(self):
        self.assertIn("api-level: 35", WORKFLOW)
        self.assertIn("arch: x86_64", WORKFLOW)
        self.assertIn("cores: 2", WORKFLOW)
        self.assertIn("uses: reactivecircus/android-emulator-runner@v2", WORKFLOW)
        self.assertIn("script: bash .github/scripts/run-m274-android-tap-smoke.sh",
                      WORKFLOW)
        self.assertIn('flutter drive --driver=test_driver/integration_test.dart',
                      SCRIPT)
        self.assertIn('--target="$test_file"', SCRIPT)
        self.assertIn('--use-application-binary=build/app/outputs/flutter-apk/app-debug.apk',
                      SCRIPT)
        self.assertIn('integration_test/m274_ui_tap_smoke_android_test.dart', SCRIPT)
        self.assertIn('M274_ANDROID_UI_PASS:real_footer_and_privacy_taps', SCRIPT)
        self.assertIn('exit "$result"', SCRIPT)
        self.assertNotIn('|| true\n    flutter drive', SCRIPT)

    def test_m412_docs_only_sync_cannot_turn_skipped_android_green(self):
        impact = WORKFLOW.split("  m412-impact:", 1)[1].split(
            "  widget-ui-and-golden-candidates:", 1)[0]
        self.assertIn("M412 Impact Telemetry", impact)
        self.assertIn("run: 'true'", impact)
        self.assertNotIn("run: ${{ steps.impact.outputs.run }}", impact)
        # Both expensive jobs MUST actually run whenever M274 is triggered.
        self.assertEqual(
            WORKFLOW.count("if: ${{ needs.m412-impact.outputs.run == 'true' }}"),
            2,
        )
        self.assertIn("android-emulator-ui-taps:", WORKFLOW)
        self.assertIn("widget-ui-and-golden-candidates:", WORKFLOW)

    def test_skipped_android_or_golden_cannot_be_certified_green(self):
        gate = WORKFLOW.split("  m274-required-android-certification:", 1)[1]
        self.assertIn("if: ${{ always() }}", gate)
        self.assertIn("needs: [m412-impact, widget-ui-and-golden-candidates, android-emulator-ui-taps]", gate)
        for token in [
            "M274_IMPACT_RESULT",
            "M274_GOLDEN_RESULT",
            "M274_ANDROID_RESULT",
            '!= "success"',
            "exit 1",
            "M533_M274_REAL_JOBS_CONFIRMED:android_and_golden_success",
        ]:
            self.assertIn(token, gate)
        self.assertIn("M274 Mandatory Actual Android + Golden Completion Gate", gate)

    def test_crashed_emulator_is_red_and_has_bounded_diagnostics(self):
        self.assertIn("if: failure()", WORKFLOW)
        self.assertIn("path: build/m274/*.log", WORKFLOW)
        self.assertIn("retention-days: 7", WORKFLOW)
        self.assertIn('M533_EMULATOR_HOST_PROCESS', SCRIPT)
        self.assertIn('M533_EMULATOR_CRASH_EVIDENCE', SCRIPT)
        self.assertIn('M274_FAILURE_DIAGNOSTICS_BEGIN', SCRIPT)
        self.assertIn('::error::M274 Android UI smoke failed', SCRIPT)
        self.assertNotIn('continue-on-error: true', WORKFLOW)
        self.assertNotIn('flutter drive || true', SCRIPT)
        self.assertNotIn('echo "M274_ANDROID_UI_PASS"\nexit 0', SCRIPT)


if __name__ == "__main__":
    unittest.main()
