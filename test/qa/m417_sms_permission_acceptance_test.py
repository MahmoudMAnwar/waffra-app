import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

class M417AutoSmsContractTest(unittest.TestCase):
    def read(self,path):
        return (ROOT/path).read_text(encoding="utf-8")

    def test_android_permission_requires_explicit_user_action(self):
        flutter=self.read("lib/waffra_auto_sms.dart")
        consent=self.read("lib/waffra_auto_sms_consent.dart")
        native=self.read("native/WaffraMainActivity.kt")
        self.assertIn("requestAutoSmsPermission",flutter)
        self.assertIn("m417-permission-allow",consent)
        self.assertIn("m417-permission-skip",consent)
        self.assertIn("requestPermissions(arrayOf(Manifest.permission.READ_SMS",native)
        self.assertIn("WaffraAutoSmsStore.permissionGranted",native)

    def test_background_cannot_post_finance_or_upload_sms(self):
        receiver=self.read("native/WaffraAutoSmsReceiver.kt")
        queue=self.read("native/WaffraAutoSmsStore.kt")
        self.assertIn("SMS_RECEIVED_ACTION",receiver)
        self.assertIn("AndroidKeyStore",queue)
        self.assertIn("AES/GCM/NoPadding",queue)
        self.assertIn("qualifies(sender, body)",queue)
        self.assertIn("otp.containsMatchIn(safe)",queue)
        self.assertIn("maxCandidates = 100",queue)
        for forbidden in ("FirebaseFirestore", "HttpURLConnection", "OkHttpClient"):
            self.assertNotIn(forbidden,receiver+queue)
        self.assertNotIn("commitConfirmedSms",receiver+queue)

    def test_writes_only_from_existing_verified_sms_review(self):
        home=self.read("lib/main.dart")
        self.assertIn("bulkSmsSheet(initialText:body)",home)
        self.assertIn("smsHashes.contains(bankSmsHash(body))",home)
        self.assertIn("await WaffraAutoSms.acknowledge([id])",home)
        self.assertIn("await WaffraAutoSms.disable();",home)

    def test_android_build_uses_explicit_scoped_receiver(self):
        for path in (".github/workflows/android.yml",
                     ".github/workflows/android-full-smoke.yml"):
            script=self.read(path)
            self.assertIn("WaffraAutoSmsReceiver.kt",script)
            self.assertIn("WaffraAutoSmsStore.kt",script)
            self.assertIn('android.permission.BROADCAST_SMS',script)
            self.assertIn("READ_SMS",script)
            self.assertIn("RECEIVE_SMS",script)
            self.assertNotIn("android.permission.SEND_SMS",script)

if __name__=="__main__":
    unittest.main()
