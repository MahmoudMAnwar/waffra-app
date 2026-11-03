# M417 — Optional automatic bank-SMS import (DRAFT / NO MERGE)

## Owner-approved feature
Waffra offers an explanation and a **Not now** option at the first app launch.
Only when the user taps **Allow** does Android ask for `READ_SMS` and
`RECEIVE_SMS`. An Android installation cannot display runtime permissions
before the first app launch. A denial never blocks manual transactions.

## Android processing
1. System SMS_RECEIVED messages are filtered locally for apparent financial
   activity. OTP, verification, personal phone senders and nonfinancial SMS are
   excluded. No SMS is sent to any server or generative AI provider.
2. Qualifying candidates are AES-GCM encrypted with an Android Keystore key,
   kept in private app storage with a 100-message cap. No plaintext log or
   Crashlytics/analytics events.
3. After permission is granted the user may import up to 500 newest inbox
   items (only matches are staged).
4. After standing first-run opt-in, Android WorkManager can start a short-lived Flutter finance worker while Waffra is closed. Only messages with independently checked sender, SAR amount, direction, date and category are eligible for automatic posting.
5. The existing Home/Widget locked finance authority atomically records the SMS transaction and duplicate hash; no native receiver ever writes money.
6. A budget is inherited only from a previous confirmed assignment for that merchant. Unknown assignments remain unlinked and are clearly indicated.
7. A device notification saying "saved" is triggered only after a verified ledger and SMS hash witness, not merely after detecting a message.
8. Ambiguous messages remain encrypted for review, and sign-out disables capture and clears pending ciphertext.

## Not yet equivalent to Genie
- **Fully automatic account/card creation and reconciliation are not built.**
  Sender identity by itself cannot establish bank account ownership.
- **Automatic posting is implemented as a draft candidate** using the pre-existing verified Home/Widget finance writer. Physical background execution and production security certification remain release blockers.
- Cloud-model inference is not enabled: it needs separate privacy opt-in,
  secure authenticated backend, DP policies and review.
- A first-launch prompt does not mean Google Play approval. Permission
  approval is pending, including the Google Play Permissions Declaration Form
  under SMS-based money management.
- Android permission behavior is installer/OS dependent; some side-loaded
  packages cannot receive restricted SMS permissions.

## Release blockers (all required)
- [ ] Exact-head Dart analyze and full test suite green
- [ ] Android debug and release Kotlin compile + manifest inspection
- [ ] READ_SMS / RECEIVE_SMS Play permission declaration APPROVED
- [ ] Play Data Safety and privacy notices revised; lawful Saudi privacy review
- [ ] Fresh install, denied permission, regrant, revocation and upgrade paths
- [ ] Android background and terminated-process SMS receiver tests
- [ ] OTP and personal-SMS false-positive audit with synthetic test messages
- [ ] Multi-part SMS, duplicate/restart/replay, at-rest encryption validation
- [ ] No financial record changes without verified existing commit route
- [ ] Preserve all legacy profile, SMS, manual entries, budgets and goals
- [ ] Manual + shared-text SMS paths still work; signed Android device checks
- [ ] Integration rebase with PRs #348/#349/#350/#351 and final full-suite rerun

## References
Google Play: https://support.google.com/googleplay/android-developer/answer/10208820
Google Play declaration: https://support.google.com/googleplay/android-developer/answer/9214102
Android READ_SMS: https://developer.android.com/reference/android/Manifest.permission#READ_SMS

Status: candidate code only; not a Play-ready APK. Do not merge to main.
