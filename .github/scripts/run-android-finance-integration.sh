#!/usr/bin/env bash
set -eu

# Android emulator runner executes each YAML script line as its own sh -c.
# This file is invoked with ONE command: bash .../run-android-finance-integration.sh
run_android_test() {
  filename="$1"
  seconds="$2"
  echo "::group::Android integration: ${filename}"
  echo "ANDROID_TEST_START:${filename}"
  if timeout --signal=TERM --kill-after=20s "${seconds}s" \
    flutter test "integration_test/${filename}" -d emulator-5554 --reporter expanded; then
    echo "ANDROID_TEST_PASS:${filename}"
  else
    code="$?"
    echo "::error title=Android emulator failure::${filename} failed or exceeded ${seconds}s (exit=${code})"
    timeout 20s adb -s emulator-5554 logcat -d -t 120 '*:E' || true
    exit "${code}"
  fi
  echo '::endgroup::'
}

# Prioritize problematic bridge & new encrypted receipts after Gradle warmup.
run_android_test storage_encryption_android_test.dart 720
run_android_test verified_encrypted_finance_bridge_android_test.dart 240
run_android_test portable_encrypted_receipts_android_test.dart 240
run_android_test finance_cloud_final_release_android_test.dart 300
run_android_test offline_restore_android_test.dart 240
run_android_test copied_receipt_ledger_android_test.dart 240
run_android_test fresh_vault_first_run_android_test.dart 240
run_android_test offline_finance_e2e_android_test.dart 240
run_android_test finance_release_regressions_android_test.dart 240
run_android_test live_finance_migration_receipts_android_test.dart 240
