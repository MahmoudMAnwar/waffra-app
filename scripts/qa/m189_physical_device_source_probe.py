#!/usr/bin/env python3
"""M189: prove two *connected physical* Androids exist; NEVER certify finance routes.

This collects only redacted hardware and APK-presence metadata. It does NOT
synthesize any of the 24 required in-app finance, OS-key, receipt or recovery
witnesses. Any collected report remains release NO-GO for manual review.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import secrets
import subprocess
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
ROUTE_SOURCE = ROOT / "lib/storage/waffra_production_finance_routing_gate.dart"
REQUIRED_ROUTES = (
    "appStartup", "widgetStartup", "dashboardRead", "widgetRead",
    "manualTransactionSave", "bulkSmsConfirmedSave",
    "widgetSmsConfirmedSave", "transactionEdit",
    "transactionDeleteAndUndo", "deleteAllTransactions",
    "categoryCatalogInstall", "categoryCreateEditDeleteRestore",
    "goalCreateEditDeleteRestore", "recurringCreateEditDeleteRestore",
    "recurringPostingAndPostponement", "challengeAndBudgetUpdate",
    "merchantRulesAndSmsHashes", "receiptCopyAndAttach", "receiptView",
    "receiptRemoveAndRollback", "widgetBalanceRefresh", "backupExport",
    "backupRestore", "fullFinanceReset",
)
PACKAGE = "com.waffra.app"


class HardwareEvidenceRefused(RuntimeError):
    pass


def routes_from_repo(source: str) -> tuple[str, ...]:
    match = re.search(r"enum\s+WaffraFinanceRoute\s*\{([^}]*)\}", source, re.S)
    if match is None:
        raise HardwareEvidenceRefused("Finance route contract is missing.")
    names = tuple(re.findall(r"^\s*([a-zA-Z][a-zA-Z0-9]*)\s*,\s*$",
                             match.group(1), re.M))
    if len(names) != 24 or names != REQUIRED_ROUTES or len(set(names)) != 24:
        raise HardwareEvidenceRefused(
            "Route inventory changed: rerun independent security review.")
    return names


def run_adb(argv: list[str], *, timeout: int = 20) -> str:
    try:
        r = subprocess.run(
            ["adb", *argv], text=True, capture_output=True,
            timeout=timeout, check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        raise HardwareEvidenceRefused(
            "ADB unavailable or timed out; hardware proof missing.") from None
    if r.returncode != 0:
        raise HardwareEvidenceRefused(
            "ADB command failed; cannot attest Android hardware.") from None
    return r.stdout.strip()


def connected_devices(
    command: Callable[[list[str]], str] = run_adb,
) -> tuple[str, ...]:
    output = command(["devices", "-l"])
    devices = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])
    if len(devices) != 2 or len(set(devices)) != 2:
        raise HardwareEvidenceRefused(
            "Exactly two distinct online, authorized Android devices required.")
    return tuple(devices)


def probe(
    serial: str,
    command: Callable[[list[str]], str] = run_adb,
    *,
    local_nonce: str,
) -> dict[str, object]:
    if not serial or not re.fullmatch(r"[A-Za-z0-9_.:-]{3,160}", serial):
        raise HardwareEvidenceRefused("Invalid ADB device selector.")
    def prop(name: str) -> str:
        return command(["-s", serial, "shell", "getprop", name]).strip()

    emulator_flag = prop("ro.kernel.qemu")
    hardware = prop("ro.hardware").lower()
    if emulator_flag not in ("", "0") or any(
        marker in hardware for marker in ("goldfish", "ranchu", "vbox", "qemu")
    ):
        raise HardwareEvidenceRefused(
            "An emulator/virtualized Android cannot satisfy physical-device proof.")
    sdk = prop("ro.build.version.sdk")
    if not sdk.isdigit() or int(sdk) < 30:
        raise HardwareEvidenceRefused("Android hardware SDK witness missing/too old.")
    fingerprint = prop("ro.build.fingerprint")
    if len(fingerprint) < 15:
        raise HardwareEvidenceRefused("Physical device build fingerprint unavailable.")
    package = command(["-s", serial, "shell", "pm", "path", PACKAGE])
    if not package.startswith("package:"):
        raise HardwareEvidenceRefused(
            "Waffra APK is not installed on both connected phones.")
    def digest(value: str) -> str:
        return hashlib.sha256((local_nonce + "|" + value).encode()).hexdigest()
    return {
        "device_token": digest(serial),
        "build_fingerprint_token": digest(fingerprint),
        "sdk": int(sdk),
        "package_present": True,
        "qemu_getprop": "0_or_unset",
        "device_read_only": True,
        # No financial information, raw serial, OS key or image bytes exported.
    }


def capture(
    command: Callable[[list[str]], str] = run_adb,
    *,
    now: Callable[[], dt.datetime] = lambda: dt.datetime.now(dt.timezone.utc),
    nonce: Callable[[], str] = lambda: secrets.token_hex(32),
    source: str | None = None,
) -> dict[str, object]:
    names = routes_from_repo(
        source if source is not None else ROUTE_SOURCE.read_text(encoding="utf-8")
    )
    ids = connected_devices(command)
    local_nonce = nonce()
    records = [probe(serial, command, local_nonce=local_nonce) for serial in ids]
    if records[0]["device_token"] == records[1]["device_token"]:
        raise HardwareEvidenceRefused("Duplicate hardware witness.")
    return {
        "milestone": "M189",
        "at_utc": now().astimezone(dt.timezone.utc).isoformat(),
        "hardware_detected": 2,
        "devices": records,
        "route_inventory": list(names),
        "route_execution_witnesses": [],
        "os_backed_key_recovery_attested": False,
        "backup_restore_across_two_real_devices_attested": False,
        "encrypted_receipt_byte_parity_attested": False,
        "signed_release_apk_attested": False,
        "source_cutover_attested": False,
        "privacy_and_account_deletion_attested": False,
        "human_release_approval": False,
        "store_publication_permitted": False,
        "status": "PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO",
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check-contract", action="store_true",
                   help="CI-safe source-only 24-route inventory; no ADB")
    p.add_argument("--capture", action="store_true",
                   help="Read-only ADB device check; requires two real phones")
    p.add_argument("--output", type=Path, help="Private local evidence JSON")
    args = p.parse_args()
    try:
        names = routes_from_repo(ROUTE_SOURCE.read_text(encoding="utf-8"))
        if args.check_contract and not args.capture:
            print(json.dumps({
                "checked_routes": len(names),
                "release_ready": False,
                "reason": "24-route inventory is not runtime/device evidence",
                "status": "M189_STATIC_CONTRACT_ONLY_NO_GO",
            }))
            return 0
        if not args.capture or args.output is None:
            p.error("Use --check-contract or --capture --output /safe/path.json")
        output = capture()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        # Private local file, never public CI log nor APK asset.
        with args.output.open("x", encoding="utf-8") as fp:
            import os
            os.chmod(args.output, 0o600)
            json.dump(output, fp, indent=2)
            fp.write("\n")
        print("Captured two physical devices; runtime routes remain NO-GO.")
        return 0
    except (HardwareEvidenceRefused, FileExistsError) as ex:
        print("M189 BLOCKED: " + str(ex))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
