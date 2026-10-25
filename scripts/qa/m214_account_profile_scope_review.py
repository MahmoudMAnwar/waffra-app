#!/usr/bin/env python3
"""M214: exact-SHA private-profile encrypted candidate staging QA, NO-GO."""
import json
import os
import subprocess
from pathlib import Path

APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m214-encrypted-account-profile-staging.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_encrypted_account_profile_stager.dart",
    "scripts/qa/m214_account_profile_scope_review.py",
    "test/storage/m214_encrypted_account_profile_staging_test.dart",
}

def git(*args):
    return subprocess.run(["git",*args],check=True,text=True,
                          capture_output=True).stdout.strip()

def require(condition,reason):
    if not condition:
        raise SystemExit("M214 BLOCKED: "+reason)

def source(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head=git("rev-parse","HEAD")
    base=git("rev-parse","refs/remotes/origin/main")
    require(head==os.environ.get("REVIEW_HEAD_SHA","").strip(),
            "review HEAD differs from checkout")
    require(git("merge-base",base,head)==base,
            "main changed; review on new base")
    changes=set(filter(None,git("diff","--name-only",base,head).splitlines()))
    require(changes==APPROVED,
            "scope mismatch: "+repr(sorted(changes ^ APPROVED)))
    stager=source("lib/storage/waffra_encrypted_account_profile_stager.dart")
    test=source("test/storage/m214_encrypted_account_profile_staging_test.dart")
    workflow=source(".github/workflows/m147-final-main-review-gate.yml")
    notes=source("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    guide=source("docs/qa/m214-encrypted-account-profile-staging.md")
    gate=source("lib/storage/waffra_production_cutover_release_gate.dart")
    old=source("lib/storage/waffra_home_finance_persistence.dart")

    for marker in (
        "class WaffraEncryptedAccountProfileStager",
        "legacyWriter.withCurrentPreferences(",
        "WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs)",
        "WaffraLegacyPreflight.inspect(finance)",
        "shadow_migrations",
        "preflight.sourceSha256",
        "Encrypted finance owner does not match the profile.",
        "store.transaction(() async",
        "fresh_account_profile_staging",
        "if (!experimentalEnabled)",
        "Map<String, String>.unmodifiable(captured)",
    ):
        require(marker in stager, "missing profile migration safety marker: "+marker)
    keyset=stager.split("static const Set<String> approvedProfileKeys",1)[1]
    keyset=keyset.split("};",1)[0]
    for marker in ("waffra_profile","waffra_registered_profile",
                   "waffra_last_login_email","waffra_last_login_phone"):
        require(marker in keyset,"missing reviewed user field: "+marker)
    for forbidden in ("waffra_pin_sha256","password","firebase",
                      "auth_token","waffra_language","waffra_dark_mode"):
        require(forbidden not in keyset,
                "non-finance secret/preference was added to contact table")
    for marker in (
        "M214 stage only reviewed PII fields",
        "M214 cold SQLCipher reopen",
        "M214 different customer profile cannot overwrite",
        "M214 unknown/malformed sensitive profile refuses",
        "M214 active finance source marker blocks",
        "M214 changed legacy financial owner cannot stage",
    ):
        require(marker in test,"missing staged PII safety test: "+marker)
    require("M214 SHA-pinned" in workflow and
            "m214_account_profile_scope_review.py" in workflow,
            "M147 full QA gate not connected")
    require("[24] M214" in notes,"main release notes not updated")
    require("production NO-GO" in guide and "physical" in guide and
            "PIN" in guide and "account deletion" in guide,
            "PII staging release blockers undocumented")
    require("bool get automaticallyActivateSqlCipher => false;" in gate,
            "unsafe automatic SQLCipher source switch")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in old,
            "M207 raw SMS plaintext fail-closed missing")
    output=Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True,exist_ok=True)
    result={
        "milestone":"M214",
        "reviewed_head":head,
        "base_main":base,
        "reviewed_paths":sorted(changes),
        "profile_encrypted_stage":"FLUTTER_INTEGRATION_TEST_REQUIRED",
        "profile_owner_bound_to_finance":"ENCRYPTED_WITNESS_TEST_REQUIRED",
        "auth_token_migrated":False,
        "pin_hash_migrated":False,
        "account_deletion_integrated":False,
        "physical_phones_verified":0,
        "live_sqlcipher_profile_selected":False,
        "production_status":"NO_GO"
    }
    output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))

if __name__=="__main__":
    main()
