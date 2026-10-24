#!/usr/bin/env bash
set -euo pipefail

# CI-only synthetic SQLCipher verification on Android, never real user data.
# flutter test -d emulator-5554 built and installed an APK on 2026-10-24 but
# then hung until timeout without running any tests. Use Flutter's supported
# integration_test driver and fail closed on connection/time-out errors.
mkdir -p test_driver build/m202/driver-logs
cat > test_driver/m202_ci_integration_test_driver.dart <<'DART'
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
DART

device="emulator-5554"
adb -s "$device" wait-for-device
test "$(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')" = "1" || {
  echo "::error::Emulator boot has not completed; refusing false pass"
  exit 1
}

run_check() {
  local name="$1"
  local seconds="$2"
  local log="build/m202/driver-logs/${name}.log"
  echo "M202_ANDROID_TEST_START:${name}"
  adb -s "$device" get-state

  # Keep the full Flutter driver transcript in the Actions log and preserve
  # the real exit code through tee. A timeout must NEVER count as a pass.
  local rc
  set +e
  timeout --signal=TERM --kill-after=20s "${seconds}s" \
    flutter drive \
      --driver=test_driver/m202_ci_integration_test_driver.dart \
      --target="integration_test/${name}" \
      -d "$device" \
      2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e

  if (( rc != 0 )); then
    echo "::error::M202 Android integration test ${name} failed (exit ${rc}); APK blocked"
    echo "::group::Android activity and crash diagnostics (synthetic emulator)"
    adb -s "$device" shell dumpsys activity activities 2>&1 | tail -65 || true
    adb -s "$device" logcat -d -t 250 -v brief 2>&1 \
      | grep -E -i 'flutter|dart|AndroidRuntime|FATAL EXCEPTION|CRASH|SQLite|SQLCipher|am_proc_died|ANR' \
      | tail -85 || true
    echo "::endgroup::"
    exit "$rc"
  fi

  # Only a zero exit status from integrationDriver counts as a pass.
  echo "M202_ANDROID_TEST_PASS:${name}"
}

# Bound hung device connections; each case must still pass independently.
run_check m202_home_widget_source_binder_android_test.dart 720
run_check live_finance_migration_receipts_android_test.dart 600
run_check m120_verified_receipt_reopen_android_test.dart 600
run_check portable_encrypted_receipts_android_test.dart 600

echo "M202_EMULATOR_QA_PASS: NO physical-device certification, NO production cutover"
