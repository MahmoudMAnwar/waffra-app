#!/usr/bin/env python3
"""Configure a generated Android Manifest for opt-in approximate location.

Waffra does NOT include a generated Android/ directory in source control.
The main APK workflow must run this AFTER flutter create and BEFORE Gradle.
Do not ask for FINE/BACKGROUND location or any SMS read permissions.
"""
from __future__ import annotations

import sys
from pathlib import Path

PERMISSION = (
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />'
)

def apply_manifest(manifest: Path, *, enable_global_location: bool = False) -> None:
    """Saudi build has no country-location permission; Global is explicit opt-in.

    Do not delete the dormant country-detection source. This modifies only a
    freshly generated Android manifest, not user preferences or finance data.
    """
    if not manifest.is_file():
        raise FileNotFoundError(f"Generated manifest missing: {manifest}")
    xml = manifest.read_text(encoding="utf-8")
    if "<manifest" not in xml or "<application" not in xml:
        raise ValueError("Not a generated Android application manifest")
    if enable_global_location:
        if PERMISSION not in xml:
            xml = xml.replace("<application", f"    {PERMISSION}\n    <application", 1)
        if xml.count(PERMISSION) != 1:
            raise AssertionError("Global COARSE permission must appear exactly once")
    else:
        xml = xml.replace(PERMISSION, "")
        if PERMISSION in xml:
            raise AssertionError("Saudi release must not declare country location permission")
    for disallowed in (
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
        'android.permission.READ_SMS',
        'android.permission.RECEIVE_SMS',
    ):
        if disallowed in xml:
            raise AssertionError("Unexpected prohibited permission in app manifest")
    manifest.write_text(xml, encoding="utf-8")


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    global_location = "--global-country-location" in sys.argv[2:]
    apply_manifest(root / "android/app/src/main/AndroidManifest.xml",
                   enable_global_location=global_location)
    print("Country location: " + ("Global coarse opt-in" if global_location
                                 else "disabled in Saudi edition") +
          "; no precise/background/SMS permissions.")
