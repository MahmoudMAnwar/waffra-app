#!/usr/bin/env bash
# Retry only a known Flutter DDS startup/ADB infrastructure failure.
# A failed UI assertion or a second DDS failure always fails CI.
set -uo pipefail

for attempt in 1 2; do
  log="$(mktemp)"
  echo "Real Android insets smoke: attempt ${attempt}/2"
  if flutter test --reporter expanded integration_test/m278_android_system_bars_smoke_test.dart -d emulator-5554 2>&1 | tee "$log"; then
    rm -f "$log"
    exit 0
  fi

  if [[ "$attempt" -ge 2 ]] || ! grep -Fq 'Failed to start Dart Development Service' "$log"; then
    echo "Android insets smoke failed; retaining the failing test result." >&2
    rm -f "$log"
    exit 1
  fi

  echo "Known DDS startup failure: restart ADB and retry once, without waiving QA."
  rm -f "$log"
  adb kill-server || true
  adb start-server
  adb wait-for-device
done

exit 1
