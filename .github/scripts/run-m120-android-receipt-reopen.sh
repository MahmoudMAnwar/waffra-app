#!/usr/bin/env bash
set -euo pipefail

# M120 executes the actual encrypted receipt cold-reopen integration test
# against an Android emulator. The CI driver is generated, never deployed.
# Retry ONLY pre-test transport errors; never mask finance assertions,
# SQLCipher key failures, native-asset corruption or broken receipt flows.
device="emulator-5554"
test_file="integration_test/m120_verified_receipt_reopen_android_test.dart"
max_attempts=3
mkdir -p build/m120 test_driver
cat > test_driver/m120_ci_integration_test_driver.dart <<'DART'
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
DART

adb -s "$device" wait-for-device
boot="$(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')"
if [[ "$boot" != "1" ]]; then
  echo "::error::M120 Android emulator is not fully booted"
  exit 1
fi

for (( attempt=1; attempt<=max_attempts; attempt++ )); do
  log="build/m120/android-receipt-reopen-attempt-${attempt}.log"
  echo "M120_RECEIPT_ANDROID_ATTEMPT:${attempt}"
  set +e
  timeout --signal=TERM --kill-after=20s 720s \
    flutter drive \
      --driver=test_driver/m120_ci_integration_test_driver.dart \
      --target="$test_file" -d "$device" \
      > "$log" 2>&1
  code=$?
  set -e
  cat "$log"

  if (( code == 0 )); then
    echo "M120_RECEIPT_ANDROID_PASS:real_encrypted_receipt_cold_reopen"
    exit 0
  fi

  # A real test assertion, a connected driver, or an app crash is never retried.
  if grep -Eq '(Test failed\.|Expected:|Actual:|Some tests failed|\[E\].*M120 Android SQLCipher receipt|FATAL EXCEPTION|Unhandled exception)' "$log" \
      || grep -Fq 'VMServiceFlutterDriver: Connected to Flutter application.' "$log"; then
    echo "::error::M120 failed after reaching test execution (exit ${code}); preserving failure"
    exit "$code"
  fi

  native_timeout=false
  if grep -Fq 'Building assets for package:sqlite3 failed.' "$log" \
      && grep -Fq 'https://github.com/simolus3/sqlite3.dart/releases/download/' "$log" \
      && grep -Eq '(SocketException: Connection timed out|SocketException: Connection reset|Connection closed before full header|HandshakeException)' "$log"; then
    native_timeout=true
  fi

  vm_transport=false
  if grep -Eq '(Failed to start Dart Development Service|It is taking an unusually long time to connect to the VM|Failed to connect to the VM Service|Service connection disposed)' "$log"; then
    vm_transport=true
  fi

  if [[ "$native_timeout" != true && "$vm_transport" != true ]]; then
    echo "::error::M120 non-transport failure (exit ${code}); preserving failure"
    exit "$code"
  fi
  if (( attempt == max_attempts )); then
    echo "::error::M120 pre-test transport did not recover after ${max_attempts} attempts"
    exit "$code"
  fi

  # Clear only stale Android debug service tunnels between attempts.
  # Reuse the real emulator and keep every SQLCipher assertion enabled.
  echo "::warning::M120 pre-test Android/Flutter transport failed; retrying real device test (${attempt}/${max_attempts})"
  adb -s "$device" shell am force-stop com.waffra.waffra >/dev/null 2>&1 || true
  adb -s "$device" forward --remove-all >/dev/null 2>&1 || true
  adb -s "$device" reverse --remove-all >/dev/null 2>&1 || true
  sleep $(( attempt * 10 ))
done

echo "::error::M120 did not complete"
exit 1
