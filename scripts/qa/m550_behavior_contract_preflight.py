#!/usr/bin/env python3
"""M550: exact-head, all-workflow test/behavior contract preflight.

Prevents obsolete *positive* source-text assertions from reaching expensive
Android/Flutter CI after approved runtime changes. Does not edit, skip, weaken,
or silently accept any test. This static guard supplements real test execution.
"""
from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = "docs/qa/behavior_contract_review.json"
PRODUCTION = ("lib/", "native/", "android/", "ios/", "firebase/", "assets/")
SAFE_STRING = re.compile(r"^[A-Za-z0-9_./ -]+$")
POSITIVE_DART = re.compile(
    r"\bexpect\(\s*(?P<var>[A-Za-z_]\w*)\s*,\s*contains\(\s*"
    r"(?P<q>['\"])(?P<literal>(?:\\.|(?!\2).)*)\2\s*\)",
    re.DOTALL,
)
ANCHOR_DART = re.compile(
    r"\b(?P<var>[A-Za-z_]\w*)\.split\(\s*"
    r"(?P<q>['\"])(?P<literal>(?:\\.|(?!\2).)*)\2",
    re.DOTALL,
)
BINDING_DART = re.compile(
    r"\b(?:final|var)\s+(?P<var>[A-Za-z_]\w*)\s*=\s*File\(\s*"
    r"(?P<q>['\"])(?P<path>(?:lib|native|android|ios|firebase|assets)/[^'\"]+)\2\s*\)"
    r"\.readAsStringSync\(\s*\)",
)
# M687: explicit source-inspection helper still targets the actual main.dart
# library and its declared Dart parts, not an unverified mock of the source.
BINDING_MAIN_RECON = re.compile(
    r"\b(?:final|var)\s+(?P<var>[A-Za-z_]\w*)\s*=\s*"
    r"readWaffraMainSourceForContracts\(\s*\)",
)
BINDING_SHELL = re.compile(
    r"\b(?P<var>[A-Za-z_]\w*)\s*=\s*Path\(\s*"
    r"(?P<q>['\"])(?P<path>(?:lib|native|android|ios|firebase|assets)/[^'\"]+)\2\s*\)"
    r"\.read_text\(",
)
ASSERT_SHELL = re.compile(
    r"\bassert\s+(?P<q>['\"])(?P<literal>(?:\\.|(?!\1).)*)\1"
    r"\s+in\s+(?P<var>[A-Za-z_]\w*)\b",
)
JOB = re.compile(r"(?m)^  ([A-Za-z_][\w-]*):\s*(?:#.*)?$")
TEST_COMMAND = re.compile(
    r"(flutter\s+test\b|dart\s+test\b|pytest\b|python3?\s+-m\s+unittest\b|"
    r"\bgradlew\b.*\btest\b|flutter\s+analyze\b)",
    re.IGNORECASE,
)


class ContractError(ValueError):
    pass


def git(*args: str) -> str:
    p = subprocess.run(("git", *args), cwd=ROOT, check=False,
                       capture_output=True, text=True, encoding="utf-8")
    if p.returncode:
        raise ContractError("Git preflight failed: " + p.stderr[:350])
    return p.stdout


def changed_paths(base: str, head: str) -> set[str]:
    return {p for p in git("diff", "--name-only", "--diff-filter=ACMRD",
                            "-z", base, head).split("\x00") if p}


def _safe_literal(q: str, raw: str) -> str | None:
    # Dart source assertions can include interpolations and raw strings.
    # Only decode unambiguous Python-compatible constant literals.
    if "$" in raw or "\n" in raw:
        return None
    try:
        value = ast.literal_eval(q + raw + q)
        return value if isinstance(value, str) and len(value) >= 4 else None
    except (ValueError, SyntaxError):
        return None


def _read_path(expr: ast.AST) -> str | None:
    if not isinstance(expr, ast.Call):
        return None
    call = expr
    if isinstance(call.func, ast.Attribute) and call.func.attr == "read":
        if isinstance(call.func.value, ast.Name) and len(call.args) >= 1:
            value = call.args[0]
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                return value.value
    if isinstance(call.func, ast.Attribute) and call.func.attr in {
        "read_text", "read_bytes"
    }:
        parent = call.func.value
        if isinstance(parent, ast.Call) and isinstance(parent.func, ast.Name):
            if parent.func.id == "Path" and parent.args:
                arg = parent.args[0]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    return arg.value
    return None


def _positive_python(text: str, path: str) -> list[tuple[str, str, int, str]]:
    try:
        tree = ast.parse(text, filename=path)
    except SyntaxError as exc:
        raise ContractError(f"{path}: malformed Python QA test: {exc}") from exc
    found: list[tuple[str, str, int, str]] = []
    # Function-local bindings prevent one test's "native" variable being
    # mistakenly attributed to another function reading a different file.
    funcs = [n for n in ast.walk(tree)
             if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
    for fn in funcs:
        vars_to_file: dict[str, str] = {}
        for node in ast.walk(fn):
            if isinstance(node, (ast.Assign, ast.AnnAssign)):
                value = node.value
                src = _read_path(value) if value is not None else None
                if src is None and isinstance(value, ast.Call) and isinstance(value.func, ast.Name) and value.func.id == 'read_waffra_home_source':
                    src = 'lib/main.dart'
                if src:
                    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                    for target in targets:
                        if isinstance(target, ast.Name):
                            vars_to_file[target.id] = src
        for node in ast.walk(fn):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                if node.func.attr == "assertIn" and len(node.args) >= 2:
                    lhs, rhs = node.args[:2]
                    if isinstance(lhs, ast.Constant) and isinstance(lhs.value, str):
                        if isinstance(rhs, ast.Name) and rhs.id in vars_to_file:
                            found.append((vars_to_file[rhs.id], lhs.value,
                                          node.lineno, "assertIn"))
            if isinstance(node, ast.Compare) and len(node.ops) == 1:
                if isinstance(node.ops[0], ast.In) and len(node.comparators) == 1:
                    rhs = node.comparators[0]
                    if isinstance(rhs, ast.Name) and rhs.id in vars_to_file:
                        if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                            found.append((vars_to_file[rhs.id], node.left.value,
                                          node.lineno, "positive in"))
    return found


def _positive_dart(text: str) -> list[tuple[str, str, int, str]]:
    bindings = {m["var"]: m["path"] for m in BINDING_DART.finditer(text)}
    bindings.update({m["var"]: "lib/main.dart"
                     for m in BINDING_MAIN_RECON.finditer(text)})
    found = []
    for kind, pat in (("expect contains", POSITIVE_DART),
                      ("source split anchor", ANCHOR_DART)):
        for m in pat.finditer(text):
            target = bindings.get(m["var"])
            literal = _safe_literal(m["q"], m["literal"])
            if target and literal:
                found.append((target, literal, text.count("\n", 0, m.start()) + 1, kind))
    return found


def _positive_workflow(text: str) -> list[tuple[str, str, int, str]]:
    bindings = {m["var"]: m["path"] for m in BINDING_SHELL.finditer(text)}
    found = []
    for m in ASSERT_SHELL.finditer(text):
        target = bindings.get(m["var"])
        literal = _safe_literal(m["q"], m["literal"])
        if target and literal:
            found.append((target, literal, text.count("\n", 0, m.start()) + 1,
                          "inline workflow assert"))
    return found


def detect_stale(
    tests: dict[str, str],
    base_sources: dict[str, str],
    head_sources: dict[str, str],
    modified_sources: set[str],
) -> tuple[list[dict], int]:
    """Only assert proven baseline->head disappearance, never a guess.

    A baseline assertion already broken on main does not become a new PR
    failure. Negative assertions and nonconstant expressions are untouched.
    """
    stale: list[dict] = []
    examined = 0
    for test_path, data in sorted(tests.items()):
        if test_path.endswith(".py"):
            positives = _positive_python(data, test_path)
        elif test_path.endswith(".dart"):
            positives = _positive_dart(data)
        elif test_path.endswith((".yml", ".yaml")):
            positives = _positive_workflow(data)
        else:
            continue
        for source, literal, lineno, kind in positives:
            if source not in modified_sources:
                continue
            if source not in base_sources or source not in head_sources:
                continue
            examined += 1
            if literal in base_sources[source] and literal not in head_sources[source]:
                stale.append({"test": test_path, "line": lineno,
                              "source": source, "old_expectation": literal[:150],
                              "kind": kind})
    return stale, examined


def inventory(root: Path = ROOT) -> dict:
    workflows = sorted([*root.glob(".github/workflows/*.yml"),
                        *root.glob(".github/workflows/*.yaml")])
    dart = sorted(root.glob("test/**/*.dart"))
    qa = sorted(root.glob("test/qa/**/*.py"))
    script_tests = sorted(root.glob("scripts/qa/test_*.py"))
    jobs = []
    for path in workflows:
        raw = path.read_text(encoding="utf-8")
        suffix = raw.split("\njobs:\n", 1)[-1] if "\njobs:\n" in raw else ""
        job_names = JOB.findall(suffix)
        commands = [line.strip()[:260] for line in raw.splitlines()
                    if TEST_COMMAND.search(line)]
        jobs.extend({"workflow": path.relative_to(root).as_posix(),
                     "job": job, "test_commands": commands} for job in job_names)
    return {"workflows": len(workflows), "jobs": jobs,
            "dart_tests": len(dart), "python_qa_tests": len(qa),
            "python_script_tests": len(script_tests),
            "workflow_files": [p.relative_to(root).as_posix() for p in workflows],
            "test_files": [p.relative_to(root).as_posix() for p in (*dart, *qa, *script_tests)]}


def validate_review(
    review: dict, changed: set[str], available: set[str],
    *,
    must_be_changed: bool = True,
    approved_deleted: set[str] | None = None,
) -> list[str]:
    if review.get("schema_version") != 1:
        raise ContractError("M550 behavior review missing/invalid schema_version=1")
    if review.get("workflow_review_policy") != "scan-all-registered-workflows":
        raise ContractError("M550 must audit ALL registered GitHub Actions workflows")
    if must_be_changed and CONTRACT not in changed:
        raise ContractError(f"M550 behavior change requires updated {CONTRACT}")
    sources = {p for p in changed if p.startswith(PRODUCTION)}
    contracts = review.get("contracts")
    if not isinstance(contracts, list) or not contracts:
        raise ContractError("M550 requires substantive behavior-to-test contracts")
    # Exact-path deletions must be declared by the M385 scope gate.
    # M550 still requires a reviewed behavior contract and live QA tests.
    deleted = approved_deleted or set()
    covered = set()
    summaries = []
    for c in contracts:
        if not isinstance(c, dict):
            raise ContractError("M550 contract entry must be an object")
        for key in ("id", "issue", "previous_behavior", "approved_behavior"):
            if not isinstance(c.get(key), str) or len(c[key].strip()) < 8:
                raise ContractError(f"M550 contract has missing {key}")
        paths, tests = c.get("source_paths"), c.get("test_paths")
        if not isinstance(paths, list) or not paths or not isinstance(tests, list) or not tests:
            raise ContractError(f"M550 {c['id']}: provide source_paths and test_paths")
        if any(not isinstance(p, str) or
                   (p not in available and p not in deleted)
                   for p in paths + tests):
            raise ContractError(f"M550 {c['id']}: source/test reference missing from checkout")
        if any(p in deleted for p in tests):
            raise ContractError(f"M550 {c['id']}: removed test cannot attest deleted source")
        if any(not p.startswith(("test/", "scripts/qa/test_")) for p in tests):
            raise ContractError(f"M550 {c['id']}: test_paths must be real QA tests")
        safety = c.get("safety_invariants")
        if not isinstance(safety, list) or not safety or any(
            not isinstance(x, str) or len(x) < 10 for x in safety
        ):
            raise ContractError(f"M550 {c['id']}: missing safety invariants")
        covered.update(paths)
        summaries.append(c["id"])
    missing = sources - covered
    if missing:
        raise ContractError("M550 missing reviewed source behavior: " +
                            ", ".join(sorted(missing)))
    return summaries


def build_report(base: str, head: str, root: Path = ROOT) -> dict:
    if git("rev-parse", "HEAD").strip() != head:
        raise ContractError("M550 refuses synthetic merge or wrong HEAD checkout")
    changed = changed_paths(base, head)
    sources = {p for p in changed if p.startswith(PRODUCTION)}
    inv = inventory(root)
    if inv["workflows"] < 1 or not inv["jobs"]:
        raise ContractError("M550 workflow inventory empty; refusing false green")
    available = {x.relative_to(root).as_posix() for x in root.rglob("*") if x.is_file()}
    # M701: Validate removed production paths against the exact approved
    # deletion declaration. Never treat a random missing file as approved.
    deleted_sources = sources - available
    try:
        scope = json.loads((root / "docs/qa/approved_change_scope.json").read_text(encoding="utf-8"))
        approved_deleted = set(scope.get("approved_deleted_files", []))
    except (OSError, ValueError, TypeError) as e:
        raise ContractError(f"M550 approved deletion scope unreadable: {e}") from e
    if deleted_sources - approved_deleted:
        raise ContractError("M550 undeclared deleted source: " +
                            ", ".join(sorted(deleted_sources - approved_deleted)))
    if sources:
        try:
            contract = json.loads((root / CONTRACT).read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            raise ContractError(f"M550 behavior review unreadable: {e}") from e
        contracts = validate_review(contract, changed, available,
                                    approved_deleted=deleted_sources)
    else:
        contracts = []
    # Complete *repository* inventory, not a handpicked list of jobs.
    target_tests = {}
    for p in inv["test_files"] + inv["workflow_files"]:
        file = root / p
        target_tests[p] = file.read_text(encoding="utf-8", errors="replace")
    old_sources: dict[str, str] = {}
    new_sources: dict[str, str] = {}
    for p in sorted(sources):
        try:
            old_sources[p] = git("show", f"{base}:{p}")
        except ContractError:
            continue  # New source path: no deleted baseline assertion.
        # Deleted sources are protected by the M385 exact-path gate.
        # They cannot be opened at HEAD, and are deliberately not
        # reconstituted from the baseline as though still executable.
        if p in available:
            new_sources[p] = (root / p).read_text(encoding="utf-8")
    # M687: same-library part moves are NOT code deletions. Check that every
    # extracted part is declared by main.dart, says 'part of main.dart', and
    # exists in the head tree before allowing any old source assertion to
    # match the moved text. Keep the original baseline unchanged: a dropped
    # or unregistered implementation still fails the exact-head scan.
    home_path = "lib/main.dart"
    expected_parts = (
        "lib/waffra_home_pdf_reports.part.dart",
        "lib/waffra_home_profile.part.dart",
        "lib/waffra_home_budget_cards.part.dart",
        "lib/waffra_home_budget_workflows.part.dart",
        "lib/waffra_home_entry_sheet.part.dart",
        "lib/waffra_home_account_tools.part.dart",
        "lib/waffra_home_sms_transfer_review.part.dart",
        "lib/waffra_home_verified_transfer_cards.part.dart",
        "lib/waffra_home_category_workflows.part.dart",
        "lib/waffra_home_sms_inbox.part.dart",
        "lib/waffra_home_sms_rules.part.dart",
        "lib/waffra_home_sms_refresh.part.dart",
        "lib/waffra_home_finance_startup.part.dart",
        "lib/waffra_home_sms_confirmation.part.dart",
        "lib/waffra_home_verified_account_flows.part.dart",
        "lib/waffra_home_finance_persistence_due.part.dart",
        "lib/waffra_home_transaction_ledger_actions.part.dart",
        "lib/waffra_home_goals_recurring_pages.part.dart",
        "lib/waffra_home_goal_actions.part.dart",
        "lib/waffra_home_dashboard_analytics.part.dart",
    )
    if home_path in new_sources:
        main_source = new_sources[home_path]
        for part_path in expected_parts:
            filename = Path(part_path).name
            if f"part '{filename}';" not in main_source:
                continue
            part_source = (root / part_path).read_text(encoding="utf-8")
            if not part_source.startswith("part of 'main.dart';"):
                raise ContractError(f"Unregistered or foreign Dart part: {part_path}")
            new_sources[home_path] += "\\n" + part_source
    stale, count = detect_stale(target_tests, old_sources, new_sources, sources)
    impacted = [j for j in inv["jobs"] if
                any("flutter test test/" in cmd or
                    "unittest discover" in cmd or
                    any(t in cmd for t in inv["test_files"])
                    for cmd in j["test_commands"])]
    return {"base": base, "head": head, "workflow_count": inv["workflows"],
            "job_count": len(inv["jobs"]),
            "test_count": inv["dart_tests"] + inv["python_qa_tests"] + inv["python_script_tests"],
            "source_files_changed": sorted(sources),
            "reviewed_contracts": contracts,
            "positive_assertions_checked": count,
            "potentially_impacted_full_test_jobs": impacted,
            "all_workflow_jobs": inv["jobs"],
            "obsolete_assertions": stale}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--report", default="")
    args = parser.parse_args()
    try:
        report = build_report(args.base, args.head)
        if args.report:
            dest = ROOT / args.report
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")
        print(f"M550 reviewed {report['workflow_count']} workflow files / "
              f"{report['job_count']} jobs, {report['test_count']} test files, "
              f"{report['positive_assertions_checked']} positive changed-source "
              f"assertions across exact SHA {args.head[:12]}")
        for broken in report["obsolete_assertions"]:
            print(f"STALE CONTRACT: {broken['test']}:{broken['line']} -> "
                  f"{broken['source']}: {broken['old_expectation']!r}")
        if report["obsolete_assertions"]:
            raise ContractError(
                f"{len(report['obsolete_assertions'])} obsolete positive "
                "test/workflow assumptions; reconcile approved code behavior "
                "and update tests BEFORE running costly CI"
            )
        print("PASS M550 contract-preflight; real Python/Flutter/Android "
              "test suites still MUST pass independently")
        return 0
    except ContractError as exc:
        print("BLOCKED M550: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
