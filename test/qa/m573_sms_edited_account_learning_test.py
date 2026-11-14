"""M573: No/edit reviewed bank SMS learns account only after verified commit."""
from pathlib import Path
from waffra_home_source import read_waffra_home_source
import unittest

SRC=read_waffra_home_source()

class EditedSmsAccountLearning(unittest.TestCase):
 def test_editor_uses_sender_and_avoids_precommit_learning(self):
  editor=SRC.split(' Future<void> entrySheet(',1)[1].split(' Future<void> showReceipt(',1)[0]
  region=editor.split('if(pendingHash!=null&&initial==null){',1)[1]
  self.assertIn("smsSender:reviewedSender??''",region)
  self.assertIn('initialSelectedIds:chosenManualAccount==null?null:[chosenManualAccount]',region)
  self.assertIn('if(applied.saved!=1)',region)
  self.assertIn('_recordConfirmedSmsAccountAssociation(',region)
  self.assertIn('record:result,sender:reviewedSender,',region)
  self.assertIn('accountId:reviewedAccount.ids?.single',region)
  self.assertLess(region.index('_financeAuthority.commitConfirmedSms('),
                  region.index('if(applied.saved!=1)'))
  self.assertLess(region.index('if(applied.saved!=1)'),
                  region.index('_recordConfirmedSmsAccountAssociation('))
  self.assertLess(region.index('entries..clear()..addAll(verified)'),
                  region.index('_recordConfirmedSmsAccountAssociation('))

if __name__=='__main__': unittest.main()
