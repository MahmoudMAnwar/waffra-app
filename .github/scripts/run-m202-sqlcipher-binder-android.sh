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
    # Preserve the first successful VM-service connection strategy. Only
    # reset ADB tunnels *between* independent test apps or after a retry.
    if (( attempt > 1 )) || [[ "$name" != "m202_home_widget_source_binder_android_test.dart" ]]; then
      adb -s "$device" shell am force-stop com.waffra.waffra >/dev/null 2>&1 || true
      adb -s "$device" forward --remove-all || true
      adb -s "$device" reverse --remove-all || true
    fi
    echo "M202_ANDROID_DRIVER_ATTEMPT:${name}:${attempt}"

    # Use the original known-working Flutter drive transport. Check
    # integrationDriver's real exit code even while streaming to tee.
    set +e
    timeout --signal=TERM --kill-after=20s "${seconds}s" \
      flutter drive \
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
    if (( attempt == 1 )) \
      && ! grep -Fq 'VMServiceFlutterDriver: Connected to Flutter application.' "$log" \
      && ! grep -Fq 'Test failed.' "$log" \
      && ! grep -Fq 'Expected:' "$log" \
      && { { (( rc == 124 )) && grep -Fq 'It is taking an unusually long time to connect to the VM' "$log"; } \
           || { (( rc == 1 )) && grep -Eq 'Service connection disposed|adb: device offline|Failed to stop app' "$log"; }; }; then
      echo "::warning::M202 Flutter/ADB bridge failed before app assertions; restarting ADB service once"
      adb kill-server || true
      adb start-server || true
      if ! timeout 55s adb -s "$device" wait-for-device; then
        echo "::error::Emulator did not reconnect; preserving Android CI failure"
        break
      fi
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
