#!/usr/bin/env python3
"""M267: two-device exact signed QA APK identity check; NEVER finance release.

Run on an operator's PRIVATE workstation with two real authorized Androids.
ADB reads installed package APKs only, not app data, notes, logs, or keys.
The result always records ZERO witnessed finance routes and release NO-GO.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path
from typing import Callable

import m189_physical_device_source_probe as hardware

PKG = "com.waffra.app"
IDENTITY_ASSET = "assets/waffra-build-identity.json"
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
CERT_LINE = re.compile(
    r"^Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]{64,95})\s*$",
    re.MULTILINE,
)
AAPT_PKG = re.compile(r"^package:\s+name='([^']+)'", re.MULTILINE)
PACKAGE_PATH = re.compile(r"^package:(/data/app/[^\r\n]+/base\.apk)$")


class IdentityRefused(RuntimeError):
    pass


def local_tool(argv: list[str]) -> str:
    try:
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=40, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as ex:
        raise IdentityRefused("Required Android signing/manifest tool unavailable.") from ex
    if result.returncode:
        raise IdentityRefused("Android signing/manifest verification failed.")
    return result.stdout + "\n" + result.stderr


def pull_package(serial: str, remote_path: str, dest: Path) -> None:
    try:
        result = subprocess.run(
            ["adb", "-s", serial, "pull", remote_path, str(dest)],
            capture_output=True, text=True, timeout=120, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as ex:
        raise IdentityRefused("Could not read installed APK from physical phone.") from ex
    if result.returncode or not dest.is_file():
        raise IdentityRefused("Installed APK copy unavailable; no identity evidence.")


def read_receipt(receipt: Path, expected: dict[str, str]) -> None:
    try:
        lines = receipt.read_text(encoding="utf-8-sig").splitlines()
    except OSError as ex:
        raise IdentityRefused("Exact-source release receipt missing.") from ex
    for key, value in expected.items():
        observed = [line[len(key) + 2:] for line in lines
                    if line.startswith(key + ": ")]
        if observed != [value]:
            raise IdentityRefused("Release receipt missing/mismatched field: " + key)


def verify_local_apk(
    apk: Path, receipt: Path, main_sha: str, trusted_signer: str,
    *, tool: Callable[[list[str]], str] = local_tool,
) -> dict[str, str]:
    if not HEX40.fullmatch(main_sha):
        raise IdentityRefused("Expected main SHA must be 40 lowercase hex digits.")
    trusted = trusted_signer.replace(":", "").lower()
    if not HEX64.fullmatch(trusted):
        raise IdentityRefused("Require independent trusted SHA-256 signing certificate.")
    try:
        with zipfile.ZipFile(apk) as z:
            if z.testzip() is not None:
                raise IdentityRefused("APK archive integrity failed.")
            raw = z.read(IDENTITY_ASSET)
        identity = json.loads(raw)
    except (OSError, zipfile.BadZipFile, KeyError, ValueError) as ex:
        raise IdentityRefused("APK embedded build identity is absent/invalid.") from ex
    if not isinstance(identity, dict):
        raise IdentityRefused("APK identity schema invalid.")
    if (identity.get("commit_sha") != main_sha or
        identity.get("branch") != "main" or
        identity.get("build_type") != "qa-android-arm64" or
        not str(identity.get("workflow_run", "")).isdigit()):
        raise IdentityRefused("APK does not identify exact signed main QA source.")
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    read_receipt(receipt, {
        "Source commit": main_sha,
        "Source branch": "main",
        "GitHub Actions run": str(identity["workflow_run"]),
        "APK sha256": digest,
    })
    signatures = tool(["apksigner", "verify", "--verbose", "--print-certs", str(apk)])
    matches = CERT_LINE.findall(signatures)
    if len(matches) != 1 or matches[0].replace(":", "").lower() != trusted:
        raise IdentityRefused("APK signer differs from independent trusted release signer.")
    if not ("Verified using v2 scheme (APK Signature Scheme v2): true"
            in signatures or
            "Verified using v3 scheme (APK Signature Scheme v3): true" in signatures):
        raise IdentityRefused("APK v2/v3 cryptographic signature not verified.")
    manifest = tool(["aapt", "dump", "badging", str(apk)])
    package_match = AAPT_PKG.search(manifest)
    if not package_match or package_match.group(1) != PKG:
        raise IdentityRefused("APK manifest package mismatch.")
    return {
        "main_sha": main_sha,
        "apk_sha256": digest,
        "signer_sha256": trusted,
        "workflow_run": str(identity["workflow_run"]),
    }


def capture(
    apk: Path, receipt: Path, main_sha: str, trusted_signer: str,
    *,
    command: Callable[[list[str]], str] = hardware.run_adb,
    tool: Callable[[list[str]], str] = local_tool,
    copier: Callable[[str, str, Path], None] = pull_package,
) -> dict[str, object]:
    verified = verify_local_apk(apk, receipt, main_sha, trusted_signer, tool=tool)
    # M189 strictly rejects virtual hardware, duplicates and missing installs.
    physical = hardware.capture(command=command)
    devices = hardware.connected_devices(command)
    apk_hash = verified["apk_sha256"]
    checked = []
    with tempfile.TemporaryDirectory(prefix="waffra-m267-private-apk-") as root:
        for index, serial in enumerate(devices):
            response = command(["-s", serial, "shell", "pm", "path", PKG])
            rows = response.strip().splitlines()
            if len(rows) != 1:
                raise IdentityRefused("Split or missing installed APK cannot be attested.")
            match = PACKAGE_PATH.fullmatch(rows[0].strip())
            if not match or ".." in match.group(1):
                raise IdentityRefused("Invalid installed APK path.")
            target = Path(root) / ("installed-" + str(index) + ".apk")
            copier(serial, match.group(1), target)
            if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != apk_hash:
                raise IdentityRefused("Installed APK does not match independently signed QA APK.")
            checked.append({
                "device_token": physical["devices"][index]["device_token"],
                "same_signed_apk_bytes": True,
                "sdk": physical["devices"][index]["sdk"],
            })
    return {
        "milestone": "M267",
        **verified,
        "hardware_detected": 2,
        "devices": checked,
        "physical_apk_identity_matched": True,
        "live_finance_route_witnesses": [],
        "source_backed_24_routes_attested": False,
        "two_phone_sqlcipher_restore_attested": False,
        "os_key_recovery_attested": False,
        "human_production_approval": False,
        "production_sqlcipher_activated": False,
        "production_release_allowed": False,
        "status": "TWO_PHYSICAL_SIGNED_APK_IDENTITY_ONLY_SQLCIPHER_NO_GO",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--main-sha", required=True)
    parser.add_argument("--trusted-signer-sha256", required=True,
                        help="Obtain independently from the known release certificate")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.output.exists():
            raise IdentityRefused("Never overwrite an existing witness file.")
        report = capture(args.apk, args.receipt, args.main_sha,
                         args.trusted_signer_sha256)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            args.output.chmod(0o600)
            json.dump(report, stream, indent=2)
            stream.write("\n")
        print("M267 two physical APK byte identities match; finance release remains NO-GO.")
        return 0
    except (IdentityRefused, hardware.HardwareEvidenceRefused) as exc:
        print("M267 BLOCKED: " + str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
