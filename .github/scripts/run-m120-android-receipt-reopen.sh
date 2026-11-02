#!/usr/bin/env bash
set -euo pipefail

# M120 must exercise the REAL encrypted receipt cold-reopen flow on Android.
# sqlite3.dart's native-asset hook downloads a SHA-256-verified prebuilt
# sqlite3mc Android library from GitHub Releases. Hosted runners may experience
# transient GitHub network timeouts BEFORE any Flutter test can execute.
# Retry ONLY that transport failure. Never mask assertions, analyzer failures,
# plugin errors, wrong native binaries, or receipt data corruption.
device="emulator-5554"
test_file="integration_test/m120_verified_receipt_reopen_android_test.dart"
max_attempts=3
mkdir -p build/m120

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
  timeout --signal=TERM --kill-after=20s 900s \
    flutter test "$test_file" -d "$device" --no-pub --reporter expanded \
    > "$log" 2>&1
  code=$?
  set -e
  cat "$log"

  if (( code == 0 )); then
    echo "M120_RECEIPT_ANDROID_PASS:real_encrypted_receipt_cold_reopen"
    exit 0
  fi

  # This exception occurs during sqlite3's *native-asset download*, before
  # Flutter's test body. It is not evidence of a failed SQLCipher transaction.
  # Keep the retry condition strict, so genuine app/test failures stop the gate.
  if ! grep -Fq 'This failed (attepted to download https://github.com/simolus3/sqlite3.dart/releases/download/' "$log" \
     || ! grep -Eq '(SocketException: Connection timed out|SocketException: Connection reset|Connection closed before full header|HandshakeException)' "$log" \
     || ! grep -Fq 'Building assets for package:sqlite3 failed.' "$log" \
     || grep -Eq '(Test failed\.|Expected:|Actual:|\[E\].*M120 Android SQLCipher receipt)' "$log"; then
    echo "::error::M120 failed for a non-retryable reason (exit ${code}); preserving failure"
    exit "$code"
  fi

  if (( attempt == max_attempts )); then
    echo "::error::M120 sqlite3mc download failed after ${max_attempts} authenticated-hook attempts"
    exit "$code"
  fi

  echo "::warning::M120 native sqlite3mc GitHub download timed out before test execution; retry ${attempt}/${max_attempts} without altering SQLCipher configuration"
  sleep $(( attempt * 15 ))
done

echo "::error::M120 did not complete"
exit 1
