from pathlib import Path
import unittest
from waffra_home_source import read_waffra_home_source

class M228PullRefreshLiveWiring(unittest.TestCase):
    def test_refresh_only_changes_source_selection_not_named_budget_projection(self):
        src=read_waffra_home_source()
        left=src.index(" Future<void> _refreshFromVerifiedFinance()async {")
        right=src.index(" Future<void> load()async {",left)
        refresh=src[left:right]
        self.assertIn("WaffraVerifiedPullRefreshSource.fromAuthority(current)",refresh)
        self.assertIn("if(current.source==WaffraRuntimeFinanceBackend.guardedLegacy)",refresh)
        # M468 now awaits verified, background-capable JSON decoding.
        # Preserve the named-budget source and read-only projection checks.
        self.assertIn("final parsed=await WaffraLargeJsonDecode.parse(raw)",refresh)
        self.assertIn("final nextNamedBudgets=await readList<WaffraNamedBudget>(",refresh)
        self.assertIn("view.getString('waffra_named_budgets_v1'),WaffraNamedBudget.fromJson",refresh)
        self.assertIn("for(final c in nextCategories.where((c)=>!c.income&&c.budget>0))",refresh)
        self.assertIn("namedBudgets..clear()..addAll(nextNamedBudgets)",refresh)
        self.assertIn("view.requireIntegrity()",refresh)
        self.assertIn("await _financialWriteQueue.drain()",refresh)
        self.assertNotIn("await persist(",refresh)
        self.assertNotIn("await _financeAuthority.commit",refresh)

if __name__ == "__main__":
    unittest.main()
