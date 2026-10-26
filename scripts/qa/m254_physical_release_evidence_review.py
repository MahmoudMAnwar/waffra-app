#!/usr/bin/env python3
"""M254: compare PRIVATE M189/M190 reports without granting SQLCipher release.

This is an offline report consistency check, NOT independent proof that either
report came from real hardware or that the signed APK corresponds to a git SHA.
Only an independently witnessed on-device recovery trial can supply that proof.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import stat

from m189_physical_device_source_probe import ROUTE_SOURCE, routes_from_repo

PIN = re.compile(r"^[a-f0-9]{64}$")
COMMIT = re.compile(r"^[a-f0-9]{40}$")
BLOCKERS = (
    "signed_apk_binary_not_proven_installed_on_both_devices",
    "signed_apk_not_independently_bound_to_reviewed_source_commit",
    "live_os_keystore_key_recovery_not_witnessed",
    "encrypted_cold_reopen_after_process_kill_not_witnessed",
    "two_physical_devices_offline_restore_not_witnessed",
    "receipt_byte_parity_and_rollback_not_witnessed",
    "home_widget_concurrent_writer_lock_not_witnessed",
    "all_24_live_finance_routes_not_witnessed",
    "legacy_migration_parity_not_witnessed",
    "active_source_restore_provenance_not_witnessed",
    "privacy_deletion_and_crash_consent_not_reviewed",
    "explicit_human_release_authorization_missing",
)


class EvidenceRefused(RuntimeError):
    pass


def _pin(value: object) -> bool:
    return isinstance(value, str) and PIN.fullmatch(value) is not None


def _required_false(report: dict, names: tuple[str, ...]) -> None:
    if any(report.get(name) is not False for name in names):
        raise EvidenceRefused("Input report falsely asserts an independent release witness.")


def inspect(physical: object, apk: object, *, source_sha: str,
            expected_routes: tuple[str, ...]) -> dict[str, object]:
    if not COMMIT.fullmatch(source_sha):
        raise EvidenceRefused("Exact reviewed git commit SHA must be a 40-digit lowercase hex.")
    if not isinstance(physical, dict) or not isinstance(apk, dict):
        raise EvidenceRefused("Both evidence reports must be JSON objects.")
    if physical.get("milestone") != "M189" or physical.get("status") != (
        "PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO"
    ):
        raise EvidenceRefused("Physical hardware collector result is not a valid M189 report.")
    devices = physical.get("devices")
    if (physical.get("hardware_detected") != 2 or
            not isinstance(devices, list) or len(devices) != 2):
        raise EvidenceRefused("Evidence requires exactly two distinct physical Android devices.")
    if len(expected_routes) != 24 or physical.get("route_inventory") != list(expected_routes):
        raise EvidenceRefused("M189 report disagrees with the canonical 24-route inventory.")
    if physical.get("route_execution_witnesses") != []:
        raise EvidenceRefused("M189 collector must not claim live route execution evidence.")
    _required_false(physical, (
        "os_backed_key_recovery_attested",
        "backup_restore_across_two_real_devices_attested",
        "encrypted_receipt_byte_parity_attested",
        "signed_release_apk_attested",
        "source_cutover_attested",
        "privacy_and_account_deletion_attested",
        "human_release_approval",
        "store_publication_permitted",
    ))
    tokens = set()
    for d in devices:
        if not isinstance(d, dict):
            raise EvidenceRefused("Malformed device record.")
        token = d.get("device_token")
        if (not _pin(token) or not _pin(d.get("build_fingerprint_token")) or
                d.get("package_present") is not True or
                d.get("qemu_getprop") != "0_or_unset" or
                d.get("device_read_only") is not True or
                type(d.get("sdk")) is not int or d["sdk"] < 30):
            raise EvidenceRefused("Missing or unsafe hardware presence metadata.")
        tokens.add(token)
    if len(tokens) != 2:
        raise EvidenceRefused("Device identifiers collide: no independent second phone.")

    if apk.get("milestone") != "M190" or apk.get("status") != (
        "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO"
    ):
        raise EvidenceRefused("Signed package review is not a valid M190 result.")
    if (apk.get("apk_signature_preflight_passed") is not True or
            apk.get("package") != "com.waffra.app" or
            not _pin(apk.get("apk_sha256")) or
            not _pin(apk.get("certificate_sha256")) or
            type(apk.get("version_code")) is not int or
            apk["version_code"] < 1):
        raise EvidenceRefused("Signed APK pin/package review is missing.")
    _required_false(apk, (
        "physical_android_devices_verified",
        "device_installed_apk_byte_identity_verified",
        "cross_device_encrypted_restore_verified",
        "live_finance_routes_24_of_24_verified",
        "production_sqlcipher_cutover_permitted",
        "google_play_publication_permitted",
    ))
    # These reports are evidence of *presence* and *local signer check* only.
    # No combination of booleans, including synthetic test data, permits GO.
    return {
        "milestone": "M254",
        "reviewed_commit_sha_claimed_not_device_proven": source_sha,
        "local_apk_sha256_checked_by_m190": apk["apk_sha256"],
        "local_signing_certificate_sha256_checked_by_m190": apk["certificate_sha256"],
        "physical_device_presence_records": 2,
        "required_routes": 24,
        "report_consistency_passed": True,
        "physical_runtime_route_attestation": False,
        "source_cutover_authorized": False,
        "release_apk_authorized": False,
        "google_play_publication_permitted": False,
        "blockers": list(BLOCKERS),
        "status": "REPORTS_CONSISTENT_BUT_PRODUCTION_RELEASE_NO_GO",
    }


def _unique_items(pairs: list[tuple[str, object]]) -> dict:
    doc = {}
    for k, v in pairs:
        if k in doc:
            raise EvidenceRefused("Duplicate JSON keys are forbidden in security evidence.")
        doc[k] = v
    return doc


def _load_private_report(path: Path) -> object:
    # Check the opened file descriptor, not the path, to avoid a symlink
    # substitution between a path check and the eventual read.
    if not hasattr(os, "O_NOFOLLOW"):
        raise EvidenceRefused("Secure no-follow local evidence reading unavailable.")
    flags = os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0)
    # Never echo raw contents, filenames, identities or financial data.
    with os.fdopen(os.open(path, flags), "r", encoding="utf-8") as f:
        info = os.fstat(f.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or
                info.st_size > 1024 * 1024 or info.st_mode & 0o077 or
                (hasattr(os, "getuid") and info.st_uid != os.getuid())):
            raise EvidenceRefused(
                "Evidence must be one owner-private regular file (max 1 MiB).")
        return json.load(f, object_pairs_hook=_unique_items)


def _write_private_report(path: Path, report: dict[str, object]) -> None:
    if not hasattr(os, "O_NOFOLLOW"):
        raise EvidenceRefused("Secure exclusive local evidence writing unavailable.")
    flags = (os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW |
             getattr(os, "O_CLOEXEC", 0))
    # 0600 at creation time: never briefly expose sensitive local report bytes.
    with os.fdopen(os.open(path, flags, 0o600), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
        f.write("\n")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--physical-report", type=Path, required=True)
    p.add_argument("--signed-apk-report", type=Path, required=True)
    p.add_argument("--expected-commit-sha", required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    try:
        report = inspect(
            _load_private_report(args.physical_report),
            _load_private_report(args.signed_apk_report),
            source_sha=args.expected_commit_sha,
            expected_routes=routes_from_repo(ROUTE_SOURCE.read_text(encoding="utf-8")),
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        _write_private_report(args.output, report)
        print("M254 local evidence reports consistent; real-phone SQLCipher release remains NO-GO.")
        return 0
    except (EvidenceRefused, OSError, ValueError, FileExistsError) as exc:
        if isinstance(exc, EvidenceRefused):
            print("M254 BLOCKED: " + str(exc))
        else:
            print("M254 BLOCKED: evidence files could not be validated.")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
