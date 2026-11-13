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
        self.assertIn("_requestPermissions()",consent)
        self.assertIn("await WaffraAutoSms.optIn()",consent)
        self.assertNotIn("allow(cloud:true)",consent)
        self.assertIn("requestPermissions(arrayOf(Manifest.permission.READ_SMS",native)
        self.assertIn("WaffraAutoSmsStore.permissionGranted",native)

    def test_background_cannot_post_finance_or_upload_sms(self):
        receiver=self.read("native/WaffraAutoSmsReceiver.kt")
        queue=self.read("native/WaffraAutoSmsStore.kt")
        self.assertIn("SMS_RECEIVED_ACTION",receiver)
        self.assertIn("AndroidKeyStore",queue)
        self.assertIn("AES/GCM/NoPadding",queue)
        # M549: every sender's SMS may enter the review-only queue. Bank
        # heuristics no longer limit native intake; finance authority is
        # still a separate user-confirmed, deduplicated SQLCipher write.
        self.assertIn("if (!reviewEligible(sender, body)) return false",queue)
        self.assertIn("reviewEligible(row.sender, row.body)",queue)
        self.assertIn("isCommittedLocked(context, fingerprint)",queue)
        self.assertIn("isExcludedMessageLocked(context, fingerprint)",queue)
        self.assertIn("otp.containsMatchIn(safe)",queue)
        self.assertIn("maxCandidates = 1000",queue)
        for forbidden in ("FirebaseFirestore", "HttpURLConnection", "OkHttpClient"):
            self.assertNotIn(forbidden,receiver+queue)
        self.assertNotIn("commitConfirmedSms",receiver+queue)

    def test_writes_only_from_existing_verified_sms_review(self):
        home=self.read("lib/main.dart")
        # M704: this used, same-library transfer method was extracted
        # byte-identically. Reconstruct the source at its original anchor
        # so every existing money/ACK/fee assertion remains unchanged.
        transfer_part=self.read("lib/waffra_home_sms_transfer_review.part.dart")
        marker=" // M703: implementation moved byte-identically to registered Home part."
        self.assertIn(marker,home)
        self.assertIn("part 'waffra_home_sms_transfer_review.part.dart';",home)
        home=home.replace(marker,transfer_part,1)
        home+=self.read("lib/waffra_home_profile.part.dart")
        self.assertIn("await entrySheet(sms:true,initialSms:body,reviewedSender:sender);",home)
        self.assertIn("smsHashes.contains(bankSmsHash(body))",home)
        # Income/expense and two-sided transfers have independent durable
        # acknowledgements. A queue-only ACK can replay money on rescan.
        self.assertIn(
            "final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);",
            home)
        self.assertIn(
            "ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id]);",
            home)
        transfer=home[home.index(" Future<void> _reviewSmsAccountTransfer({"):
                      home.index(" Future<void> _reviewAutoSmsCandidates({")]
        self.assertIn("requestId:WaffraAutoSms.transferIdForMessage(id)",transfer)
        self.assertIn("if(!mounted||!saved)return;",transfer)
        self.assertLess(
            transfer.index("await api.transfer("),
            transfer.index(
                "ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id]);"))
        self.assertNotIn("await WaffraAutoSms.acknowledge([id])",home)
        self.assertIn("await WaffraAutoSms.disable();",home)

    def test_auto_posting_requires_guarded_finance_and_verified_notification(self):
        app=self.read("lib/waffra_auto_sms_autopost.part.dart")
        classifier=self.read("lib/waffra_auto_sms_policy.dart")
        notification=self.read("native/WaffraAutoSmsNotifications.kt")
        worker=self.read("native/WaffraAutoSmsWorker.kt")
        self.assertIn("WaffraAutoSmsPolicy.decide",app)
        self.assertIn("WaffraProductionFinanceAuthorityBinding.bind",app)
        self.assertIn("commitConfirmedSms(",app)
        self.assertIn("allowDuplicateHashes:false",app)
        self.assertIn("committed.saved==1&&persisted",app)
        self.assertIn("await WaffraAutoSms.notifyCommitted",app)
        self.assertLess(app.index("committed.saved==1&&persisted"),
                        app.index("await WaffraAutoSms.notifyCommitted"))
        self.assertIn("WaffraSmsIntelligence.isPendingOrUnconfirmed",classifier)
        self.assertIn("NotificationCompat.VISIBILITY_PRIVATE",notification)
        self.assertIn("WorkManager.getInstance",worker)
        self.assertIn("waffraAutoSmsBackgroundEntrypoint",worker)
        self.assertIn("setExpedited",worker)
        self.assertNotIn("FirebaseFirestore",worker)

    def test_sms_permission_disclosure_is_review_only(self):
        ui=self.read("lib/waffra_auto_sms_consent.dart")
        # Account creation is followed by Android SMS then notifications.
        # Cloud disclosure must be separate and tied to a specific message.
        self.assertIn("await prefs.remove('waffra_cloud_sms_installation_consent_v2');",ui)
        self.assertNotIn("waffra_sms_cloud_service.dart",ui)
        self.assertIn("await WaffraAutoSms.optIn()",ui)
        self.assertIn("await WaffraAutoSms.requestNotificationPermission()",ui)
        self.assertNotIn("allow(cloud:true)",ui)
        # History starts at the activation month's first day, independent
        # of UI text length. Verify the native boundary is unchanged.
        store=self.read("native/WaffraAutoSmsStore.kt")
        api=self.read("lib/waffra_auto_sms.dart")
        self.assertIn("set(Calendar.DAY_OF_MONTH, 1)",store)
        self.assertIn("importConsentMonthBankSms",api)
        poster=self.read("lib/waffra_auto_sms_autopost.part.dart")
        self.assertIn("static bool get reviewOnly => false;",poster)
        self.assertIn("!matched.autoPost",poster)
        self.assertIn("matched.accountSuffix",poster)
        self.assertIn("sourceAccountVerified:true",poster)
        self.assertLess(poster.index("!matched.autoPost"),
                        poster.index("commitConfirmedSms("))

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
