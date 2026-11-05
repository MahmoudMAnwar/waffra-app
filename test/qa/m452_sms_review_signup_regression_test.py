"""M452: single-page registration, secure SMS session and collapsed review accordion.

Static checks are additional guard rails, not a substitute for Flutter
analyze, widget tests or signed-device permission coverage.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class M452ReviewAndRegistration(unittest.TestCase):
    def test_sms_review_is_collapsible_and_count_remains_visible(self):
        home = source("lib/main.dart")
        card = home.split(" Widget _autoSmsReviewCard(){", 1)[1].split(
            " Future<void> _reviewAutoSmsCandidates(", 1)[0]
        self.assertIn("bool _autoSmsReviewExpanded=false;", home)
        self.assertIn("waffra-auto-sms-review-expand", card)
        self.assertIn("waffra-auto-sms-review-count", card)
        self.assertLess(card.index("waffra-auto-sms-review-count"),
                        card.index("if(_autoSmsReviewExpanded)Padding("))
        self.assertIn("waffra-auto-sms-review-open", card)
        self.assertIn("waffra-auto-sms-review-refresh", card)
        self.assertIn("_refreshAutoSmsInbox(importMonth:true)", card)
        self.assertIn("_autoSmsReviewExpanded=!_autoSmsReviewExpanded", card)

    def test_registration_has_single_submit_and_avatar_choices(self):
        home = source("lib/main.dart")
        registration = home.split(" Widget _phoneRegistrationForm(){", 1)[1].split(
            " @override Widget build(BuildContext context){", 1)[0]
        for key in ("waffra-register-single-page", "waffra-register-name",
                    "waffra-register-gender-male",
                    "waffra-register-gender-female",
                    "waffra-register-phone", "waffra-register-password",
                    "waffra-register-confirm-password", "waffra-register-submit"):
            self.assertIn(key, registration)
        self.assertIn("saudiAvatar(g,radius:21)", registration)
        self.assertNotIn("_registrationDetailsStep", home)
        self.assertNotIn("_nextPhoneRegistrationStep", home)

    def test_sms_owner_not_locked_to_old_onboarding_boolean(self):
        store = source("native/WaffraAutoSmsStore.kt")
        segment = store.split("private fun activeProfileReady(context: Context)", 1)[1].split(
            "fun enabled(context: Context)", 1)[0]
        self.assertIn("signedInOwnerHash(context) != null", segment)
        self.assertNotIn("waffra_onboarding_completed", store.split(
            "private fun signedInOwnerHash(context: Context)", 1)[1].split(
            "fun enabled(context: Context)", 1)[0])
        self.assertIn("owner != prefs.getString(consentedOwnerName, null)", store)
        self.assertIn("!permissionGranted(context)", store)


    def test_local_rule_store_owner_guard_is_unique(self):
        rules = source("lib/waffra_sms_local_rules.dart")
        self.assertEqual(rules.count("Future<List<WaffraSmsLocalRule>> read("), 1)
        self.assertEqual(rules.count("Future<void> write("), 1)
        self.assertEqual(rules.count("String _key(String owner)"), 1)
        self.assertIn("RegExp(r'^[a-f0-9]{64}
        self.assertNotIn(").hasMatch(owner)){\n   throw", rules.split("Future<void> write(", 1)[1])


if __name__ == "__main__":
    unittest.main()
).hasMatch(owner)", rules)
        self.assertNotIn(").hasMatch(owner)){\n   throw", rules.split("Future<void> write(", 1)[1])


if __name__ == "__main__":
    unittest.main()
