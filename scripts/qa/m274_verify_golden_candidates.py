#!/usr/bin/env python3
"""Validate candidate pixel images, recording exact-file SHA-256 for review.

This is an integrity check, NOT approval that a screenshot looks correct.
Once baselines are explicitly approved/committed, Flutter golden matching
becomes the actual pixel-diff regression gate.
"""
from __future__ import annotations

import hashlib
import json
import os
import struct
from pathlib import Path

root = Path("tool/goldens/baselines")
expected = [
    f"m274-footer-{lang}-{theme}.png"
    for lang in ("ar", "en")
    for theme in ("light", "dark")
] + [
    f"m274-balance-ar-{theme}.png" for theme in ("light", "dark")
]

results = []
for filename in expected:
    file = root / filename
    if not file.is_file():
        raise SystemExit(f"M274 BLOCKED: missing screenshot {file}")
    data = file.read_bytes()
    if len(data) < 150 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit(f"M274 BLOCKED: not a rendered PNG {file}")
    if data[12:16] != b"IHDR":
        raise SystemExit(f"M274 BLOCKED: invalid PNG header {file}")
    width, height = struct.unpack(">II", data[16:24])
    if width < 50 or height < 30:
        raise SystemExit(f"M274 BLOCKED: implausible image size {file}")
    results.append({
        "name": filename,
        "width": width,
        "height": height,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    })

Path("build").mkdir(exist_ok=True)
receipt = {
    "milestone": "M274",
    "source_sha": os.getenv("GITHUB_SHA", ""),
    "screenshot_status": "CANDIDATES_NEED_HUMAN_DESIGN_APPROVAL",
    "images": results,
    "real_device_full_app_qa": False,
}
Path("build/m274-golden-candidate-receipt.json").write_text(
    json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
)
print(f"PASS: {len(results)} rendered PNGs and integrity hashes recorded")
print("NOT APPROVED: pixel baselines must be reviewed before release gating.")
