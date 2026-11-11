#!/usr/bin/env python3
"""M385: fail-closed PR diff boundaries; never silently modify unrequested code.

A committed scope manifest limits which files and *which portions* of existing
application/CI code may change. Human approval of the scope is a separate
required review, not something a machine or PR author can self-certify.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Mapping

MANIFEST_PATH = "docs/qa/approved_change_scope.json"
PROTECTED_PREFIXES = (
    "lib/", "native/", "android/", "ios/", "firebase/", "assets/",
    ".github/workflows/", "scripts/qa/", "test/",
)


class ScopeViolation(ValueError):
    pass


def git(*args: str) -> bytes:
    p = subprocess.run(["git", *args], stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, check=False)
    if p.returncode:
        raise ScopeViolation("Cannot inspect exact Git revision/diff: " +
                             p.stderr.decode("utf-8", errors="replace")[:350])
    return p.stdout


def unchanged_outside_sections(source: str, specifications: list[dict],
                               path: str) -> str:
    """Replace only approved anchored function/job bodies with opaque markers.

    The rest of the original file must match byte-for-byte after replacement,
    regardless of how many lines were added, removed, or moved inside the scope.
    An anchor removed, duplicated or reordered always blocks the PR.
    """
    if not specifications:
        raise ScopeViolation(f"No bounded sections for protected file {path}")
    spans = []
    for i, spec in enumerate(specifications):
        if not isinstance(spec, dict):
            raise ScopeViolation(f"Malformed section {i} for {path}")
        start, end = spec.get("start"), spec.get("end")
        if not isinstance(start, str) or not start or source.count(start) != 1:
            raise ScopeViolation(f"Missing/duplicate start anchor {i} in {path}")
        left = source.index(start)
        if end is None:
            right = len(source)
        else:
            if not isinstance(end, str) or not end or source.count(end) != 1:
                raise ScopeViolation(f"Missing/duplicate end anchor {i} in {path}")
            right = source.index(end)
            if right <= left + len(start):
                raise ScopeViolation(f"Reversed section anchors in {path}")
        spans.append((left, right, i))
    spans.sort()
    previous_end = 0
    parts = []
    for left, right, index in spans:
        if left < previous_end:
            raise ScopeViolation(f"Overlapping or reordered sections in {path}")
        parts.append(source[previous_end:left])
        parts.append(f"\\n<M385_APPROVED_SECTION_{index}>\\n")
        previous_end = right
    parts.append(source[previous_end:])
    return "".join(parts)


def audit_scope(manifest: dict, changed: set[str],
                base_text: Mapping[str, str],
                head_text: Mapping[str, str],
                base_exists: set[str]) -> None:
    if manifest.get("contract_version") != 1:
        raise ScopeViolation("Unsupported/missing scope manifest version")
    if MANIFEST_PATH not in changed:
        raise ScopeViolation("Every PR must create/update its change scope manifest")
    claims = manifest.get("user_requested_changes")
    if (not isinstance(claims, list) or not claims or
            any(not isinstance(t, str) or len(t.strip()) < 15 for t in claims)):
        raise ScopeViolation("Missing concrete user-requested change descriptions")
    allowed = manifest.get("allowed_changed_files")
    if (not isinstance(allowed, list) or not allowed or
            len(allowed) != len(set(allowed)) or
            any(not isinstance(p, str) or not p or ".." in p for p in allowed)):
        raise ScopeViolation("Invalid changed-file allowlist")
    expected = set(allowed)
    if changed != expected:
        raise ScopeViolation(
            "Unrequested or undeclared file change: extra=" +
            repr(sorted(changed - expected)) + " missing=" +
            repr(sorted(expected - changed)))
    # M636: An explicitly user-approved retirement may DELETE obsolete
    # engine-only files. Require a declared exact-path allowlist, not globs.
    # Protected source replacements cannot masquerade as deletion/recreation.
    deletions = manifest.get("approved_deleted_files", [])
    if (not isinstance(deletions, list) or len(deletions) != len(set(deletions)) or
            any(not isinstance(p, str) or not p or ".." in p for p in deletions)):
        raise ScopeViolation("Invalid approved deletion list")
    if set(deletions) != {p for p in changed if p in base_exists and p not in head_text}:
        raise ScopeViolation("Every removed source must have specific user approval")
    # M640 #561: only these exact owner-approved, obsolete OCR-only assets
    # may be deleted, in addition to the M636 Qwen retirement exceptions.
    # The manifest must ALSO declare every removed path by exact name.
    explicitly_retired = {
        "lib/waffra_ondevice_qwen.dart",
        "lib/waffra_ai_model_gate.dart",
        "scripts/qa/prefetch_verified_llamadart.sh",
        ".github/workflows/m317-ondevice-ai-brain.yml",
        "lib/waffra_widget_capture.part.dart",
        "native/WaffraQuickActivity.kt",
        "assets/tessdata_config.json",
        "lib/waffra_receipt_ocr.dart",
        "lib/waffra_receipt_ocr_parser.dart",
        "lib/waffra_bank_screenshot_parser.dart",
        ".github/workflows/m287-receipt-ocr.yml",
        ".github/workflows/m297-receipt-to-entry.yml",
        "scripts/qa/m287_patch_tesseract_gradle.py",
        "test/m287_receipt_ocr_test.dart",
        "test/m297_ocr_to_finance_and_sms_layout_test.dart",
        "test/m299_multi_transaction_image_review_test.dart",
        "test/m335_real_sms_ocr_accuracy_test.dart",
        "test/m332_ai_ocr_hang_and_six_for_three_test.dart",
        "test/m332_live_bank_image_sms_hang_regression_test.dart",
        "test/m329_ai_model_restart_and_visible_analysis_test.dart",
    }
    for p in deletions:
        if p not in explicitly_retired:
            raise ScopeViolation(f"Unrelated code deletion is prohibited: {p}")
    # M636: an owner-approved replacement of an obsolete test file is allowed
    # ONLY when declared by exact path, and only under test/. Never allow
    # wholesale production, security-gate, or workflow replacement.
    full_replacements = manifest.get("approved_full_test_replacements", [])
    if (not isinstance(full_replacements, list) or
            len(full_replacements) != len(set(full_replacements)) or
            any(not isinstance(p, str) or not p.startswith("test/") or
                ".." in p for p in full_replacements)):
        raise ScopeViolation("Invalid wholesale test replacement allowlist")
    if not set(full_replacements).issubset(changed):
        raise ScopeViolation("Unused full replacement declaration")
    bounded = manifest.get("bounded_sections")
    if not isinstance(bounded, dict):
        raise ScopeViolation("Missing protected-section boundaries")
    if set(bounded) - changed:
        raise ScopeViolation("Section scopes declared for unchanged files")
    for path in sorted(changed):
        if path not in base_exists:
            # New files may be created, but protected runtime paths cannot be
            # deleted and replaced with a clean file to bypass comparison.
            if path not in head_text:
                raise ScopeViolation(f"Missing newly declared file: {path}")
            continue
        if path not in head_text:
            # Only exact allowlisted, physically removed model-only paths pass.
            if path not in deletions:
                raise ScopeViolation(f"Existing file deleted without authorization: {path}")
            continue
        if path in full_replacements:
            continue
        if path.startswith(PROTECTED_PREFIXES) and path not in bounded:
            raise ScopeViolation(
                f"Existing production / CI file cannot change wholesale: {path}")
        if path in bounded:
            old = unchanged_outside_sections(base_text[path], bounded[path], path)
            new = unchanged_outside_sections(head_text[path], bounded[path], path)
            if old != new:
                raise ScopeViolation(
                    f"Old code outside user-approved sections was modified in {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, help="Exact main PR base SHA")
    parser.add_argument("--head", required=True, help="Exact PR HEAD SHA")
    args = parser.parse_args()
    if not args.base.strip():
        print("M385 main push: PR-specific diff checks are enforced on PR reviews")
        return 0
    actual_head = git("rev-parse", "HEAD").decode().strip()
    if actual_head != args.head:
        raise ScopeViolation("Checkout differs from exact PR head SHA")
    git("merge-base", "--is-ancestor", args.base, args.head)
    changed = set(filter(None, git("diff", "--name-only", "-z", args.base,
                                   args.head).decode().split("\x00")))
    manifest = json.loads(Path(MANIFEST_PATH).read_text(encoding="utf-8"))
    # Inspect the Git trees first. A failed "git show" for an existing file
    # must never be mistaken for a newly added file and skip its diff audit.
    base_exists = set(filter(None, git(
        "ls-tree", "-r", "--name-only", "-z", args.base).decode().split("\x00")))
    head_exists = set(filter(None, git(
        "ls-tree", "-r", "--name-only", "-z", args.head).decode().split("\x00")))
    base_text: dict[str, str] = {}
    head_text: dict[str, str] = {}
    for path in changed:
        if path in base_exists:
            base_text[path] = git("show", f"{args.base}:{path}").decode("utf-8")
        if path in head_exists:
            head_text[path] = git("show", f"{args.head}:{path}").decode("utf-8")
    audit_scope(manifest, changed, base_text, head_text, base_exists)
    print(f"PASS M385: {len(changed)} declared files, protected code outside "
          "bounded sections unchanged. Human scope approval still required.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ScopeViolation, UnicodeError, OSError, json.JSONDecodeError) as exc:
        print(f"BLOCKED M385: {exc}", file=sys.stderr)
        raise SystemExit(1)
