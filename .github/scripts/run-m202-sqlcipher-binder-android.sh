#!/usr/bin/env bash
set -euo pipefail

# Android emulator tests use a throwaway SQLCipher vault and synthetic records.
# No user key, Firebase account, real receipt or physical device is involved.
run_check() {
  local name="$1"
  local seconds="$2"
  echo "M202_ANDROID_TEST_START:${name}"
  adb -s emulator-5554 get-state
  timeout --signal=TERM --kill-after=20s "${seconds}s" \
    flutter test "integration_test/${name}" -d emulator-5554 --reporter expanded
  echo "M202_ANDROID_TEST_PASS:${name}"
}

run_check m202_home_widget_source_binder_android_test.dart 1100
run_check live_finance_migration_receipts_android_test.dart 700
run_check m120_verified_receipt_reopen_android_test.dart 700
run_check portable_encrypted_receipts_android_test.dart 700

echo "M202_EMULATOR_QA_PASS: NO physical-device certification, NO production cutover"
