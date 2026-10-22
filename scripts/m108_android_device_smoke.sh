#!/usr/bin/env bash
set -euo pipefail

# Manual, *local* signed-APK cold-launch smoke only; NOT a two-device signoff.
# Run on a disposable test phone or after safely backing up its app data.
# Never run on a production phone or accept credential inputs in CI logs.
#
# Usage:
#   WAFFRA_QA_DEVICE_CONFIRMED=YES bash scripts/m108_android_device_smoke.sh \
#      /path/to/app-release.apk PHONE_ADB_SERIAL

if [[ "${WAFFRA_QA_DEVICE_CONFIRMED:-}" != YES ]]; then
  echo "BLOCKED: Set WAFFRA_QA_DEVICE_CONFIRMED=YES only after confirming a dedicated test phone and safe test data."
  exit 2
fi
if [[ $# -ne 2 ]]; then
  echo "Usage: bash scripts/m108_android_device_smoke.sh SIGNED_APK ADB_SERIAL"
  exit 2
fi
apk=$1
serial=$2
if [[ ! -f "$apk" || ! -s "$apk" || -z "$serial" ]]; then
  echo "Missing signed APK or explicit Android device serial."
  exit 2
fi
if ! command -v adb >/dev/null 2>&1; then
  echo "Android adb is required on your own test laptop."
  exit 2
fi
if ! adb -s "$serial" get-state 2>/dev/null | grep -qx device; then
  echo "Requested test device is not connected and authorized."
  exit 2
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "sha256sum is required to attest to exact artifact."
  exit 2
fi

printf 'APK SHA256: '
sha256sum "$apk" | cut -d ' ' -f 1
echo "Installing SIGNED TEST artifact onto the explicit test device..."
adb -s "$serial" install -r "$apk" >/dev/null
adb -s "$serial" shell pm path com.waffra.app | grep -q '^package:'
adb -s "$serial" shell am force-stop com.waffra.app >/dev/null
adb -s "$serial" shell monkey -p com.waffra.app \
  -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 5
# Do not collect logcat, user messages, device IDs or screen images.
if [[ -z "$(adb -s "$serial" shell pidof com.waffra.app | tr -d '\r')" ]]; then
  echo "FAIL: Waffra did not remain running in a basic smoke check."
  exit 1
fi
echo "PASS: APK installed and app process stayed alive for the smoke window."
echo "NOT CERTIFIED: Google sign-in, 24 finance writes, widget, backup,"
echo "  crash recovery, Android 16 UX and actual two-device Firebase restore."
echo "Complete docs/release/REAL_DEVICE_GO_NO_GO_AR.md using synthetic transactions."
