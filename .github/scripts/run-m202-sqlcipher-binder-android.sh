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

  # Run independent integration apps against a fresh ADB VM-service tunnel.
  # An old forwarded VM port from the previous flutter drive can remain alive
  # while the following application has already been reinstalled.
  local rc=1 attempt=1
  while (( attempt <= 2 )); do
    adb -s "$device" shell am force-stop com.waffra.waffra >/dev/null 2>&1 || true
    adb -s "$device" forward --remove-all || true
    adb -s "$device" reverse --remove-all || true
    echo "M202_ANDROID_DRIVER_ATTEMPT:${name}:${attempt}"

    # Disable DDS for integration_test's VMServiceFlutterDriver. The Flutter
    # integration_test package documents --no-dds for VM service connectivity.
    # Retain the exit status even though output is streamed through tee.
    set +e
    timeout --signal=TERM --kill-after=20s "${seconds}s" \
      flutter drive --no-dds \
        --driver=test_driver/m202_ci_integration_test_driver.dart \
        --target="integration_test/${name}" \
        -d "$device" \
        2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    set -e
    if (( rc == 0 )); then
      echo "M202_ANDROID_TEST_PASS:${name}"
      return 0
    fi

    # Retry exactly once only if the *driver never attached* to the VM.
    # A test assertion failure, crash, SQLCipher failure, or any case where
    # the driver connected is never retried or turned into a false pass.
    if (( attempt == 1 && rc == 124 )) \
      && grep -Fq 'VMServiceFlutterDriver: Connecting to Flutter application' "$log" \
      && grep -Fq 'VMServiceFlutterDriver: It is taking an unusually long time to connect to the VM' "$log" \
      && ! grep -Fq 'VMServiceFlutterDriver: Connected to Flutter application.' "$log" \
      && ! grep -Eq '^[^[:space:]]*.*[+]([1-9]|[0-9]+ -[1-9])' "$log"; then
      echo "::warning::M202 VM-service connection timed out before test start; resetting Android bridge and retrying once"
      attempt=$((attempt + 1))
      sleep 4
      continue
    fi
    break
  done

  echo "::error::M202 Android integration test ${name} failed (exit ${rc}); APK blocked"
  echo "::group::Android activity and crash diagnostics (synthetic emulator)"
  adb -s "$device" shell dumpsys activity activities 2>&1 | tail -65 || true
  adb -s "$device" logcat -d -t 250 -v brief 2>&1 \
    | grep -E -i 'flutter|dart|AndroidRuntime|FATAL EXCEPTION|CRASH|SQLite|SQLCipher|am_proc_died|ANR' \
    | tail -85 || true
  echo "::endgroup::"
  exit "$rc"
}

# Bound hung device connections; each case must still pass independently.
run_check m202_home_widget_source_binder_android_test.dart 720
run_check live_finance_migration_receipts_android_test.dart 600
run_check m120_verified_receipt_reopen_android_test.dart 600
run_check portable_encrypted_receipts_android_test.dart 600

echo "M202_EMULATOR_QA_PASS: NO physical-device certification, NO production cutover"
