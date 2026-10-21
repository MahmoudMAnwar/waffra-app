#!/usr/bin/env python3
"""Conservative per-test-file pass reuse for Waffra Android CI.

A cached result is accepted only when a *successfully released* prior build
recorded an identical fingerprint for that test and all its known inputs.
Finance-critical tests ALWAYS execute. A full smoke run executes every test.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

SCHEMA = 2
ROOT = Path(__file__).resolve().parent.parent
CACHE_PATH = ROOT / ".ci_cache" / "waffra_green_tests.json"
SOURCE_RE = re.compile(r"\b(?:import|export|part)\s+(?:r)?['\"]([^'\"]+)['\"]")
# These concern balances, payment scheduling, transactions, input safety,
# bank SMS, financial PDF data and financial backup integrity.
ALWAYS_TEST = (
    "bank_sms_test.dart",
    "waffra_amount_formatter_test.dart",
    "waffra_financial_insights_test.dart",
    "waffra_recurring_policy_test.dart",
    "waffra_saving_challenge_test.dart",
    "waffra_secure_backup_test.dart",
    "waffra_merchant_rules_test.dart",
    "waffra_validators_test.dart",
    "waffra_inline_form_validation_test.dart",
    "waffra_widget_quick_capture_test.dart",
    "waffra_pdf_text_test.dart",
)
# Changes in any of these invalidate every prior Flutter test result.
GLOBAL_INPUTS = (
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml",
    ".github/workflows/android.yml",
    "scripts/smart_ci.py",
)
GLOBAL_DIRS = ("assets", "native", "firebase")


def source_files(root: Path, directory: str, suffix: str = "") -> set[Path]:
    folder = root / directory
    if not folder.exists():
        return set()
    return {p.resolve() for p in folder.rglob("*")
            if p.is_file() and (not suffix or p.name.endswith(suffix))}


def test_files(root: Path) -> list[Path]:
    return sorted(source_files(root, "test", "_test.dart"))


def _safe_local(root: Path, source: Path, uri: str) -> Path | None:
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:waffra/"):
        target = root / "lib" / uri.split("/", 1)[1]
    elif uri.startswith("package:"):
        # Third-party packages are pinned by pubspec.lock + Flutter version.
        return None
    else:
        target = source.parent / uri
    target = target.resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError:
        raise ValueError(f"Local import escapes the repository: {uri}")
    if not target.is_file():
        raise ValueError(f"Unresolved project import in {source}: {uri}")
    return target


def local_dependencies(root: Path, test: Path) -> set[Path]:
    """Walk import/export/part graph; fail closed on missing local imports."""
    seen: set[Path] = set()
    queue = [test]
    while queue:
        path = queue.pop()
        if path in seen:
            continue
        seen.add(path)
        text = path.read_text(encoding="utf-8")
        for uri in SOURCE_RE.findall(text):
            resolved = _safe_local(root, path, uri)
            if resolved is not None and resolved not in seen:
                queue.append(resolved)
        # Tests sometimes read/check Dart sources without importing them.
        if path == test and re.search(r"\b(?:File|Directory)\s*\(", text):
            seen.update(source_files(root, "lib", ".dart"))
    # main.dart has app-wide shared state, mixins and multiple dynamically
    # referenced modules. Be conservative about anything using that module.
    if (root / "lib/main.dart").resolve() in seen:
        seen.update(source_files(root, "lib", ".dart"))
    return seen


def global_dependencies(root: Path) -> set[Path]:
    inputs = {root / name for name in GLOBAL_INPUTS}
    for directory in GLOBAL_DIRS:
        inputs.update(source_files(root, directory))
    return {p.resolve() for p in inputs if p.is_file()}


def sha_for_inputs(root: Path, paths: set[Path], toolchain: str) -> str:
    digest = hashlib.sha256()
    digest.update(f"smart-ci-schema:{SCHEMA}\nflutter:{toolchain}\n".encode())
    for path in sorted(paths):
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\n")
    return digest.hexdigest()


def flutter_identity() -> str:
    result = subprocess.run(
        ["flutter", "--version", "--machine"],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(result.stdout)
    return "|".join(str(data.get(k, "")) for k in (
        "frameworkVersion", "frameworkRevision", "engineRevision",
        "dartSdkVersion", "channel",
    ))


def verified_baseline(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if (data.get("schema") != SCHEMA or
                data.get("all_tests_passed") is not True or
                not isinstance(data.get("fingerprints"), dict) or
                data.get("branch") != "main"):
            return {}
        return data
    except (OSError, json.JSONDecodeError, ValueError):
        return {}


def determine_plan(root: Path, previous: dict, toolchain: str,
                   *, full: bool = False) -> tuple[dict[str, str], list[str], list[str]]:
    tests = test_files(root)
    if not tests:
        raise RuntimeError("No Flutter tests discovered: refusing a green CI build")
    globals_ = global_dependencies(root)
    fingerprints: dict[str, str] = {}
    executed: list[str] = []
    reused: list[str] = []
    prior_hashes = previous.get("fingerprints", {})
    for test in tests:
        path = test.relative_to(root).as_posix()
        try:
            inputs = globals_ | local_dependencies(root, test)
        except (OSError, ValueError) as error:
            # Unknown dependency: all project Dart files are a safe fallback.
            print(f"CONSERVATIVE fallback for {path}: {error}", flush=True)
            inputs = (globals_ | source_files(root, "lib", ".dart")
                      | source_files(root, "test", ".dart"))
        fingerprint = sha_for_inputs(root, inputs, toolchain)
        fingerprints[path] = fingerprint
        if (full or test.name in ALWAYS_TEST or
                prior_hashes.get(path) != fingerprint):
            executed.append(path)
        else:
            reused.append(path)
    return fingerprints, executed, reused


def update_report(root: Path, previous: dict, executed: list[str],
                  reused: list[str], duration: float, full: bool) -> None:
    lines = [
        "### Waffra Smart Incremental CI",
        "",
        f"- Previous verified successful build: **{previous.get('run_number', 'none')}**",
        f"- Executed Flutter test files: **{len(executed)}**",
        f"- Reused verified successful test files: **{len(reused)}**",
        f"- Failed test files: **0** (Flutter runner exited successfully)",
        f"- Flutter test command duration: **{duration:.1f} seconds**",
        f"- Full validation requested: **{'Yes' if full else 'No'}**",
        "",
        "| Test file | Verification |",
        "|:--|:--|",
    ]
    lines.extend(f"| \x60{p}\x60 | Executed — passed |" for p in executed)
    lines.extend(f"| \x60{p}\x60 | Reused — unchanged inputs |" for p in reused)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"executed={len(executed)}\nreused={len(reused)}\n")


def main() -> int:
    root = ROOT
    full = os.environ.get("WAFFRA_FULL_VALIDATION", "").lower() == "true"
    previous = verified_baseline(CACHE_PATH)
    toolchain = flutter_identity()
    hashes, executed, reused = determine_plan(
        root, previous, toolchain, full=full,
    )
    print(f"Previous verified manifest: {previous.get('run_number', 'none')}")
    print(f"Execute {len(executed)} test files; reuse {len(reused)} verified outcomes")
    # Keep a positive gate: no implicit "passed" when nothing ran.
    if not executed:
        raise RuntimeError("Financial safety tests missing; refusing skip-all")
    start = time.monotonic()
    # A single Flutter invocation saves repeated test startup/compilation.
    command = ["flutter", "test", "--no-pub", *executed]
    result = subprocess.run(command, cwd=root, check=False)
    elapsed = time.monotonic() - start
    if result.returncode:
        print(f"Flutter tests FAILED ({result.returncode}); cannot cache any outcomes")
        return result.returncode

    # This file will ONLY be uploaded to GitHub Actions cache AFTER a successful
    # APK build, release-signature verification and artifact upload.
    document = {
        "schema": SCHEMA,
        "branch": "main",
        "all_tests_passed": True,
        "run_number": os.environ.get("GITHUB_RUN_NUMBER", "local"),
        "source_sha": os.environ.get("GITHUB_SHA", "local"),
        "verified_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "toolchain": toolchain,
        "fingerprints": hashes,
        "executed": executed,
        "reused": reused,
    }
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp = CACHE_PATH.with_suffix(".tmp")
    temp.write_text(json.dumps(document, ensure_ascii=False, indent=2),
                    encoding="utf-8")
    temp.replace(CACHE_PATH)
    update_report(root, previous, executed, reused, elapsed, full)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Smart test runner refused to skip tests: {exc}", file=sys.stderr)
        sys.exit(1)
