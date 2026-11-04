from pathlib import Path
import unittest

class M440TransferReplayUx(unittest.TestCase):
 def test_exact_replay_is_not_exposed_as_failed_transfer(self):
  repository=Path('lib/storage/waffra_accounts_repository.dart').read_text(encoding='utf8')
  page=Path('lib/waffra_accounts_manager_page.dart').read_text(encoding='utf8')
  self.assertIn('return false;',repository)
  self.assertIn('Transfer ID reused with different money.',repository)
  self.assertNotIn("if(!accepted)throw StateError('Transfer already applied.')",page)
  self.assertIn('await widget.repository.transfer(',page)

if __name__=='__main__':unittest.main()
