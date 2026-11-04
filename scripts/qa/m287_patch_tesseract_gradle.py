#!/usr/bin/env python3
"""Fail-closed CI compatibility shim for flutter_tesseract_ocr 0.4.31.

The published Android Gradle file still contains a legacy buildscript/
jcenter() block which fails evaluation under newer Gradle. Remove ONLY
that obsolete block from the disposable pub cache after 'flutter pub get'.
Never change financial code, SDK permissions, or OCR behaviour.
"""
from __future__ import annotations
import os
from pathlib import Path
import re
import sys

cache = Path(os.environ.get("PUB_CACHE") or Path.home() / ".pub-cache")
gradle = cache / "hosted" / "pub.dev" / "flutter_tesseract_ocr-0.4.31" / "android" / "build.gradle"
if not gradle.is_file():
    raise SystemExit(f"OCR build blocked: expected pinned Tesseract Gradle file absent: {gradle}")
source = gradle.read_text(encoding="utf-8")
if "jcenter()" not in source:
    print("PASS: Tesseract Gradle has no legacy jcenter() (already compatible)")
    sys.exit(0)
match = re.search(r"(?ms)^buildscript\s*\{\s*\n.*?^\}\s*\n", source)
if match is None or "jcenter()" not in match.group(0):
    raise SystemExit("OCR build blocked: unexpected Tesseract Gradle layout; refusing blind patch")
updated = source[:match.start()] + source[match.end():]
if "jcenter()" in updated or updated == source:
    raise SystemExit("OCR build blocked: deprecated Gradle repository remains")
gradle.write_text(updated, encoding="utf-8")
print("PASS: Removed obsolete Tesseract buildscript from disposable pub cache")
