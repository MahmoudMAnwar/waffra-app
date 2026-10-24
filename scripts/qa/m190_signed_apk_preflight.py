#!/usr/bin/env python3
"""M190: read-only signed APK preflight; NEVER a Play or SQLCipher GO decision.

Only independently pinned SHA-256 hashes and a verified APK signature are
accepted. Does not touch devices, source markers, Firebase or private keys.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile
from typing import Callable

PACKAGE = "com.waffra.app"
MAX_APK_BYTES = 200 * 1024 * 1024
HEX_64 = re.compile(r"^[a-f0-9]{64}$")
CERT_LINE = re.compile(
    r"^Signer #([0-9]+) certificate SHA-256 digest:\s*([a-fA-F0-9:]+)\s*$",
    re.MULTILINE,
)
PACKAGE_LINE = re.compile(
    r"^package:\s+name='([^']+)'\s+versionCode='([0-9]+)'",
    re.MULTILINE,
)


class SignedApkPreflightRefused(RuntimeError):
    pass


def normalize_pin(value: str) -> str:
    pin = value.lower().replace(":", "").strip()
    if not HEX_64.fullmatch(pin):
        raise SignedApkPreflightRefused("Independent SHA-256 pin is invalid.")
    return pin


def run_tool(argv: list[str]) -> str:
    try:
        done = subprocess.run(
            argv, check=True, capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        # Never echo arbitrary tool stderr or filesystem paths.
        raise SignedApkPreflightRefused("Android SDK signature/package tool failed.") from None
    return done.stdout + "\n" + done.stderr


def attest(
    apk: Path,
    *,
    expected_apk_sha256: str,
    expected_cert_sha256: str,
    command: Callable[[list[str]], str] = run_tool,
) -> dict[str, object]:
    expected_apk = normalize_pin(expected_apk_sha256)
    expected_cert = normalize_pin(expected_cert_sha256)
    if apk.is_symlink() or not apk.is_file():
        raise SignedApkPreflightRefused("APK must be an existing regular file, not a symlink.")
    size = apk.stat().st_size
    if size < 100 or size > MAX_APK_BYTES or not zipfile.is_zipfile(apk):
        raise SignedApkPreflightRefused("APK size or ZIP container is invalid.")

    h = hashlib.sha256()
    with apk.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            h.update(block)
    apk_sha = h.hexdigest()
    if apk_sha != expected_apk:
        raise SignedApkPreflightRefused("APK differs from independently pinned build SHA-256.")

    signature = command(["apksigner", "verify", "--verbose", "--print-certs", str(apk)])
    if re.search(r"CN\s*=\s*Android Debug", signature, re.IGNORECASE):
        raise SignedApkPreflightRefused("Android debug certificate is not a release signer.")
    matches = CERT_LINE.findall(signature)
    if len(matches) != 1 or matches[0][0] != "1":
        raise SignedApkPreflightRefused("Exactly one APK signing certificate is required.")
    cert_sha = normalize_pin(matches[0][1])
    if cert_sha != expected_cert:
        raise SignedApkPreflightRefused("Signer certificate differs from independently pinned release signer.")
    # v1-only/JAR signatures are insufficient for this release gate.
    if not re.search(
        r"Verified using v(?:2|3) scheme[^:\n]*:\s*true\b",
        signature, re.IGNORECASE,
    ):
        raise SignedApkPreflightRefused("APK v2/v3 signature verification is required.")

    badging = command(["aapt", "dump", "badging", str(apk)])
    package = PACKAGE_LINE.search(badging)
    if package is None or package.group(1) != PACKAGE:
        raise SignedApkPreflightRefused("Reviewed APK package identity does not match Waffra.")
    if int(package.group(2)) < 1:
        raise SignedApkPreflightRefused("APK versionCode must be positive.")

    return {
        "milestone": "M190",
        "apk_sha256": apk_sha,
        "certificate_sha256": cert_sha,
        "package": PACKAGE,
        "version_code": int(package.group(2)),
        "apk_size_bytes": size,
        "apk_signature_preflight_passed": True,
        "physical_android_devices_verified": False,
        "device_installed_apk_byte_identity_verified": False,
        "cross_device_encrypted_restore_verified": False,
        "live_finance_routes_24_of_24_verified": False,
        "production_sqlcipher_cutover_permitted": False,
        "google_play_publication_permitted": False,
        "status": "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--expected-apk-sha256", required=True)
    parser.add_argument("--expected-cert-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = attest(
            args.apk,
            expected_apk_sha256=args.expected_apk_sha256,
            expected_cert_sha256=args.expected_cert_sha256,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as out:
            os.chmod(args.output, 0o600)
            json.dump(report, out, indent=2)
            out.write("\n")
        print("M190 signed APK preflight passed; release remains NO-GO.")
        return 0
    except (SignedApkPreflightRefused, FileExistsError) as exc:
        print("M190 BLOCKED: " + str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
