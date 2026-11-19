"""M566: editable SMS must confirm unknown original bank date before finance write."""
from pathlib import Path
from waffra_home_source import read_waffra_home_source
import unittest
SOURCE=read_waffra_home_source()
class SmsDateReviewTest(unittest.TestCase):
 def test_date_consent_inside_editor(self):
  region=SOURCE.split('Future<void> entrySheet(',1)[1].split('Future<void> showReceipt(',1)[0]
  for marker in (
   'final originalSmsDate=sms&&initialSms!=null?',
   'initial!=null||',
   "final savedManualDate=smsEditorDraft?['dateConfirmed']==true&&",
   "smsEditorDraft?['date'] is DateTime&&",
   "!(smsEditorDraft!['date'] as DateTime).isAfter(DateTime.now());",
   'final verifiedOriginalSmsDate=originalSmsDate!=null&&',
   '!originalSmsDate.isAfter(DateTime.now())&&',
   'var smsDateConfirmed=initial!=null||savedManualDate||verifiedOriginalSmsDate;',
   'smsDateConfirmed=true;',
   'showTimePicker(',
   'if(!smsDateConfirmed){',
   "'dateConfirmed':smsDateConfirmed,",
   'Choose the real bank transaction date',
   "Key('m1044-sms-date-provenance')",
   'تاريخ ووقت الرسالة الأصلية غير مؤكدين',
   'تم تأكيدهما يدويًا',
  ):
   self.assertIn(marker,region)
if __name__=='__main__':unittest.main()
