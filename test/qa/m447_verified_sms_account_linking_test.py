"""M447: guard actual bank-SMS account selection through verified source."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class VerifiedSmsAccountLinkingTest(unittest.TestCase):
    def test_every_home_sms_commit_reviews_accounts(self):
        home = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertEqual(home.count("commitConfirmedSms("), 2)
        self.assertNotIn("Future<void> bulkSmsSheet(", home)
        self.assertIn("await entrySheet(sms:true,initialSms:body,reviewedSender:sender);", home)
        self.assertIn("userConfirmed:true", home)
        # M636: surviving paths are M565 yes-confirm + account-bound SMS editor;\n        # retired bulk paste and widget direct writers must NEVER return.
        self.assertIn("selectedAccountIds:chosen.ids", home)
        self.assertIn("expectedAccountGeneration:chosen.generation", home)
        self.assertIn("allowDuplicateHashes:false", home)
        # Verified source account selection remains mandatory for both SMS
        # routes, and goal_due continues to require an account and witness.
        self.assertEqual(home.count("await reviewSmsAccountLinks("), 5)
        self.assertIn("sourceType:'goal_due'", home)
        self.assertEqual(home.count("selectedAccountIds:reviewedAccounts.ids"), 0)
        self.assertEqual(home.count("selectedAccountIds:reviewedAccount.ids"), 1)
        self.assertEqual(home.count("expectedAccountGeneration:reviewedAccounts.generation"), 0)
        self.assertEqual(home.count("expectedAccountGeneration:reviewedAccount.generation"), 1)

    def test_manual_and_recurring_finance_account_selection(self):
        home = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("selectedAccountId:chosen.ids?.single", home)
        self.assertIn("selectedAccountId:initial==null?chosenManual?.ids?.single:null", home)
        self.assertIn("route:WaffraFinanceRoute.recurringPostingAndPostponement", home)

    def test_verified_source_only_with_no_shadow_db(self):
        home = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        reader = home.split("Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(", 1)[1]
        reader = reader.split("/// Budget assignment is OPTIONAL", 1)[0]
        self.assertIn("final bridge=_financeBinding?.accountsBridge;", reader)
        self.assertIn("if(bridge==null){", reader)
        self.assertIn("return mustSelectAccount?null:(ids:null,generation:null);", reader)
        self.assertIn("final dueRequiresAccount=recurringId!=null", reader)
        self.assertIn("if(mustSelectAccount&&assigned.any((account)=>account==null))return null;", reader)
        self.assertIn("final mustSelectAccount=candidates.isNotEmpty;", reader)
        self.assertIn("initialSelectedIds:chosenManualAccount==null?null:[chosenManualAccount]", home)
        self.assertNotIn("DropdownMenuItem(value:'none'", reader)
        self.assertIn("final manualRequiresAccount=candidates.any", reader)
        self.assertIn("if(active.isEmpty){", reader)
        self.assertIn("if(mustSelectAccount){", reader)
        self.assertIn("await bridge.readVerifiedAccounts()", reader)
        self.assertNotIn("SharedPreferences", reader)
        self.assertNotIn("WaffraEncryptedStore.openAt", reader)

    def test_no_guarded_legacy_sms_account_override(self):
        authority = (ROOT / "lib/storage/waffra_verified_finance_authority.dart").read_text(encoding="utf-8")
        self.assertIn("Account-linked SMS requires verified SQLCipher.", authority)
        self.assertIn("selectedAccountIds: accounts,", authority)
        session = (ROOT / "lib/storage/waffra_encrypted_finance_session.dart").read_text(encoding="utf-8")
        self.assertIn("selectedAccountIds: selectedAccountIds,", session)
        writer = (ROOT / "lib/storage/waffra_unified_finance_writer.dart").read_text(encoding="utf-8")
        self.assertIn("final selectedAccount=confirmedAccounts[i];", writer)
        self.assertIn("'INSERT INTO fresh_finance_account_entry_links '", writer)


if __name__ == "__main__":
    unittest.main()
