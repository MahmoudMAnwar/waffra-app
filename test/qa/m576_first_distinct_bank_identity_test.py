"""M576: distinct sender+four digit bank identity needs owner account choice."""
from pathlib import Path
import unittest

SRC=(Path(__file__).resolve().parents[2]/'lib/main.dart').read_text(encoding='utf-8')

class BankIdentityChoice(unittest.TestCase):
 def test_second_account_same_bank_never_silently_inherits_old_identity(self):
  reader=SRC.split('Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(',1)[1].split('/// Budget assignment is OPTIONAL',1)[0]
  for expected in ('final sameBankIdsForOffer=<String>{',
   'final identitySuffix=firstSmsFacts==null?null:',
   'final verifiedIdentity=identitySuffix==null?null:',
   'final needsNewIdentityChoice=firstSenderIncomeExpense&&',
   '(!alreadyLinkedToBank||', '(identitySuffix!=null&&verifiedIdentity==null)',
   'if(needsNewIdentityChoice&&',
   'WaffraSmsAccountLearning.suggest(learned,sender:smsSender,',
   'lastFour:draft.lastFour', 'Choose existing', 'Add account',
   'exactSmsIdentityConfirmed','latest.witness.generation'):
   self.assertIn(expected,reader)
  self.assertEqual(1,reader.count('var learned=<WaffraSmsAccountEvidence>[];'))
  self.assertEqual(1,reader.count('.read(_smsRuleOwnerKey);'))
  self.assertIn('if(approved!=true)return null;',reader)

if __name__=='__main__':unittest.main()
