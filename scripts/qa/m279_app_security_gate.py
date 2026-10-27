#!/usr/bin/env python3
"""M279 fail-closed, read-only mobile app security release guard.

Static checks complement—not replace—Flutter tests, Firestore emulator, and
signed Android/iOS device validation. No live Firebase/network access and no
finance/PIN/SMS/receipt content is printed or read from devices.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROHIBITED_ANDROID_PERMISSIONS = frozenset({
    "READ_SMS", "RECEIVE_SMS", "SEND_SMS", "READ_CALL_LOG",
    "READ_CONTACTS", "QUERY_ALL_PACKAGES", "MANAGE_EXTERNAL_STORAGE",
    "BIND_ACCESSIBILITY_SERVICE", "REQUEST_INSTALL_PACKAGES",
})
PERMISSION = re.compile(
    r"(?:android\.permission\.|android\.permission/)"
    r"([A-Z][A-Z_0-9]+)"
)
ALLOW = re.compile(
    r"\ballow\s+([A-Za-z_,\s]+)\s*:\s*if\s*"
    r"(true|request\.auth\s*!=\s*null)\s*;",
    re.IGNORECASE,
)


def uncomment(source: str) -> str:
    """Strip // and /* */ Firestore rule comments, not validation expressions."""
    return re.sub(
        r"/\*.*?\*/|//[^\n]*", "", source, flags=re.DOTALL,
    )


def firestore_errors(rules: str) -> list[str]:
    source = uncomment(rules)
    problems: list[str] = []
    if ALLOW.search(source):
        problems.append("firestore_public_or_any_signed_in_access")
    if not re.search(
        r"match\s*/\{document=\*\*\}\s*\{\s*"
        r"allow\s+read\s*,\s*write\s*:\s*if\s+false\s*;",
        source,
    ):
        problems.append("firestore_fallback_default_deny_missing")
    if not re.search(
        r"function\s+signedInAs\s*\(uid\)", source,
    ) or not re.search(r"request\.auth\.uid\s*==\s*uid", source):
        problems.append("firestore_owner_uid_verification_missing")
    if "accountDeletionRequests/$(uid)" not in source:
        problems.append("firestore_account_deletion_tombstone_missing")
    if not re.search(r"function\s+validCiphertextRecord\s*\(", source):
        problems.append("firestore_ciphertext_envelope_guard_missing")
    else:
        for marker in (
            "data.keys().hasOnly(", "data.keys().hasAll(",
            "data.ciphertext is string", "data.nonce is string",
            "data.mac is string", "data.encryptionVersion == 1",
        ):
            if marker not in source:
                problems.append("firestore_envelope_missing_" + marker.split("(")[0])
    for marker in (
        "function validRecoveryEnvelope(", "data.wrappedKey is string",
        "allow delete: if false;", "request.resource.data.localVersion ==",
    ):
        if marker not in source:
            problems.append("firestore_recovery_revision_or_delete_guard_missing")
    return problems


def manifest_permission_errors(source: str) -> list[str]:
    return sorted(
        "prohibited_android_permission_" + name
        for name in (set(PERMISSION.findall(source)) & PROHIBITED_ANDROID_PERMISSIONS)
    )


def required_markers(name: str, content: str, markers: tuple[str, ...]) -> list[str]:
    return [name + "_missing_" + str(index + 1)
            for index, marker in enumerate(markers) if marker not in content]


def audit_repo(root: Path) -> dict[str, list[str]]:
    errors: list[str] = []
    checked: list[str] = []

    def read(relative: str) -> str:
        p = root / relative
        checked.append(relative)
        if not p.is_file():
            errors.append("missing_source_" + relative)
            return ""
        return p.read_text(encoding="utf-8")

    errors.extend(firestore_errors(read("firestore.rules")))
    errors.extend(required_markers(
        "firebase_rules_emulator_config",
        read("firebase.json"),
        ('"rules": "firestore.rules"', '"firestore"'),
    ))
    errors.extend(required_markers(
        "cloud_cipher",
        read("lib/storage/waffra_cloud_cipher.dart"),
        ("AesGcm.with256bits()", "aad: _aad(", "WaffraCloudSanitizer.sanitize(",
         "throw StateError('Unapproved field in cloud financial record.')",
         "'receiptPath'"),
    ))
    errors.extend(required_markers(
        "portable_backup",
        read("lib/waffra_secure_backup.dart"),
        ("AesGcm.with256bits()", "Argon2id(",
         "Random.secure()", "password.runes.length>=12",
         "'version':2", "_cipher.decrypt(",
         "hasValidEncryptedHeader("),
    ))
    errors.extend(required_markers(
        "backup_export",
        read("lib/waffra_backup_files.dart"),
        ("isEncryptedArchive(payload)", "maxArchiveBytes",
         "saveEncryptedFile", "Only encrypted Waffra archives can be saved"),
    ))
    errors.extend(required_markers(
        "pin_device_protection_candidate",
        read("lib/storage/waffra_pin_os_secure_candidate_stager.dart"),
        ("this.experimentalEnabled = false", "FlutterSecureStorage(",
         "throw StateError('PIN secure candidate migration is disabled.')",
         "if (await readLegacyHash() != legacy)"),
    ))
    errors.extend(required_markers(
        "release_privacy",
        read("docs/release/PRODUCTION_GO_LIVE_CHECKLIST.md"),
        ("No raw SMS/receipts/balances in Crashlytics",
         "No bank-account permission", "two physical phones"),
    ))
    manifest_paths = sorted(
        set((root / "native").rglob("*.xml"))
        | set((root / "android").rglob("AndroidManifest.xml"))
        | set((root / "native").rglob("*.kt"))
    )
    if not manifest_paths:
        errors.append("native_android_sources_unavailable")
    for p in manifest_paths:
        checked.append(str(p.relative_to(root)))
        errors.extend(manifest_permission_errors(p.read_text(encoding="utf-8")))

    # The iOS Runner isn't checked into this repository yet. It is an
    # explicit release blocker, NOT a static-scanner PASS.
    limitations = [
        "iOS Runner native entitlements/ATS/keychain unavailable in repository",
        "Android merged release manifest needs post-build permission inspection",
        "Physical phone tests, runtime PIN brute force, TLS interception, "
        "SQLCipher at-rest verification and device backup are not proven",
    ]
    return {
        "errors": sorted(set(errors)),
        "checked": sorted(set(checked)),
        "limitations": limitations,
    }


def main() -> int:
    outcome = audit_repo(ROOT)
    # Output only check names and paths; never source content or secrets.
    print(json.dumps({
        "gate": "M279 app-wide security source check",
        "passed": len(outcome["errors"]) == 0,
        "checked": outcome["checked"],
        "errors": outcome["errors"],
        "not_certified": outcome["limitations"],
    }, ensure_ascii=False, indent=2))
    return 0 if not outcome["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
