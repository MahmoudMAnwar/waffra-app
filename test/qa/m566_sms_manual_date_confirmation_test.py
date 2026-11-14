"""M566: editable SMS must confirm unknown original bank date before finance write."""
from pathlib import Path
from waffra_home_source import read_waffra_home_source
import unittest
SOURCE=read_waffra_home_source()
class SmsDateReviewTest(unittest.TestCase):
 def test_date_consent_inside_editor(self):
  region=SOURCE.split('Future<void> entrySheet(',1)[1].split('Future<void> showReceipt(',1)[0]
  for marker in ('final originalSmsDate=sms&&initialSms!=null?', 'initial!=null||',
   "var smsDateConfirmed=initial!=null||",
   "smsEditorDraft?['dateConfirmed']==true||originalSmsDate!=null;",
   'smsDateConfirmed=true;', 'showTimePicker(', 'if(!smsDateConfirmed){',
   "'dateConfirmed':smsDateConfirmed,", 'Choose the real bank transaction date'):
   self.assertIn(marker,region)
if __name__=='__main__':unittest.main()
