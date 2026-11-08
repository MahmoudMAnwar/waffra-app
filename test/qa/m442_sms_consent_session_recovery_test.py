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
        # M470 also removes the old owner's encrypted blocked-sender policy.
        # All these removals share the same preferences editor/commit.
        self.assertIn('if (previous != null && previous != owner)', store)
        self.assertIn(
            'editor.remove(queueName).remove(excludedSendersName).remove(historyCursorAt)',
            store)
        self.assertIn('.remove(historyCursorId).remove(historySourceMonth)', store)
        self.assertIn('.remove(historyScannedCount).remove(historyAddedCount)', store)
        self.assertIn('.putBoolean(suspendedAfterLogoutName, false)', store)
        # A device-level permission alone never enables capture.
        self.assertIn('!prefs.getBoolean(activeName, false)', store)
        self.assertIn('!activeProfileReady(context)', store)

    def test_logout_races_cannot_capture_or_hide_old_encrypted_data(self):
        store = read("native/WaffraAutoSmsStore.kt")
        activity = read("native/WaffraMainActivity.kt")
        offer = store[store.index("fun offer(context:"):
                      store.index("fun pending(context:")]
        # First reject unauthorized sessions and excluded senders before
        # parsing; re-check BOTH under the mutex before the encrypted write.
        self.assertIn('if (!enabled(context)) return false', offer)
        self.assertIn(
            'if (synchronized(mutex) { isExcludedLocked(context, sender) }) return false',
            offer)
        self.assertIn('val result = synchronized(mutex)', offer)
        self.assertIn('if (!enabled(context) || isExcludedLocked(context, sender))', offer)
        self.assertIn('return@synchronized false', offer)
        self.assertLess(offer.index('if (!enabled(context) || isExcludedLocked'),
                        offer.index('val queue = read(context)'))
        acknowledge = store[store.index("fun acknowledge(context:"):
                            store.index("fun importConsentMonth(")]
        self.assertIn("if (!enabled(context) || ids.isEmpty()", acknowledge)
        importer = store[store.index("fun importConsentMonth("):
                         store.index("fun claimReviewNotification(")]
        self.assertIn("synchronized(mutex) {", importer)
        # M547 scans the provider outside the lock, but refuses to persist
        # either owner-mismatched rows or their cursor once logout wins.
        self.assertIn("ownerAtStart != signedInOwnerHash(context)", importer)
        self.assertIn("return@synchronized 0", importer)
        self.assertLess(importer.index("ownerAtStart != signedInOwnerHash(context)"),
                        importer.index("val queue = read(context)"))
        self.assertIn("if (!editor.commit()) return@synchronized 0", importer)
        self.assertIn("if (allow && !previouslyActive)", store)
        self.assertIn("editor.remove(historyCursorAt).remove(historyCursorId)", store)
        self.assertIn("if (canResume) editor.putString(consentedOwnerName, owner)", store)
        self.assertIn("else editor.remove(queueName)", store)
        # The resumed Activity notifies Flutter only when pending encrypted
        # messages exist (or ciphertext is unreadable). Android UI dispatch
        # runs after the background executor, so matching the old adjacent
        # one-line expression would reject the correct race-safe behavior.
        on_resume = activity[activity.index('override fun onResume()'):
                             activity.index('override fun onRequestPermissionsResult(')]
        self.assertIn('smsHistoryExecutor.execute {', on_resume)
        self.assertIn('if (hasReview) runOnUiThread {', on_resume)
        self.assertIn('messageChannel?.invokeMethod("autoSmsAvailable", null)', on_resume)
        self.assertLess(on_resume.index('smsHistoryExecutor.execute {'),
                        on_resume.index('if (hasReview) runOnUiThread {'))
        self.assertLess(on_resume.index('if (hasReview) runOnUiThread {'),
                        on_resume.index('messageChannel?.invokeMethod("autoSmsAvailable", null)'))

    def test_bridge_is_wired_to_native_with_no_os_reprompt_on_relogin(self):
        bridge = read("lib/waffra_auto_sms.dart")
        activity = read("native/WaffraMainActivity.kt")
        home = read("lib/main.dart")
        for name in ('autoSmsTrackingStatus', 'pauseAutoSmsForSignOut',
                     'resumeAutoSmsAfterSignIn'):
            self.assertIn(name, bridge)
            self.assertIn('"' + name + '"', activity)
        # M603: encrypted SMS suspension must not block Android's UI thread.
        # Preserve the signed-out safety barrier and return the real worker result.
        pause = activity.split('"pauseAutoSmsForSignOut" -> {', 1)[1].split(
            '"resumeAutoSmsAfterSignIn" -> {', 1)[0]
        self.assertIn('val app = applicationContext', pause)
        self.assertIn('smsHistoryExecutor.execute {', pause)
        self.assertIn('WaffraAutoSmsStore.suspendForSignOut(app)', pause)
        self.assertIn('runOnUiThread { result.success(paused) }', pause)
        self.assertIn('result.error("SMS_SIGNOUT_UNAVAILABLE"', pause)
        self.assertLess(pause.index('smsHistoryExecutor.execute {'),
                        pause.index('WaffraAutoSmsStore.suspendForSignOut(app)'))
        self.assertNotIn('WaffraAutoSmsStore.suspendForSignOut(this)', pause)
        self.assertIn('WaffraAutoSmsStore.resumeForSameSignedInOwner(app)', activity)
        # M547: verified same-owner resume waits for SMS mutex/commits only
        # on the serialized SMS executor, never the Android UI thread.
        resume = activity.split('"resumeAutoSmsAfterSignIn" -> {', 1)[1].split(
            '"autoSmsNotificationsEnabled"', 1)[0]
        self.assertIn('val app = applicationContext', resume)
        self.assertIn('smsHistoryExecutor.execute {', resume)
        self.assertIn('runOnUiThread { result.success(resumed) }', resume)
        # The bounded native SMS pause must fail closed on timeout instead of
        # leaving logout apparently unresponsive; preserve native-first order.
        self.assertIn('WaffraAutoSms.suspendForSignOut().timeout(', home)
        self.assertIn('const Duration(seconds:12),onTimeout:()=>false', home)
        self.assertLess(home.index('WaffraAutoSms.suspendForSignOut().timeout('),
                        home.index('await _accountWriteAuthority.signOut();'))
        self.assertIn('await WaffraAutoSms.resumeAfterSignIn();', home)
        self.assertIn('await _accountWriteAuthority.saveProfile(', home)
        self.assertIn('await _accountWriteAuthority.signOut();', home)
        # M603: verified SMS resume is now scheduled only after Home paint;
        # no synchronous wait on the login/navigation critical path.
        save_user = home[home.index(' Future<void> saveUser(Person u)async {'):
                         home.index(' Future<void> setUiCountry(')]
        self.assertIn('await _accountWriteAuthority.saveProfile(', save_user)
        self.assertIn('if(Platform.isAndroid&&mounted){', save_user)
        self.assertIn('WidgetsBinding.instance.addPostFrameCallback((_){', save_user)
        self.assertIn('if(!mounted||profile==null||showLogin)return;', save_user)
        self.assertIn('unawaited(()async{', save_user)
        self.assertIn('final resumed=await WaffraAutoSms.resumeAfterSignIn();', save_user)
        self.assertIn('if(resumed&&mounted&&!showLogin&&identical(profile,u)){', save_user)
        self.assertLess(save_user.index('await _accountWriteAuthority.saveProfile('),
                        save_user.index('WidgetsBinding.instance.addPostFrameCallback((_){'))
        self.assertLess(save_user.index('WidgetsBinding.instance.addPostFrameCallback((_){'),
                        save_user.index('final resumed=await WaffraAutoSms.resumeAfterSignIn();'))
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
        activity = read("native/WaffraMainActivity.kt")
        # The encrypted SMS queue is now read on a dedicated worker so
        # Activity.onResume never blocks Android UI or turns corruption into 0.
        on_resume = activity[activity.index('override fun onResume()'):
                             activity.index('override fun onRequestPermissionsResult(')]
        self.assertIn('smsHistoryExecutor.execute {', on_resume)
        self.assertIn('WaffraAutoSmsStore.pending(app).isNotEmpty()', on_resume)
        self.assertIn('true // Flutter review reports the actual queue error.', on_resume)
        self.assertIn('if (hasReview) runOnUiThread {', on_resume)
        self.assertIn('messageChannel?.invokeMethod("autoSmsAvailable", null)', on_resume)
        self.assertNotIn('false // Encrypted queue unreadable', on_resume)
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
