"""M565: reviewed SMS yes/no verified finance behavior and source-date contract."""
from pathlib import Path
import unittest

SOURCE=(Path(__file__).resolve().parents[2]/'lib/main.dart').read_text(encoding='utf-8')

class SmsYesNoTest(unittest.TestCase):
 def test_yes_no_with_preview_and_no_guessing(self):
  for value in ('هل العملية صحيحة؟',"Key('m565-sms-no-edit')",
   "Key('m565-sms-yes-confirm')",'onPressed:canConfirm&&reviewedAccount?.ids?.single!=null&&',
   "decision=='yes'", "decision=='no'",'originalDate=bankSmsDate(body)',
   "originalAmount.currency=='SAR'",'previewLeaves=categories.where((c)=>',
   'previewLeaves.length==1&&', 'previewParents.length==1'):
   self.assertIn(value,SOURCE)
 def test_authoritative_commit(self):
  body=SOURCE.split('Future<void> _m565ConfirmSms(',1)[1].split('Future<void> _reviewAutoSmsCandidates(',1)[0]
  for value in ('required ({List<String?>? ids,int? generation}) selectedAccount',
   'final chosen=selectedAccount;', 'selectedAccount.ids!.single',
   'reviewSmsBudgetLinks([record])','_financeAuthority.commitConfirmedSms(',
   'expectedAccountGeneration:chosen.generation','allowDuplicateHashes:false',
   'acknowledgeCommitted([id])','sourceType:\'sms\'',
   "original.currency!='SAR'",'bankSmsDate(body)==null',
   'if(applied.saved!=1)', 'entries..clear()..addAll(updated)'):
   self.assertIn(value,body)
  self.assertNotIn('DateTime.now()',body)

if __name__=='__main__':unittest.main()
