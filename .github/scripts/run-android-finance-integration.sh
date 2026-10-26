#!/usr/bin/env bash
set -euo pipefail

# Android emulator runner executes each YAML script line as its own sh -c.
# This file is invoked with ONE command: bash .../run-android-finance-integration.sh
run_android_test() {
  filename="$1"
  seconds="$2"
  echo "::group::Android integration: ${filename}"
  echo "ANDROID_TEST_START:${filename}"
  # Keep a short crash-only log *before* Flutter connects to its VM service.
  # If the VM service disappears, adb may be offline by the time test exits.
  local crash_log crash_pid
  crash_log="$(mktemp)"
  adb -s emulator-5554 logcat -c >/dev/null 2>&1 || true
  adb -s emulator-5554 logcat -v brief \
    'AndroidRuntime:E' 'libc:F' 'flutter:E' '*:S' \
    > "${crash_log}" 2>&1 &
  crash_pid="$!"
  # A hosted-runner Maven mirror may return HTTP 429 while resolving the
  # Gradle build *before* any test starts. Retry only that exact dependency
  # failure, bounded; never mask a test assertion, app crash, or SQLCipher fault.
  local code=1 attempt=0 max_attempts=4 output_log
  output_log="$(mktemp)"
  while (( attempt < max_attempts )); do
    attempt=$((attempt+1))
    : > "${output_log}"
    if timeout --signal=TERM --kill-after=20s "${seconds}s" \
      flutter test "integration_test/${filename}" -d emulator-5554 --reporter expanded \
      2>&1 | tee "${output_log}"; then
      code=0
      break
    else
      code="${PIPESTATUS[0]}"
    fi
    if (( attempt < max_attempts )) && \
       grep -Eq '(Gradle task assembleDebug failed|Gradle threw an error while downloading artifacts|Could not resolve org.jetbrains.kotlin)' "${output_log}" && \
       grep -Eq '(429|Too Many Requests)' "${output_log}"; then
      delay=$((20 * attempt))
      echo "::warning title=Gradle dependency rate limit::Gradle Maven HTTP 429 before runtime test. Retry ${attempt}/${max_attempts} in ${delay}s; no finance assertion was skipped."
      sleep "${delay}"
    else
      break
    fi
  done
  rm -f "${output_log}"
  kill "${crash_pid}" 2>/dev/null || true
  wait "${crash_pid}" 2>/dev/null || true
  if [[ "${code}" -eq 0 ]]; then
    rm -f "${crash_log}"
    echo "ANDROID_TEST_PASS:${filename}"
  else
    echo "::error title=Android emulator failure::${filename} failed or exceeded ${seconds}s (exit=${code})"
    echo "Crash-only AndroidRuntime/libc/flutter logs captured before VM disconnect:"
    tail -n 100 "${crash_log}" || true
    rm -f "${crash_log}"
    timeout 10s adb -s emulator-5554 get-state || true
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
run_android_test m78_parallel_combined_android_test.dart 300
run_android_test offline_restore_android_test.dart 240
run_android_test copied_receipt_ledger_android_test.dart 240
run_android_test fresh_vault_first_run_android_test.dart 240
run_android_test offline_finance_e2e_android_test.dart 240
run_android_test finance_release_regressions_android_test.dart 240
run_android_test live_finance_migration_receipts_android_test.dart 240
