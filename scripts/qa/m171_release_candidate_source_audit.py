#!/usr/bin/env python3
"""M171 read-only supply-chain audit of release candidate source. No signing key is read."""
from pathlib import Path

def inspect(root: Path) -> dict:
    workflow = (root / ".github/workflows/android.yml").read_text()
    pubspec = (root / "pubspec.yaml").read_text()
    checks = {
        "release_signing_uses_encrypted_secrets": all(
            ("secrets." + name) in workflow
            for name in (
                "WAFFRA_RELEASE_KEYSTORE_BASE64",
                "WAFFRA_RELEASE_STORE_PASSWORD",
                "WAFFRA_RELEASE_KEY_PASSWORD",
            )
        ),
        "no_debug_release_signing": 'signingConfigs.getByName("waffraRelease")' in workflow,
        "certificate_fingerprint_gate": "does not match the certificate registered in Firebase" in workflow,
        "firebase_package_identity": "com.waffra.app" in workflow,
        "apk_signature_is_verified": "apksigner" in workflow
                                     and "Verify final APK uses Firebase-registered" in workflow,
        "candidate_aab_built": "flutter build appbundle" in workflow,
        "api36_candidate_target": "targetSdk = 36" in workflow
                                  and "compileSdk = 36" in workflow,
        "signed_aab_integrity": 'jarsigner -verify "$bundle"' in workflow
                                and 'unzip -t "$bundle"' in workflow,
        "candidate_archive_has_sha256": "aab_candidate_sha256.txt" in workflow,
        "signed_artifacts_only_not_keystore": ("Waffra-Android-API36-AAB-Internal-Test-Candidate" in workflow
            and "path: |" in workflow and "build/app/outputs/bundle/release/app-release.aab" in workflow),
        "semver_declared": "version:" in pubspec,
        "no_play_production_publish_action": not any(
            text in workflow for text in [
                "r0adkll/upload-google-play@",
                "play-store-deploy@",
                "fastlane supply",
            ]
        ),
    }
    return {
        "milestone": "M171",
        "auditOnly": True,
        "sourceChecks": checks,
        "sourcePolicyConsistent": all(checks.values()),
        "aabSignedAndInstalledOnPhone": False,
        "readyForProduction": False,
        "blockers": [
            "same_sha_signed_aab_artifact_not_independently_verified",
            "upload_certificate_must_match_owner_play_app_signing_and_firebase_oauth",
            "version_code_uniqueness_and_play_console_status_unverified",
            "real_android_google_login_and_restore_not_certified",
            "play_internal_or_closed_test_and_owner_launch_approval_missing",
        ],
    }

if __name__ == "__main__":
    import json
    result = inspect(Path(__file__).resolve().parents[2])
    print(json.dumps(result, indent=2))
    if not result["sourcePolicyConsistent"]:
        raise SystemExit("M171 signed bundle source policy failed")
