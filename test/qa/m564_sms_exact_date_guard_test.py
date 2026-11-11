"""M564/M636: every surviving SMS posting route verifies source date.

The owner retired the independent bulk paste sheet, not the strict original-
timestamp guard or the account-bound, human-confirmed automatic SMS review.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')


class ExactBankSmsDateTest(unittest.TestCase):
    def test_auto_review_sms_requires_original_timestamp_before_atomic_post(self):
        start = SOURCE.index(" Future<void> _m565ConfirmSms({")
        end = SOURCE.index(" Future<void> _reviewAutoSmsCandidates(", start)
        confirm = SOURCE[start:end]
        rejected = confirm.index(
            "bankSmsDate(body)==null||bankSmsHasUnverifiedTimestamp(body)")
        commit = confirm.index("_financeAuthority.commitConfirmedSms(", rejected)
        self.assertLess(rejected, commit)
        self.assertIn("required double value,required DateTime date", confirm)
        self.assertIn("date:date,", confirm)
        self.assertIn("userConfirmed:true", confirm)
        self.assertNotIn("date:DateTime.now()", confirm)

    def test_sms_editor_requires_explicit_calendar_date_and_verified_currency(self):
        start = SOURCE.index(" Future<void> entrySheet(")
        end = SOURCE.index(" Future<void> showReceipt(", start)
        editor = SOURCE[start:end]
        guard = editor.index("if(!smsDateConfirmed)")
        money = editor.index(
            "WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
            guard)
        commit = editor.index("_financeAuthority.commitConfirmedSms(", money)
        self.assertLess(guard, money)
        self.assertLess(money, commit)
        self.assertIn("userConfirmed:true", editor)
        self.assertNotIn("date:bankSmsDate(raw)??DateTime.now()", editor)

    def test_removed_paste_and_widget_writers_cannot_default_to_today(self):
        self.assertNotIn("Future<void> bulkSmsSheet(", SOURCE)
        self.assertNotIn("part 'waffra_widget_capture.part.dart';", SOURCE)
        self.assertNotIn("date:bankSmsDate(raw)??DateTime.now()", SOURCE)


if __name__ == '__main__':
    unittest.main()
