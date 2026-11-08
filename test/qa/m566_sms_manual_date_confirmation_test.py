"""M566: editable SMS must confirm unknown original bank date before finance write."""
from pathlib import Path
import unittest
SOURCE=(Path(__file__).resolve().parents[2]/'lib/main.dart').read_text(encoding='utf-8')
class SmsDateReviewTest(unittest.TestCase):
 def test_date_consent_inside_editor(self):
  region=SOURCE.split('Future<void> entrySheet(',1)[1].split('Future<void> showReceipt(',1)[0]
  for marker in ('final originalSmsDate=sms&&initialSms!=null?',
   "var smsDateConfirmed=smsEditorDraft?['dateConfirmed']==true||",
   'if(sms)smsDateConfirmed=true;', 'if(!smsDateConfirmed){',
   "'dateConfirmed':smsDateConfirmed,", 'Choose the real bank transaction date'):
   self.assertIn(marker,region)
if __name__=='__main__':unittest.main()
