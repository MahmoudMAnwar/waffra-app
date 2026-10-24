#!/usr/bin/env bash
# M166 offline Android APK preflight. This script DOES NOT install, publish, migrate or erase data.
set -euo pipefail
apk="${1:-}"
if [[ -z "$apk" || ! -f "$apk" ]]; then
  echo "Usage: bash scripts/qa/m166_verify_android_apk.sh /path/to/signed-qa.apk" >&2
  exit 2
fi
for tool in apksigner aapt sha256sum; do
  command -v "$tool" >/dev/null || { echo "BLOCK: missing Android SDK tool: $tool" >&2; exit 2; }
done
echo "SHA-256 (record alongside exact workflow head SHA):"
sha256sum "$apk"
echo "Android signature checks:"
signature_report="$(apksigner verify --verbose --print-certs "$apk")"
printf '%s\n' "$signature_report"
if grep -qi 'CN=Android Debug' <<<"$signature_report"; then
  echo "BLOCK: debug certificate cannot be accepted as release QA signing" >&2
  exit 1
fi
echo "Validate package identity:"
badging="$(aapt dump badging "$apk")"
printf '%s\n' "$badging" | grep '^package:'
if ! grep -q "^package: name='com.waffra.app'" <<<"$badging"; then
  echo "BLOCK: unexpected Android applicationId (Google sign-in risk)" >&2
  exit 1
fi
echo "PASS: APK signature + com.waffra.app package verified OFFLINE."
echo "NOT VERIFIED: physical device install, Google login, SMS, Widget, restore, encryption or Play readiness."
