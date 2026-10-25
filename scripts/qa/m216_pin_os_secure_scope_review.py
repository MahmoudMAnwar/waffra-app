#!/usr/bin/env python3
"""M216 exact-head NON-DESTRUCTIVE, disabled OS candidate PIN review."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m216-pin-os-protected-candidate-migration.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_pin_os_secure_candidate_stager.dart",
    "scripts/qa/m216_pin_os_secure_scope_review.py",
    "test/storage/m216_pin_os_secure_candidate_stage_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True,
                          text=True).stdout.strip()

def check(ok, reason):
    if not ok:
        raise SystemExit("M216 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    check(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
          "reviewed checkout SHA differs from expected")
    check(git("merge-base", base, head) == base,
          "current main is not ancestor of candidate")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    check(changed == SCOPE, "unexpected file scope: " +
          repr(sorted(changed ^ SCOPE)))

    source = read("lib/storage/waffra_pin_os_secure_candidate_stager.dart")
    tests = read("test/storage/m216_pin_os_secure_candidate_stage_test.dart")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    qa = read("docs/qa/m216-pin-os-protected-candidate-migration.md")
    main = read("lib/main.dart")
    release = read("lib/storage/waffra_production_cutover_release_gate.dart")

    for marker in (
        "class WaffraPinOsSecureCandidateStager",
        "FlutterSecureStorage(",
        "AndroidOptions(encryptedSharedPreferences: true)",
        "experimentalEnabled = false",
        "if (!experimentalEnabled)",
        "readLegacyHash",
        "readSecureHash",
        "writeSecureHash",
        "readLegacyHash() != legacy",
        "Protected PIN verifier differs from its source.",
        "Protected PIN verifier roundtrip failed.",
        "Secure PIN verifier has no verified legacy owner.",
    ):
        check(marker in source, "missing protected PIN stage safeguard: " + marker)
    check("prefs.remove(" not in source and "delete(" not in source,
          "candidate attempts to delete a credential")
    check("firebase" not in source.lower() and "print(" not in source,
          "candidate attempts network or sensitive logging")
    cases = [
        "M216 disabled by default cannot stage a legacy PIN",
        "M216 valid verifier is copied and independently roundtrip verified",
        "M216 matching protected verifier is idempotent",
        "M216 missing legacy and secure verifier creates no PIN",
        "M216 orphan protected verifier requires independent recovery",
        "M216 malformed plaintext-like legacy verifier is rejected",
        "M216 mismatched protected verifier cannot overwrite other PIN",
        "M216 secure OS writer failure never reports a verified copy",
        "M216 corrupt protected roundtrip cannot pass",
        "M216 concurrent legacy PIN replacement rejects stale protected copy",
    ]
    for marker in cases:
        check(marker in tests, "missing PIN negative test: " + marker)
    check("M216 SHA-pinned" in workflow and
          "m216_pin_os_secure_scope_review.py" in workflow,
          "missing exact-head CI review")
    check("[26] M216" in notes, "missing release notes")
    check("production NO-GO" in qa and
          "two physical Android" in qa and
          "low entropy" in qa, "undocumented credential blockers")
    check("p.getString('waffra_pin_sha256')" in main,
          "unexpected live PIN source; review independently")
    check("bool get automaticallyActivateSqlCipher => false;" in release,
          "unreviewed encrypted source activation")
    report = {
        "milestone": "M216",
        "reviewed_head": head,
        "main_at_review": base,
        "paths": sorted(changed),
        "secure_copy_only": True,
        "live_pin_ui_switched": False,
        "original_verifier_deleted": False,
        "two_physical_phones_verified": 0,
        "release": "NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
