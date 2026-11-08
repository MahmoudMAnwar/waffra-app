"""M564: reviewed bank SMS finance cannot silently use the device clock."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')

class ExactBankSmsDateTest(unittest.TestCase):
 def test_batch_rejects_missing_or_ambiguous_source_timestamp(self):
  self.assertIn('bankSmsDate(raw)==null||bankSmsHasUnverifiedTimestamp(raw)',SOURCE)
  self.assertIn('final verifiedSmsDate=bankSmsDate(raw);',SOURCE)
  self.assertIn('date:verifiedSmsDate,notes:raw,sourceType:',SOURCE)
  self.assertNotIn('date:bankSmsDate(raw)??DateTime.now()',SOURCE)

 def test_single_sms_must_use_parsed_date(self):
  self.assertIn('final verifiedSmsDate=bankSmsDate(messages[index]);',SOURCE)
  self.assertIn('verifiedSmsDate==null||bankSmsHasUnverifiedTimestamp(messages[index])',SOURCE)
  self.assertIn('date:verifiedSmsDate,notes:messages[index]',SOURCE)
  self.assertNotIn('income:income,date:now,notes:messages[index]',SOURCE)

if __name__ == '__main__':
 unittest.main()
