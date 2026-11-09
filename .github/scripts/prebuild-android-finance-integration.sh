#!/usr/bin/env bash
set -euo pipefail

# M626: build the FIRST integration test target for this shard before starting
# its device-test time budget. Cold Gradle/CMake compilation must be witnessed
# separately, not misreported as a Dart/SQLCipher test assertion failure.
# Never skip the mandatory flutter test invocations in the emulator runner.
shard="${1:-}"
case "$shard" in
  vault) first_test=storage_encryption_android_test.dart ;;
  cloud) first_test=finance_cloud_final_release_android_test.dart ;;
  receipts) first_test=copied_receipt_ledger_android_test.dart ;;
  release) first_test=finance_release_regressions_android_test.dart ;;
  *)
    echo "::error title=Invalid Android finance shard::Unknown prebuild shard: $shard"
    exit 64
    ;;
esac

echo "::group::M626 Android cold build for $shard: $first_test"
# GitHub's 55-minute job limit still applies. Compilation is individually
# bounded and MUST fail before emulator tests if the Android APK cannot build.
timeout --signal=TERM --kill-after=30s 900s \
  flutter build apk --debug --no-pub --target "integration_test/$first_test"
apk="build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -s "$apk" ]]; then
  echo "::error title=Missing prebuilt Android debug APK::$apk"
  exit 1
fi
unzip -tqq "$apk" || {
  echo "::error title=Invalid prebuilt Android debug APK::$apk"
  exit 1
}
echo "ANDROID_PREBUILD_PASS:$shard:$first_test"
echo '::endgroup::'
