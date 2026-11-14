#!/usr/bin/env python3
"""M936: fail-closed read-only release source inventory, NOT a release GO.

Runs in existing M550 before costly Flutter CI. Never reads phones,
private user backups, actual release signing keys, or live GitHub status.
A green source check must NEVER become proof of a signed/hardware release.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

HEX40 = re.compile(r"[0-9a-f]{40}\Z")
SOURCE_CONTRACTS = {
    "scripts/qa/m190_signed_apk_preflight.py": (
        "expected_apk_sha256", "expected_cert_sha256",
        "apksigner", "google_play_publication_permitted",
        "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO",
    ),
    "scripts/qa/m267_signed_two_phone_apk_probe.py": (
        "verify_local_apk(", "IDENTITY_ASSET",
        "read_receipt(", "IdentityRefused",
    ),
    "scripts/qa/m171_release_candidate_source_audit.py": (
        "no_play_production_publish_action",
        "release_signing_uses_encrypted_secrets",
        "readyForProduction",
    ),
    "scripts/qa/m279_app_security_gate.py": (
        "PROHIBITED_ANDROID_PERMISSIONS",
        "firestore_errors(", "manifest_permission_errors(",
    ),
    "scripts/qa/m449_release_notes_ancestry.py": (
        "inspect_release_notes(", "merge-base", "APP_PATHS",
    ),
    "docs/qa/M935_PHASE_TWO_ANDROID_ACCEPTANCE.md": (
        "Spouse device approved for update?", "Pending device evidence",
        "Financial parity before and after force-stop/relaunch",
    ),
}

# Remain NO-GO even if the entire read-only source inventory passes.
RELEASE_BLOCKERS = (
    "exact_main_signed_apk_or_aab_digest_and_trusted_signer_not_attested_here",
    "owner_authenticated_two_physical_android_installations_not_attested_here",
    "original_legacy_backup_and_post_reopen_financial_parity_not_attested_here",
    "physical_android_pdf_ux_sms_biometric_and_permissions_not_attested_here",
    "google_play_internal_test_and_owner_launch_approval_not_attested_here",
)


class ReleaseSourceRefused(ValueError):
    pass


def inspect(root: Path, source_sha: str) -> dict[str, object]:
    if HEX40.fullmatch(source_sha) is None:
        raise ReleaseSourceRefused("Exact 40-character lowercase source SHA required")
    checks: dict[str, bool] = {}
    for relative, markers in SOURCE_CONTRACTS.items():
        path = root / relative
        # The repo may contain untrusted files or symlinks: never traverse
        # symlinks or read any personal finance artifacts in this audit.
        if not path.is_file() or path.is_symlink():
            checks[relative] = False
            continue
        source = path.read_text(encoding="utf-8")
        checks[relative] = all(marker in source for marker in markers)
    return {
        "milestone": "M936",
        "source_sha": source_sha,
        "source_contract_checks": checks,
        "source_contract_passed": all(checks.values()),
        "scope": "SOURCE_ONLY_NO_ANDROID_OR_SIGNED_ARTIFACT_ATTESTATION",
        "physical_android_verified": False,
        "owner_backup_financial_parity_verified": False,
        "signed_artifact_released": False,
        "production_sqlcipher_cutover_permitted": False,
        "google_play_publication_permitted": False,
        "release_status": "NO_GO_PENDING_INDEPENDENT_OWNER_ACCEPTANCE",
        "blockers": list(RELEASE_BLOCKERS),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    try:
        result = inspect(args.root, args.source_sha)
    except (OSError, UnicodeError, ReleaseSourceRefused) as error:
        print("BLOCKED M936: " + type(error).__name__)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    # Do not confuse source-safety validity with GO for production release.
    return 0 if result["source_contract_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
