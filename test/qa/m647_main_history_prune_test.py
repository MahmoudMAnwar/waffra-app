"""M647 — confirm old main-only history pruning cannot erase live release evidence."""
import datetime as dt
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/m647_main_history_prune.py"
WORKFLOW = ROOT / ".github/workflows/m647-main-history-prune.yml"
spec = importlib.util.spec_from_file_location("m647_prune", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

NOW = dt.datetime(2026, 11, 11, 20, 0, tzinfo=dt.timezone.utc)
HEAD = "a" * 40
OLD = "b" * 40


def run(rid=10, conclusion="skipped", **changes):
    original = {
        "id": rid, "name": "M410 Bounded Failed Android UI Job Retry",
        "status": "completed", "conclusion": conclusion, "event": "workflow_run",
        "head_branch": "main", "head_sha": OLD,
        "head_repository": {"full_name": mod.REPOSITORY},
        "pull_requests": [],
        "created_at": "2026-11-07T12:00:00Z",
        "updated_at": "2026-11-07T12:00:10Z",
    }
    original.update(changes)
    return original


class FakeAPI:
    def __init__(self, rows, artifacts=None, live=None, head=HEAD):
        self.rows, self.artifacts, self.live, self.head = rows, artifacts or {}, live or {}, head
        self.calls = []

    def __call__(self, method, route):
        self.calls.append((method, route))
        if method == "GET" and route.endswith("/branches/main"):
            return {"commit": {"sha": self.head}}
        if method == "GET" and "/actions/runs?" in route:
            from urllib.parse import parse_qs
            q = parse_qs(route.partition("?")[2])
            # GitHub's supported "created" query uses an explicit comparison.
            # Bare "..YYYY-MM-DD" appears valid but returns ZERO real runs.
            expected_date = "<=" + (NOW - mod.AGE).date().isoformat()
            if q.get("created") != [expected_date]:
                raise AssertionError(
                    "Unsupported GitHub created filter (silent zero-run risk): "
                    + str(q.get("created")))
            matching = [x for x in self.rows
                        if x["conclusion"] == q["status"][0]]
            page = int(q["page"][0])
            size = int(q["per_page"][0])
            return {"workflow_runs": matching[(page-1)*size:page*size]}
        if method == "GET" and route.endswith("/artifacts?per_page=1"):
            rid = int(route.split("/runs/")[1].split("/")[0])
            return {"total_count": self.artifacts.get(rid, 0)}
        if method == "GET" and "/actions/runs/" in route:
            rid = int(route.rsplit("/", 1)[1])
            item = next(x for x in self.rows if x["id"] == rid)
            return self.live.get(rid, item)
        if method == "DELETE" and "/actions/runs/" in route:
            return {}
        raise AssertionError("Unexpected API call: " + method + " " + route)


class M647MainHistoryPruneTest(unittest.TestCase):
    def test_excludes_success_active_current_head_recent_non_main_pr_and_forks(self):
        self.assertTrue(mod.eligible(run(), now=NOW, main_sha=HEAD, current_run_id=999))
        invalid = [
            run(conclusion="success"),
            run(status="in_progress"), run(status="queued"),
            run(head_sha=HEAD), run(head_branch="feature/old"),
            run(event="pull_request"),
            run(head_repository={"full_name": "outsider/fork"}),
            run(pull_requests=[{"number": 321}]),
            run(created_at="2026-11-10T23:00:00Z"),
            run(updated_at="2026-11-10T23:00:00Z"),
            run(id=999), run(created_at=None), run(head_sha="bad"),
        ]
        for value in invalid:
            with self.subTest(item=value):
                self.assertFalse(mod.eligible(
                    value, now=NOW, main_sha=HEAD, current_run_id=999))

    def test_only_main_trusted_events_and_manual_confirmation(self):
        base = {"GITHUB_REPOSITORY": mod.REPOSITORY, "GITHUB_REF": "refs/heads/main",
                "GITHUB_SHA": HEAD, "GITHUB_EVENT_NAME": "workflow_dispatch"}
        self.assertTrue(mod.approve_execution(base, {"inputs": {}}))
        self.assertTrue(mod.approve_execution(base, {"inputs": {"dry_run": "true"}}))
        with self.assertRaises(RuntimeError):
            mod.approve_execution(base, {"inputs": {"dry_run": "false"}})
        with self.assertRaises(RuntimeError):
            mod.approve_execution(base, {"inputs": {"dry_run": "false",
                                                   "confirm_delete": "yes"}})
        self.assertFalse(mod.approve_execution(base, {"inputs": {
            "dry_run": "false", "confirm_delete": mod.CONFIRM}}))
        for event in ("pull_request", "pull_request_target", "workflow_run"):
            with self.assertRaises(RuntimeError):
                mod.approve_execution(dict(base, GITHUB_EVENT_NAME=event), {})
        for ref in ("refs/heads/old", "refs/pull/568/merge"):
            with self.assertRaises(RuntimeError):
                mod.approve_execution(dict(base, GITHUB_REF=ref), {})
        self.assertFalse(mod.approve_execution(dict(base, GITHUB_EVENT_NAME="schedule"), {}))

    def test_dry_run_does_not_issue_delete_and_preserves_artifacts(self):
        api = FakeAPI([run(10), run(11, conclusion="failure"),
                       run(12, conclusion="cancelled")], artifacts={11: 1})
        pruner = mod.MainPruner(api, now=NOW, run_id=99, commit_sha=HEAD,
                                sleep=lambda _: None)
        result = pruner.execute(dry_run=True)
        self.assertEqual(result["previewed"], 2)
        self.assertEqual(result["with_artifacts"], 1)
        self.assertEqual(result["deleted"], 0)
        self.assertFalse(any(method == "DELETE" for method, _ in api.calls))

    def test_fresh_read_blocks_mutation_if_run_completed_success_after_snapshot(self):
        changed = run(10, conclusion="success")
        api = FakeAPI([run(10)], live={10: changed})
        result = mod.MainPruner(api, now=NOW, run_id=99, commit_sha=HEAD,
                                sleep=lambda _: None).execute(dry_run=False)
        self.assertEqual(result["deleted"], 0)
        self.assertEqual(result["stale_or_protected"], 1)
        self.assertFalse(any(method == "DELETE" for method, _ in api.calls))

    def test_main_head_moved_blocks_deletion_entirely(self):
        api = FakeAPI([run(10)], head="c"*40)
        with self.assertRaisesRegex(RuntimeError, "main moved"):
            mod.MainPruner(api, now=NOW, run_id=99, commit_sha=HEAD,
                           sleep=lambda _: None).execute(dry_run=False)
        self.assertFalse(any(method == "DELETE" for method, _ in api.calls))

    def test_all_three_old_failed_skipped_cancelled_can_delete_no_success(self):
        api = FakeAPI([run(10), run(11, conclusion="failure"),
                       run(12, conclusion="cancelled"), run(13, conclusion="success")])
        result = mod.MainPruner(api, now=NOW, run_id=99, commit_sha=HEAD,
                                sleep=lambda _: None).execute(dry_run=False)
        self.assertEqual(result["deleted"], 3)
        self.assertEqual(set(result["example_ids"]), {10, 11, 12})
        self.assertEqual(result["by_conclusion"], {
            "skipped": 1, "failure": 1, "cancelled": 1})
        deletions = [route for method, route in api.calls if method == "DELETE"]
        self.assertEqual(len(deletions), 3)
        self.assertNotIn("/13", " ".join(deletions))

    def test_bounded_deletion_and_complete_list_snapshot_precedes_any_mutation(self):
        api = FakeAPI([run(i) for i in range(1, 270)])
        result = mod.MainPruner(api, now=NOW, run_id=999, commit_sha=HEAD,
                                sleep=lambda _: None).execute(dry_run=False)
        self.assertEqual(result["deleted"], mod.MAX_DELETE)
        self.assertEqual(len([x for x in api.calls if x[0] == "DELETE"]), mod.MAX_DELETE)
        first_delete = next(i for i, x in enumerate(api.calls) if x[0] == "DELETE")
        self.assertTrue(any("status=cancelled" in route
                            for method, route in api.calls[:first_delete] if method == "GET"))

    def test_created_filter_is_verified_github_api_comparison_not_zero_run_range(self):
        api = FakeAPI([run(10)])
        pruner = mod.MainPruner(api, now=NOW, run_id=99, commit_sha=HEAD,
                                sleep=lambda _: None)
        result = pruner.execute(dry_run=True)
        self.assertEqual(result["snapshotted"], 1)
        self.assertEqual(result["previewed"], 1)
        from urllib.parse import parse_qs
        list_calls = [parse_qs(route.partition("?")[2])
                      for method, route in api.calls
                      if method == "GET" and "/actions/runs?" in route]
        self.assertEqual(len(list_calls), 3)  # all 3 conclusions scanned
        self.assertTrue(all(q.get("created") == ["<=2026-11-09"]
                            for q in list_calls))
        self.assertFalse(any(method == "DELETE" for method, _ in api.calls))

    def test_unknown_artifact_count_fails_closed(self):
        api = FakeAPI([run(10)])
        old = api.__call__
        def unknown(method, route):
            if route.endswith("/artifacts?per_page=1"):
                return {}
            return old(method, route)
        with self.assertRaisesRegex(RuntimeError, "artifact"):
            mod.MainPruner(unknown, now=NOW, run_id=99, commit_sha=HEAD,
                           sleep=lambda _: None).execute(dry_run=False)

    def test_workflow_only_runs_after_main_merge_and_never_on_pr(self):
        source = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("branches: [main]", source)
        self.assertIn("workflow_dispatch:", source)
        self.assertIn("schedule:", source)
        self.assertIn("default: true", source)
        self.assertIn("confirm_delete:", source)
        self.assertNotIn("pull_request:", source)
        self.assertNotIn("pull_request_target:", source)
        self.assertIn("actions: write", source)
        self.assertIn("github.ref == 'refs/heads/main'", source)
        self.assertIn("persist-credentials: false", source)
        self.assertIn("m647_main_history_prune_test.py", source)
        self.assertIn("scripts/qa/m647_main_history_prune.py", source)
        self.assertNotIn("continue-on-error: true", source)


if __name__ == "__main__":
    unittest.main()
