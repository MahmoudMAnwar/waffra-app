"""M442: account-bound one-time SMS consent and truthful review states.

Source-level regression checks complement native Android instrumentation.
They do not certify real device permission behavior or SQLCipher cutover.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(file: str) -> str:
    return (ROOT / file).read_text(encoding="utf-8")


class M442SmsConsentSessionRecovery(unittest.TestCase):
    def test_suspended_session_resumes_only_same_owner(self):
        store = read("native/WaffraAutoSmsStore.kt")
        self.assertIn('private const val consentedOwnerName', store)
        self.assertIn('private const val suspendedAfterLogoutName', store)
        self.assertIn('private fun signedInOwnerHash(context: Context)', store)
        self.assertIn('MessageDigest.getInstance("SHA-256")', store)
        self.assertIn('owner != prefs.getString(consentedOwnerName, null)', store)
        self.assertIn('!prefs.getBoolean(suspendedAfterLogoutName, false)', store)
        self.assertIn('fun suspendForSignOut(context: Context)', store)
        self.assertIn('fun resumeForSameSignedInOwner(context: Context)', store)
        self.assertIn('!permissionGranted(context) || !activeProfileReady(context)', store)
        self.assertIn('editor.remove(queueName)', store)
        self.assertIn('else editor.remove(queueName)', store)
        self.assertIn('if (previous != null && previous != owner)', store)
        self.assertIn('editor.remove(queueName).remove(historyCursorAt)', store)
        self.assertIn('.putBoolean(suspendedAfterLogoutName, false)', store)
        # A device-level permission alone never enables capture.
        self.assertIn('!prefs.getBoolean(activeName, false)', store)
        self.assertIn('!activeProfileReady(context)', store)

    def test_logout_races_cannot_capture_or_hide_old_encrypted_data(self):
        store = read("native/WaffraAutoSmsStore.kt")
        activity = read("native/WaffraMainActivity.kt")
        offer = store[store.index("fun offer(context:"):
                      store.index("fun pending(context:")]
        self.assertIn("if (!enabled(context)) return@synchronized false", offer)
        self.assertIn("val result = synchronized(mutex)", offer)
        acknowledge = store[store.index("fun acknowledge(context:"):
                            store.index("fun importConsentMonth(")]
        self.assertIn("if (!enabled(context) || ids.isEmpty()", acknowledge)
        importer = store[store.index("fun importConsentMonth("):
                         store.index("fun claimReviewNotification(")]
        self.assertIn("synchronized(mutex) {", importer)
        self.assertIn("if (!enabled(context)) return accepted", importer)
        self.assertIn("if (allow && !previouslyActive)", store)
        self.assertIn("editor.remove(historyCursorAt).remove(historyCursorId)", store)
        self.assertIn("if (canResume) editor.putString(consentedOwnerName, owner)", store)
        self.assertIn("else editor.remove(queueName)", store)
        self.assertIn("if (hasReview) messageChannel?.invokeMethod", activity)

    def test_bridge_is_wired_to_native_with_no_os_reprompt_on_relogin(self):
        bridge = read("lib/waffra_auto_sms.dart")
        activity = read("native/WaffraMainActivity.kt")
        home = read("lib/main.dart")
        for name in ('autoSmsTrackingStatus', 'pauseAutoSmsForSignOut',
                     'resumeAutoSmsAfterSignIn'):
            self.assertIn(name, bridge)
            self.assertIn('"' + name + '"', activity)
        self.assertIn('WaffraAutoSmsStore.suspendForSignOut(this)', activity)
        self.assertIn('WaffraAutoSmsStore.resumeForSameSignedInOwner(this)', activity)
        self.assertIn('await WaffraAutoSms.suspendForSignOut();', home)
        self.assertIn('await WaffraAutoSms.resumeAfterSignIn();', home)
        self.assertIn('await _accountWriteAuthority.saveProfile(', home)
        self.assertIn('await _accountWriteAuthority.signOut();', home)
        self.assertIn('if(Platform.isAndroid)await WaffraAutoSms.resumeAfterSignIn();', home)
        self.assertNotIn('requestAutoSmsPermission', home[home.index('Future<void> saveUser('):
                                                            home.index('Future<void> setUiCountry(')])

    def test_dashboard_does_not_hide_disabled_or_corrupt_queue_as_zero(self):
        store = read("native/WaffraAutoSmsStore.kt")
        bridge = read("lib/waffra_auto_sms.dart")
        home = read("lib/main.dart")
        self.assertIn('fun trackingStatus(context: Context): Map<String, Boolean>', store)
        for key in ('"permissionGranted"', '"trackingRequested"', '"profileReady"',
                    '"suspendedAfterLogout"', '"historyComplete"', '"enabled"'):
            self.assertIn(key, store)
        self.assertIn('throw IllegalStateException("Encrypted SMS review queue unreadable"', store)
        self.assertIn('static Future<List<Map<String,Object?>>?> pendingChecked()', bridge)
        self.assertIn('final results=await WaffraAutoSms.pendingChecked();', home)
        self.assertIn('_autoSmsStatusProblem', home)
        self.assertIn('_autoSmsStatusChecked', home)
        self.assertIn("status['permissionGranted']!=true", home)
        self.assertIn("'صلاحية أندرويد مفعّلة، لكن متابعة الرسائل موقوفة داخل وفرة.", home)
        self.assertIn('page<4', home)
        self.assertIn("progress['historyComplete']==true", home)
        self.assertIn('!_autoSmsHistoryComplete', home)
        self.assertIn("count.toString()", home)
        self.assertIn("true // Foreground refresh will surface the read failure.", activity := read(
            "native/WaffraMainActivity.kt"))
        self.assertNotIn('commitConfirmedSms(', home[
            home.index('Future<void> _scanPreviousBankSmsFromSettings()'):
            home.index('Future<void> _openAutoSmsInbox()')])

    def test_existing_android_permission_not_misreported_as_missing(self):
        home = read("lib/main.dart")
        settings = home[home.index('Future<void> _scanPreviousBankSmsFromSettings()'):
                        home.index('Future<void> _openAutoSmsInbox()')]
        self.assertIn('if(!await WaffraAutoSms.enabled())', settings)
        self.assertIn("status?['permissionGranted']!=true", settings)
        self.assertIn('صلاحية أندرويد مفعّلة بالفعل', settings)
        self.assertNotIn('requestAutoSmsPermission', settings)
        self.assertIn('await _refreshAutoSmsInbox(importMonth:true)', settings)


if __name__ == "__main__":
    unittest.main()
