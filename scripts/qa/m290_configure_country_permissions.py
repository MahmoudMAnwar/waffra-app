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

def apply_manifest(manifest: Path) -> None:
    if not manifest.is_file():
        raise FileNotFoundError(f"Generated manifest missing: {manifest}")
    xml = manifest.read_text(encoding="utf-8")
    if "<manifest" not in xml or "<application" not in xml:
        raise ValueError("Not a generated Android application manifest")
    if PERMISSION not in xml:
        xml = xml.replace("<application", f"    {PERMISSION}\n    <application", 1)
    manifest.write_text(xml, encoding="utf-8")
    if xml.count(PERMISSION) != 1:
        raise AssertionError("COARSE location permission not unique")
    for disallowed in (
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
        'android.permission.READ_SMS',
        'android.permission.RECEIVE_SMS',
    ):
        if disallowed in xml:
            raise AssertionError("Unexpected prohibited permission in app manifest")


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    apply_manifest(root / "android/app/src/main/AndroidManifest.xml")
    print("Verified optional ACCESS_COARSE_LOCATION; no precise/background/SMS.")
