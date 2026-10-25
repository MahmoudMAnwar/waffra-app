#!/usr/bin/env python3
"""M219 SHA-pinned Android Keystore HMAC candidate integration audit."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m219-android-keystore-account-owner-proof.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_android_owner_keystore_signer.dart",
    "native/WaffraMainActivity.kt",
    "scripts/qa/m219_android_keystore_owner_scope_review.py",
    "test/storage/m219_android_owner_keystore_signer_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True, text=True,
                          capture_output=True).stdout.strip()

def require(condition, reason):
    if not condition:
        raise SystemExit("M219 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "reviewed head must be exact PR SHA")
    require(git("merge-base", base, head) == base,
            "reviewed branch does not contain latest main")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(changed == SCOPE, "unexpected scope: " +
            repr(sorted(changed ^ SCOPE)))

    native = read("native/WaffraMainActivity.kt")
    adapter = read("lib/storage/waffra_android_owner_keystore_signer.dart")
    tests = read("test/storage/m219_android_owner_keystore_signer_test.dart")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    release = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    guide = read("docs/qa/m219-android-keystore-account-owner-proof.md")
    cutover = read("lib/storage/waffra_production_cutover_release_gate.dart")
    app = read("lib/main.dart")

    for marker in (
        "private val ownerProofChannelName = \"waffra/account_owner\"",
        "private val ownerKeyAlias = \"waffra_profile_owner_hmac_v1\"",
        "private fun signExistingAccountOwnerChallenge",
        "KeyStore.getInstance(\"AndroidKeyStore\")",
        "keystore.getKey(ownerKeyAlias, null) as? SecretKey",
        "Mac.getInstance(\"HmacSHA256\")",
        "FirebaseAuth.getInstance().currentUser",
        "authenticatedUser.isAnonymous",
        "authenticatedUser.uid != ownerEnvelope.optString(3)",
        "call.argument<ByteArray>(\"challenge\")",
        "signExistingOwnerChallenge",
        "result.error(\"OWNER_PROOF_UNAVAILABLE\"",
    ):
        require(marker in native, "missing native fail-closed proof: " + marker)
    for forbidden in (
        "KeyGenerator.getInstance(",
        "KeyGenParameterSpec.Builder(",
        "setEntry(ownerKeyAlias",
        "keystore.deleteEntry(",
        "getEncoded()",
        "Log.d(\"owner",
        "Log.e(\"owner",
    ):
        require(forbidden not in native, "unsafe owner-key access: " + forbidden)
    for marker in (
        "class WaffraAndroidOwnerKeystoreSigner",
        "signExistingChallenge(List<int> challenge)",
        "Uint8List.fromList(challenge)",
        "signExistingOwnerChallenge",
        "Owner challenge is not an approved account proof.",
        "on MissingPluginException",
        "on PlatformException",
    ):
        require(marker in adapter, "missing Dart proof guard: " + marker)
    for marker in (
        "M219 verifies Android owner MAC and transmits bytes only",
        "M219 refuses missing native MethodChannel implementation",
        "M219 refuses an absent non-enrolled OS owner key",
        "M219 refuses a null or malformed native HMAC",
        "M219 blocks malformed JSON before calling the native key",
        "M219 blocks non-profile HMAC purpose without a native call",
        "M219 rejects missing UID, vault and malformed source digest",
        "M219 rejects oversized challenge and out-of-range byte",
        "M219 refuses non-canonical JSON before OS signing",
        "M219 raw owner key is never a response or protocol parameter",
    ):
        require(marker in tests, "missing negative regression test: " + marker)
    require("M219 SHA-pinned" in workflow and
            "m219_android_keystore_owner_scope_review.py" in workflow,
            "exact-head CI scope hook not installed")
    require("[29] M219" in release, "release notes not documented")
    require("production NO-GO" in guide and
            "physical Android" in guide and
            "Firebase ID-token server validation" in guide, "owner enrollment blockers absent")
    require("bool get automaticallyActivateSqlCipher => false;" in cutover,
            "cutover release gate unexpectedly changed")
    require("WaffraAndroidOwnerKeystoreSigner" not in app,
            "native proof unexpectedly turned on in live UI")

    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    proof = {
        "milestone": "M219",
        "reviewed_head": head,
        "main": base,
        "scope": sorted(changed),
        "native_owner_signer": True,
        "existing_key_required": True,
        "fresh_principal_attestation": False,
        "owner_enrollment_active": False,
        "physical_android_devices": 0,
        "release": "NO_GO",
    }
    out.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(proof))

if __name__ == "__main__":
    main()
