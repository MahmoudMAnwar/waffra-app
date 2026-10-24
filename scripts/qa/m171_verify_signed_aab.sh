#!/usr/bin/env bash
# M171: human-operated OFFLINE AAB verification with public cert fingerprint only.
# No keystore, signing password, Play API key or Firebase token is loaded.
set -euo pipefail
bundle="${1:-}"
expected_sha256="894c436dc4270d46815707a29147709e89cd42d40fbf5d3ae24104293b03ae8c"
if [[ -z "$bundle" || ! -s "$bundle" ]]; then
  echo "Usage: bash scripts/qa/m171_verify_signed_aab.sh /path/to/app-release.aab" >&2
  exit 2
fi
for cmd in unzip jarsigner keytool sha256sum; do
  command -v "$cmd" >/dev/null || { echo "Missing verification tool: $cmd" >&2; exit 2; }
done
unzip -t "$bundle" > /dev/null
jarsigner -verify -strict "$bundle" >/dev/null
sha256sum "$bundle"
cert_report="$(keytool -printcert -jarfile "$bundle")"
cert_sha256="$(printf '%s\n' "$cert_report" | sed -n -E 's/^[[:space:]]*SHA256:[[:space:]]*([0-9A-Fa-f:]+).*/\1/p' | head -1 | tr -d ':' | tr '[:upper:]' '[:lower:]')"
if [[ "$cert_sha256" != "$expected_sha256" ]]; then
  echo "BLOCK: AAB is not signed by expected Firebase Waffra release cert" >&2
  exit 1
fi
# Manifest checks require bundletool; never infer package/SDK from file name.
if [[ -n "${BUNDLETOOL_JAR:-}" ]]; then
  command -v java >/dev/null || { echo "Java required for BUNDLETOOL_JAR" >&2; exit 2; }
  manifest="$(java -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$bundle" --module=base)"
elif command -v bundletool >/dev/null; then
  manifest="$(bundletool dump manifest --bundle="$bundle" --module=base)"
else
  echo "BLOCK: bundletool or BUNDLETOOL_JAR needed to verify embedded package/API" >&2
  exit 2
fi
grep -Eq 'package="com\.waffra\.app"' <<<"$manifest" ||
  { echo "BLOCK: wrong Android package" >&2; exit 1; }
grep -Eq '(targetSdkVersion|targetSdk)="36"' <<<"$manifest" ||
  { echo "BLOCK: Android API 36 target not proven" >&2; exit 1; }
echo "PASS: signed, non-corrupt AAB cert, package and API 36 metadata; actual Play App Signing/device OAuth still require review."
