#!/bin/sh
# Verify the installed Firebase-registered Waffra package before launch.
# Avoid pm list packages -3, which can be stale immediately after adb install.
set -eu
PACKAGE="$1"
if [ "$PACKAGE" != "com.waffra.app" ]; then
  echo "Unexpected Android package identity; expected com.waffra.app" >&2
  exit 1
fi
attempt=1
while [ "$attempt" -le 10 ]; do
  if adb shell pm path "$PACKAGE" | tr -d '\r' | grep -q '^package:'; then
    echo "Verified installed Android package: $PACKAGE"
    exit 0
  fi
  if [ "$attempt" -lt 10 ]; then sleep 2; fi
  attempt=$((attempt + 1))
done
echo "Installed APK was not registered as $PACKAGE after 10 checks" >&2
adb shell pm list packages | grep 'waffra' || true
exit 1
