#!/usr/bin/env python3
"""M256: compare one locally pinned signed APK with two read-only ADB hashes.

This is preliminary LOCAL observation, never physical attestation, provenance
of the source commit, finance recovery, release authorization or an APK build.
Runs only on a trusted private Linux/WSL test workstation with user permission.
No app installation, file pull, device mutation, raw serial logging or data read.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
from typing import Callable

from m189_physical_device_source_probe import (
    PACKAGE, ROUTE_SOURCE, HardwareEvidenceRefused, capture,
    connected_devices, routes_from_repo, run_adb,
)
from m190_signed_apk_preflight import (
    SignedApkPreflightRefused, attest, normalize_pin,
)
from m254_physical_release_evidence_review import (
    EvidenceRefused, _write_private_report, inspect,
)

Command = Callable[[list[str]], str]
ApkAttester = Callable[..., dict[str, object]]

# The Android package manager may report /data/app/~~xyz/package-xyz==/base.apk.
# Restrict everything used in adb shell to inert characters before execution.
_SAFE_APK_PATH = re.compile(r"^/data/app/[A-Za-z0-9_./~+=-]{2,1000}/base\.apk$")
_SHA_LINE = re.compile(r"^([0-9a-fA-F]{64})[ \t]+\*?([^\r\n]+)$")


class DevicePackageRefused(RuntimeError):
    pass


def _base_apk_path(serial: str, command: Command) -> str:
    output = command(["-s", serial, "shell", "pm", "path", PACKAGE])
    lines = output.splitlines()
    if len(lines) != 1 or not lines[0].startswith("package:"):
        raise DevicePackageRefused(
            "Installed package is missing or split into multiple APK files.")
    path = lines[0][len("package:"):]
    if (len(path) > 1024 or not _SAFE_APK_PATH.fullmatch(path) or
            "//" in path or any(part in (".", "..") for part in path.split("/"))):
        raise DevicePackageRefused("Unsafe or unexpected installed APK path.")
    return path


def installed_sha256(serial: str, command: Command) -> str:
    path = _base_apk_path(serial, command)
    raw = command(["-s", serial, "shell", "sha256sum", path])
    lines = raw.splitlines()
    if len(lines) != 1:
        raise DevicePackageRefused("Device APK checksum response is unavailable.")
    match = _SHA_LINE.fullmatch(lines[0])
    if match is None or match.group(2) != path:
        raise DevicePackageRefused("Device APK checksum response is ambiguous.")
    if _base_apk_path(serial, command) != path:
        raise DevicePackageRefused("Installed APK changed during the read.")
    return match.group(1).lower()


def review(
    apk: Path,
    *,
    expected_apk_sha256: str,
    expected_cert_sha256: str,
    reviewed_commit_sha: str,
    command: Command = run_adb,
    apk_attester: ApkAttester = attest,
) -> dict[str, object]:
    # Check source format and pins, but DO NOT infer binary-to-source identity.
    if not re.fullmatch(r"[a-f0-9]{40}", reviewed_commit_sha):
        raise DevicePackageRefused("Review target must be an exact git SHA.")
    expected_apk = normalize_pin(expected_apk_sha256)
    expected_cert = normalize_pin(expected_cert_sha256)
    signed = apk_attester(
        apk,
        expected_apk_sha256=expected_apk,
        expected_cert_sha256=expected_cert,
    )
    if (signed.get("apk_sha256") != expected_apk or
            signed.get("certificate_sha256") != expected_cert):
        raise DevicePackageRefused("Local signed APK pin was not verified.")

    # Both checks are observational and can be spoofed by an untrusted ADB.
    first = connected_devices(command)
    physical = capture(command=command)
    second = connected_devices(command)
    if first != second:
        raise DevicePackageRefused("Connected Android devices changed.")

    routes = routes_from_repo(ROUTE_SOURCE.read_text(encoding="utf-8"))
    consistency = inspect(
        physical, signed, source_sha=reviewed_commit_sha,
        expected_routes=routes,
    )
    if consistency["source_cutover_authorized"] is not False:
        raise DevicePackageRefused("Unsafe evidence review outcome.")

    for serial in first:
        if installed_sha256(serial, command) != expected_apk:
            raise DevicePackageRefused(
                "Installed APK differs from the independently pinned binary.")

    if connected_devices(command) != first:
        raise DevicePackageRefused("Connected Android devices changed.")

    # Deliberately *not* an independent physical-device witness or release GO.
    # A debug bridge/mock/device can report arbitrary hashes. A human must
    # independently verify the installation, source provenance and runtime.
    return {
        "milestone": "M256",
        "reviewed_source_commit_claim_only": reviewed_commit_sha,
        "local_signed_apk_sha256": expected_apk,
        "local_signing_certificate_sha256": expected_cert,
        "connected_device_count_observed_via_adb": 2,
        "local_adb_installed_apk_hash_match_observed": True,
        "independent_installed_binary_attestation": False,
        "source_commit_bound_to_signed_binary": False,
        "os_keystore_recovery_attested": False,
        "cross_device_restore_attested": False,
        "all_24_live_finance_routes_attested": False,
        "production_sqlcipher_cutover_permitted": False,
        "apk_release_permitted": False,
        "human_release_approved": False,
        "status": "LOCAL_ADB_HASH_OBSERVATION_ONLY_RELEASE_NO_GO",
        "blockers": consistency["blockers"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--expected-apk-sha256", required=True)
    parser.add_argument("--expected-cert-sha256", required=True)
    parser.add_argument("--reviewed-commit-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = review(
            args.apk,
            expected_apk_sha256=args.expected_apk_sha256,
            expected_cert_sha256=args.expected_cert_sha256,
            reviewed_commit_sha=args.reviewed_commit_sha,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        _write_private_report(args.output, result)
        print("M256 local APK hashes observed; production release remains NO-GO.")
        return 0
    except (HardwareEvidenceRefused, SignedApkPreflightRefused,
            EvidenceRefused, DevicePackageRefused, OSError, ValueError):
        # Keep raw ADB stderr, paths, and identifiers out of logs.
        print("M256 BLOCKED: private signing/device evidence incomplete or unsafe.")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
