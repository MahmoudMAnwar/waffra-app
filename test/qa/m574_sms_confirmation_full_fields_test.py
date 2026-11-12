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
  # M615 approved review replaced one opaque paragraph with accessible
  # two-column rows. Keep all audited fields and verified-account safeguards.
  for text in ("'هل العملية صحيحة؟'",
   "_m615ReviewDetail(waffraIsEnglish?'Type':'نوع العملية'",
   "_m615ReviewDetail(waffraIsEnglish?'Amount':'المبلغ'",
   "_m615ReviewDetail(waffraIsEnglish?'Description':'الوصف'",
   "_m615ReviewDetail(waffraIsEnglish?'Main category':'القسم الرئيسي'",
   "_m615ReviewDetail(waffraIsEnglish?'Subcategory':'القسم الفرعي'",
   "_m615ReviewDetail(waffraIsEnglish?'Sender':'المرسل'",
   "_m615ReviewDetail(waffraIsEnglish?'Money account':'الحساب المالي'",
   "_m615ReviewDetail(waffraIsEnglish?'Original date/time':'تاريخ ووقت العملية'",
   'previewAccountLabel','previewMainName','previewDateTime',
   'originalDate.toIso8601String()',
   'facts.destinationSuffix:facts.sourceSuffix',
   "Key('m565-sms-yes-confirm')", "Key('m565-sms-no-edit')"):
   self.assertIn(text,block)
  # M669: an SMS classifier root is a suggestion, never a valid child.
  # The real bank confirmation must display one verified parent AND leaf,
  # original bank SMS, and exact account generation before enabling Yes.
  for evidence in (
   'previewHint=waffraResolveSmsReviewCategory(categories,',
   'reviewCategoryValid=previewHint.leaf!=null&&',
   'previewHint.parent!=null',
   "Key('m669-review-original-sms-text')",
   'SelectableText(body,textAlign:TextAlign.start)',
   "Key('m669-sms-review-blockers')",
   'reviewedAccount?.generation!=null',
   'onPressed:canConfirm&&reviewedAccount?.ids?.single!=null&&',
  ):
   self.assertIn(evidence,block)
  self.assertNotIn('reviewCategoryValid=previewLeaves.length==1&&',block)

if __name__=='__main__':unittest.main()
