#!/bin/sh
# The Android emulator action launches each YAML script line in a fresh shell.
# Keep all dependent commands in one POSIX shell process so PACKAGE survives.
set -eu
PACKAGE=com.waffra.app
adb install -r build/app/outputs/flutter-apk/app-release.apk
sh scripts/verify_android_emulator_package.sh "$PACKAGE"
adb logcat -c
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1
sleep 18
if ! adb shell pidof "$PACKAGE"; then
  echo "Waffra process exited during startup" >&2
  adb logcat -d -t 350
  exit 1
fi
adb shell uiautomator dump /sdcard/waffra-ui.xml || true
adb pull /sdcard/waffra-ui.xml /tmp/waffra-ui.xml || true
if [ -f /tmp/waffra-ui.xml ]; then
  if grep -qE 'تعذر تشغيل وفرة|نسخ تفاصيل الخطأ|Retry' /tmp/waffra-ui.xml; then
    echo "Startup error UI detected" >&2
    adb logcat -d -t 350
    exit 1
  fi
fi
# A live process is not enough: JNI/plugin exceptions may leave an error UI.
if adb logcat -d -t 2000 | grep -Ei 'Failed to load dynamic library.*libdartjni\.so|libdartjni\.so.*(cannot|failed|not found)|dlopen failed.*dartjni|UnsatisfiedLinkError|NoSuchMethodError.*SharedPreferences|FATAL EXCEPTION|Waffra startup failed:'; then
  echo "Release startup error detected in Android logs" >&2
  exit 1
fi
echo "Release app launched without detected startup exception"
