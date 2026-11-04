#!/usr/bin/env bash
# Run this file as ONE command from reactivecircus/android-emulator-runner.
# Its script input is split into separate /bin/sh -c invocations, so inline
# multi-line if/fi or heredoc blocks do not survive intact.
set -euo pipefail

APK="build/app/outputs/flutter-apk/app-release.apk"
PACKAGE="com.waffra.app"
test -s "$APK"
adb install -r "$APK"

# Check the exact Firebase-registered package. Android 15 may omit freshly
# installed apps from "pm list packages -3"; do not use that as launch proof.
if ! adb shell pm path "$PACKAGE" | tr -d '\r' | grep -q '^package:'; then
  echo "::error::Expected Waffra package is not installed: $PACKAGE"
  adb shell pm list packages -u | grep -i waffra || true
  adb shell dumpsys package "$PACKAGE" | head -60 || true
  exit 1
fi

adb logcat -c
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1
sleep 18
adb shell pidof "$PACKAGE" || { adb logcat -d -t 350; exit 1; }
adb shell uiautomator dump /sdcard/waffra-ui.xml || true
adb pull /sdcard/waffra-ui.xml /tmp/waffra-ui.xml || true

if [ -f /tmp/waffra-ui.xml ]; then
  if grep -qE 'تعذر تشغيل وفرة|نسخ تفاصيل الخطأ|Retry' /tmp/waffra-ui.xml; then
    echo "::error::Startup error UI detected"
    adb logcat -d -t 350
    exit 1
  fi
fi

if adb logcat -d -t 2000 | grep -E 'NoSuchMethodError.*SharedPreferences|FATAL EXCEPTION|Waffra startup failed:'; then
  echo "::error::Release startup error detected in Android logs"
  exit 1
fi

echo "Release app launched without detected startup exception"
