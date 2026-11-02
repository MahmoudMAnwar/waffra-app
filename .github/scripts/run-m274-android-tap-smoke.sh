#!/usr/bin/env bash
set -euo pipefail

# M274 runs on a disposable Android emulator. Never hide or skip UI failures.
# reactivecircus/android-emulator-runner runs its script using /bin/sh -c,
# so the workflow must invoke THIS file as one shell command.
device="emulator-5554"
test_file="integration_test/m274_ui_tap_smoke_android_test.dart"
adb -s "$device" wait-for-device
test "$(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')" = "1"

mkdir -p build/m274
log="build/m274/android-tap-smoke.log"

for attempt in 1 2; do
  echo "M274_ANDROID_UI_ATTEMPT:$attempt"
  set +e
  # Drive the exact integration APK built before emulator boot. Flutter test
  # would re-run Gradle with the emulator active, exhausting runner memory.
  timeout --signal=TERM --kill-after=20s 900s \
    flutter drive --driver=test_driver/integration_test.dart \
      --target="$test_file" --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk \
      -d "$device" --no-pub > "$log" 2>&1
  result=$?
  set -e
  cat "$log"
  if (( result != 0 )); then
    # M387: record emulator/host state on failure, without changing the result
    # or logging application financial data (these tests use synthetic records).
    echo "M274_FAILURE_DIAGNOSTICS_BEGIN"
    adb devices -l || true
    adb -s "$device" shell getprop sys.boot_completed || true
    df -h . || true
    free -h || true
    ps -eo pid,comm,rss --sort=-rss | head -n 16 || true
    echo "M274_FAILURE_DIAGNOSTICS_END"
  fi
  if (( result == 0 )); then
    echo "M274_ANDROID_UI_PASS:real_footer_and_privacy_taps"
    exit 0
  fi

  # A transient DDS startup failure can happen before any app assertion runs.
  # Do not retry test assertion failures, crashes or timeouts.
  if (( attempt == 1 )) \
    && grep -Eq 'Failed to start Dart Development Service|registerService:.*Service connection disposed' "$log" \
    && test "$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" \
    && ! grep -Eq '([+][1-9]|Test failed\.|Expected:|Actual:)' "$log"; then
    echo "::warning::M274 DDS startup failed before test execution; retrying once after ADB port reset"
    adb -s "$device" forward --remove-all || true
    adb -s "$device" reverse --remove-all || true
    adb -s "$device" shell am force-stop com.waffra.waffra || true
    sleep 5
    continue
  fi
  echo "::error::M274 Android UI smoke failed (exit $result); blocking integration"
  exit "$result"
done

echo "::error::M274 Android UI smoke failed both DDS start attempts"
exit 1
