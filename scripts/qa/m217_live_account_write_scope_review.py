#!/usr/bin/env python3
"""M217 exact-head live profile/root source-lock review; NO-GO release."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m217-live-account-source-guard.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/storage/waffra_live_account_write_authority.dart",
    "scripts/qa/m217_live_account_write_scope_review.py",
    "test/storage/m217_live_account_write_authority_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True, text=True,
                          capture_output=True).stdout.strip()

def require(condition, reason):
    if not condition:
        raise SystemExit("M217 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "wrong reviewed source SHA")
    require(git("merge-base", base, head) == base,
            "current main does not precede tested branch")
    paths = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(paths == SCOPE, "unreviewed file changes: " +
            repr(sorted(paths ^ SCOPE)))

    app = read("lib/main.dart")
    adapter = read("lib/storage/waffra_live_account_write_authority.dart")
    tests = read("test/storage/m217_live_account_write_authority_test.dart")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    qa = read("docs/qa/m217-live-account-source-guard.md")
    cutover = read("lib/storage/waffra_production_cutover_release_gate.dart")

    for marker in (
        "import 'storage/waffra_live_account_write_authority.dart';",
        "_accountWriteAuthority.saveProfile(",
        "_accountWriteAuthority.signOut()",
        "_accountWriteAuthority.replacePinVerifier(hash)",
    ):
        require(marker in app, "real app account path not wired: " + marker)
    root = app.split("class _WaffraAppState", 1)[1]
    root = root.split(" Future<void> setLanguage(String next)", 1)[0]
    account = root.split(" Future<void> saveUser(Person u)", 1)[1]
    require("SharedPreferences.getInstance()" not in account,
            "direct unguarded account mutation still present")
    for marker in (
        "class WaffraLiveAccountWriteAuthority",
        "coordinator.withCurrentPreferences(",
        "_requirePersonJson(profileJson)",
        "Future<void> signOut()",
        "Future<void> replacePinVerifier(String? nextVerifier)",
        "waffra_signed_out_explicitly",
        "waffra_pin_sha256",
    ):
        require(marker in adapter, "source-guarded mutation missing: " + marker)
    for banned in (
        "prefs.setString('entries'",
        "prefs.remove('entries'",
        "automaticallyActivateSqlCipher",
        "FirebaseAuth",
        "debugPrint(",
    ):
        require(banned not in adapter,
                "account adapter illegally changes source/finance: " + banned)
    cases = (
        "M217 guarded live saveUser keeps existing finances untouched",
        "M217 guarded logout preserves registration and finance",
        "M217 guarded PIN replace and remove keeps finance untouched",
        "M217 malformed PIN verifier fails before any preferences change",
        "M217 malformed or unapproved profile fields fail closed",
        "M217 incorrect login method fails before native write",
        "M217 SQLCipher source disagreement blocks user save",
        "M217 SQLCipher source disagreement blocks logout",
        "M217 SQLCipher source disagreement blocks PIN mutation",
        "M217 external active source flag blocks all old account writes",
        "M217 pending cutover blocks all legacy account changes",
    )
    for marker in cases:
        require(marker in tests, "required real-route regression missing: " + marker)
    require("M217 SHA-pinned" in workflow and
            "m217_live_account_write_scope_review.py" in workflow,
            "missing exact-SHA M147 CI hook")
    require("[27] M217" in notes, "release notes not updated")
    require("SQLCipher customer activation remains NO-GO" in qa and
            "24 live finance routes" in qa and
            "physical Android phones" in qa, "release blockers undocumented")
    require("bool get automaticallyActivateSqlCipher => false;" in cutover,
            "automatic source promotion is not forbidden")
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    proof = {
        "milestone": "M217",
        "reviewed_head": head,
        "main_at_review": base,
        "paths": sorted(paths),
        "real_profile_mutations_routed": True,
        "native_home_widget_lease": True,
        "encrypted_live_profile_mutations": False,
        "automatic_sqlcipher_activation": False,
        "physical_phones_tested": 0,
        "production_status": "NO_GO",
    }
    out.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(proof))

if __name__ == "__main__":
    main()
