from pathlib import Path
import unittest

class M228PullRefreshLiveWiring(unittest.TestCase):
    def test_refresh_only_changes_source_selection_not_named_budget_projection(self):
        src=Path("lib/main.dart").read_text(encoding="utf-8")
        left=src.index(" Future<void> _refreshFromVerifiedFinance()async {")
        right=src.index(" Future<void> load()async {",left)
        refresh=src[left:right]
        self.assertIn("WaffraVerifiedPullRefreshSource.fromAuthority(current)",refresh)
        self.assertIn("if(current.source==WaffraRuntimeFinanceBackend.guardedLegacy)",refresh)
        self.assertIn("final nextNamedBudgets=readList<WaffraNamedBudget>",refresh)
        self.assertIn("namedBudgets..clear()..addAll(nextNamedBudgets)",refresh)
        self.assertIn("view.requireIntegrity()",refresh)
        self.assertIn("await _financialWriteQueue.drain()",refresh)
        self.assertNotIn("await persist(",refresh)
        self.assertNotIn("await _financeAuthority.commit",refresh)

if __name__ == "__main__":
    unittest.main()
