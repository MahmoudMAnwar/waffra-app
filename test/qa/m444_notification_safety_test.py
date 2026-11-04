from pathlib import Path
import unittest

class M444NotificationSafety(unittest.TestCase):
 def test_recurring_notices_never_cancel_every_channel(self):
  reminders=Path('lib/waffra_reminders.dart').read_text(encoding='utf8')
  self.assertNotIn('_plugin.cancelAll()',reminders)
  self.assertIn('_plugin.pendingNotificationRequests()',reminders)
  self.assertIn('_plugin.cancel(request.id)',reminders)
  self.assertIn('oneTimeDueAt',reminders)
 def test_finance_ui_respects_threshold_and_real_due(self):
  main=Path('lib/main.dart').read_text(encoding='utf8')
  self.assertIn('WaffraFinancialInsights.reachedBudgetThreshold(',main)
  self.assertIn('budget:b.budget,alertPercent:b.alertPercent',main)
  self.assertIn('WaffraFinancialInsights.pendingCurrentMonth(',main)
  self.assertIn('oneTimeDueAt:r.linkedGoalId==null?null:r.startAt',main)

if __name__=='__main__':unittest.main()
