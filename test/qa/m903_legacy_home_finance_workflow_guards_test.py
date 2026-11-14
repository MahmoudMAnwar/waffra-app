"""M903: legacy M155/M158 CI must inspect original registered production Home parts."""
from pathlib import Path
import unittest

from waffra_home_source import read_waffra_home_source

ROOT = Path(__file__).resolve().parents[2]


def workflow(path: str) -> str:
    return (ROOT / ".github/workflows" / path).read_text(encoding="utf-8")


class M903OriginalWorkflowSourceGuards(unittest.TestCase):
    def test_m155_encrypted_sms_and_backup_assertions_remain_mandatory(self):
        src = workflow("m155-approved-features-finance-reconcile.yml")
        block = src.split("      - name: Fail closed on source authority or privacy regression", 1)[1]
        self.assertIn("from waffra_home_source import read_waffra_home_source", block)
        self.assertIn("app=read_waffra_home_source()", block)
        self.assertNotIn("app=Path('lib/main.dart').read_text()", block)
        for original in (
            "assert '_financeAuthority.commitConfirmedSms' in app",
            "assert '_financeAuthority.saveCaptured' in app",
            "assert 'WaffraBackupFiles.saveEncryptedArchive' in app",
            "assert 'WaffraBackupFiles.openArchive' in app",
            "assert 'Clipboard.setData(ClipboardData(text:encrypted))' not in app",
            "assert 'Intent.ACTION_CREATE_DOCUMENT' in native",
            "assert 'Intent.ACTION_OPEN_DOCUMENT' in native",
            "assert 'argon2id' in backup and 'pbkdf2-sha256' in backup",
        ):
            self.assertIn(original, block)

    def test_m158_original_sms_widget_privacy_dedupe_assertions_remain(self):
        src = workflow("m158-widget-sms-title-privacy.yml")
        block = src.split("      - name: Reject raw bank SMS in Widget ledger titles", 1)[1]
        self.assertIn("from waffra_home_source import read_waffra_home_source", block)
        self.assertIn("home=read_waffra_home_source()", block)
        self.assertNotIn("home=Path('lib/main.dart').read_text()", block)
        for original in (
            "assert not Path('lib/waffra_widget_capture.part.dart').exists()",
            "assert 'Intent(context, MainActivity::class.java)' in widget",
            """assert 'action = "waffra.ADD_TRANSACTION"' in widget""",
            "assert 'PendingIntent.FLAG_IMMUTABLE' in widget",
            "assert 'entry.raw.replaceAll' not in widget",
            "assert 'waffraWidgetAction' in bridge",
            "assert 'WaffraAutoSms.acknowledgeCommitted([id])' in home",
        ):
            self.assertIn(original, block)
        self.assertIn("if(!mounted||!ready||waffraWidgetAction.value!='add')return;", block)

    def test_original_production_source_contains_all_required_live_witnesses(self):
        app = read_waffra_home_source(ROOT)
        for witness in (
            "_financeAuthority.commitConfirmedSms",
            "_financeAuthority.saveCaptured",
            "WaffraBackupFiles.saveEncryptedArchive",
            "WaffraBackupFiles.openArchive",
            "WaffraAutoSms.acknowledgeCommitted([id])",
        ):
            self.assertIn(witness, app)


if __name__ == "__main__":
    unittest.main()
