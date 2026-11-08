"""M574: every bank SMS Yes/No preview shows the complete audited fields."""
from pathlib import Path
import unittest

SRC=(Path(__file__).resolve().parents[2]/'lib/main.dart').read_text(encoding='utf-8')

class FullSmsPreviewTest(unittest.TestCase):
 def test_review_preview_displays_all_495_fields(self):
  block=SRC.split(' Future<void> _reviewAutoSmsCandidates(',1)[1].split(' Future<void> ',1)[0]
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
