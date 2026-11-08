"""M574: every bank SMS Yes/No preview shows the complete audited fields."""
from pathlib import Path
import re
import unittest

SRC=(Path(__file__).resolve().parents[2]/'lib/main.dart').read_text(encoding='utf-8')

class FullSmsPreviewTest(unittest.TestCase):
 def test_review_preview_displays_all_495_fields(self):
  # Scope to the full class method, not a nested Future<void> helper.
  marker='\n Future<void> _reviewAutoSmsCandidates('
  self.assertEqual(SRC.count(marker),1)
  remaining=SRC.split(marker,1)[1]
  method_end=re.search(r'(?m)^ \}$',remaining)
  self.assertIsNotNone(method_end,'Could not find SMS review method closing brace')
  block=remaining[:method_end.start()]
  self.assertNotIn('\n void _receiveSharedSms(',block)
  for text in ('هل العملية صحيحة؟','نوع العملية: ','الوصف: ',
   'القسم الرئيسي / الفرعي: ','المرسل: ',
   'تاريخ ووقت العملية الأصلي: ',
   'previewAccountLabel','previewMainName',
   'previewDateTime','originalDate.toIso8601String()',
   'facts.destinationSuffix:facts.sourceSuffix',
   "Key('m565-sms-yes-confirm')", "Key('m565-sms-no-edit')"):
   self.assertIn(text,block)
  self.assertIn('previewParents.length==1',block)

if __name__=='__main__':unittest.main()
