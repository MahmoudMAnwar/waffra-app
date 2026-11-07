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
        # M449 release-note-last must still launch real M274 on the exact SHA.
        self.assertIn("'docs/release/WAFFRA_APPROVED_CHANGES.txt'", WORKFLOW)
        self.assertIn("emulator-options: -no-window -no-audio -no-snapshot "
                      "-gpu swiftshader -feature -Vulkan -no-boot-anim", WORKFLOW)
        self.assertNotIn("-gpu software", WORKFLOW)
        self.assertNotIn("-gpu swiftshader_indirect", WORKFLOW)
        # M543: never execute a redundant emulator -version prelaunch
        # process (it marked the job failed with exit 127 even if UI ran).
        self.assertNotIn("pre-emulator-launch-script: |", WORKFLOW)
        # Regression for Flutter engine issue #192736: only the generated
        # disposable test host selects Skia on Linux headless emulators.
        self.assertIn("Apply test-only Linux emulator Impeller compatibility setting", WORKFLOW)
        self.assertIn("android/app/src/main/AndroidManifest.xml", WORKFLOW)
        self.assertIn("io.flutter.embedding.android.EnableImpeller", WORKFLOW)
        self.assertIn('android:value="false"', WORKFLOW)
        self.assertIn("M543_CI_ONLY_IMPELLER_DISABLED:real_android_engine_skia", WORKFLOW)
        self.assertLess(WORKFLOW.index("Apply test-only Linux emulator Impeller compatibility setting"),
                        WORKFLOW.index("Precompile Android UI integration APK before emulator launch"))
        # M534: the workflow verifies actual build before launch; the runner
        # inspects installed metadata without executing emulator -version twice.
        self.assertIn('emulator/source.properties', SCRIPT)
        self.assertIn('M534_EMULATOR_PACKAGE_VERIFIED:36.4.10', SCRIPT)
        self.assertIn("Pkg", SCRIPT)
        self.assertNotIn('version_output=', SCRIPT)
        self.assertNotIn('emulator_bin=', SCRIPT)

    def test_preserves_exact_flutter_driver_and_real_android_ui(self):
        self.assertIn("api-level: 35", WORKFLOW)
        self.assertIn("arch: x86_64", WORKFLOW)
        self.assertIn("cores: 4", WORKFLOW)
        self.assertIn("profile: pixel_2", WORKFLOW)
        self.assertNotIn("profile: pixel_6", WORKFLOW)
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

    def test_m535_atd_keeps_real_api35_ui_and_diagnoses_vm_handshake(self):
        self.assertIn("target: aosp_atd", WORKFLOW)
        self.assertNotIn("target: google_apis", WORKFLOW)
        self.assertIn("api-level: 35", WORKFLOW)
        self.assertIn("timeout --signal=TERM --kill-after=20s 360s", SCRIPT)
        self.assertIn("M535_VM_HANDSHAKE_EVIDENCE", SCRIPT)
        self.assertIn("M535_APP_VM_FATAL_LOGCAT_IF_ALIVE", SCRIPT)
        self.assertIn('forward --list', SCRIPT)
        self.assertIn('shell pidof com.waffra.waffra', SCRIPT)
        self.assertIn('flutter drive --driver=', SCRIPT)
        self.assertIn('exit "$result"', SCRIPT)

    def test_m534_runner_is_well_scoped_and_reaches_real_flutter_drive(self):
        self.assertEqual(SCRIPT.count('for attempt in 1 2; do'), 1)
        self.assertEqual(SCRIPT.count('adb -s "$device" wait-for-device'), 1)
        self.assertEqual(SCRIPT.count('flutter drive --driver='), 1)
        self.assertIn('source_properties="$sdk/emulator/source.properties"', SCRIPT)
        self.assertIn("Pkg", SCRIPT)
        self.assertIn('M534_EMULATOR_PACKAGE_VERIFIED:36.4.10', SCRIPT)
        self.assertNotIn('version_output=', SCRIPT)
        self.assertNotIn('emulator_bin=', SCRIPT)

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
