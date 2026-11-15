# M954 — Default and user-defined bank SMS rule parity (Issue #661)

**Status:** code committed to existing **Draft PR #660**; no actual Android/app notification acceptance asserted. User report 2026-11-15.

## Observed gaps

1. `native/WaffraAutoSmsStore.kt` recognizes only a limited set of registration/OTP phrases. Different newly installed app code language can enter review as ordinary notices.
2. `lib/waffra_auto_sms_autopost.part.dart` previously suppressed ONLY user rules in WorkManager, and only if bank facts were uncertain; built-in default exclusion would still trigger `notifyReview` while Waffra was in background.
3. The background path used `acknowledge([id])` (queue removal) rather than durable `excludeMessages([id])`, so an already excluded SMS could reappear after rescan.
4. Android masks original verification digits before storing the encrypted review row; Dart must honor the preserved `sensitiveOtp` flag. Running literal keyword match alone on the masked text is insufficient.
5. Account/currency/posted-income/transfer evidence must NEVER be overridden by loosely matching user exclusion fragments. No general exclusion rule gets permission to post money.

## Authorized, bounded changes

- Native secure intake recognizes additional synthetic Arabic/English login verification phrases; original digits are masked **before encrypted storage** and never logged or sent to the cloud.
- The pure local rule `resolveSpecial` accepts `nativeSensitiveOtp` and uses a safety gate: do not automatically exclude if independent completed-money evidence or mixed purchase/transfer cues exist. If a known code is detected with no matching literal seed, use the already registered built-in OTP rule identity without saving an OTP-specific custom rule.
- Home full-queue compute worker and on-demand rule inspection pass the native-sensitive classification to that SAME local resolver; financial rules remain controlled by parsed, source-derived bank income/expense direction and active categories.
- WorkManager now applies the same built-in + currently readable owner rules BEFORE notifying for review; use native `excludeMessages([id])` to persist a 30-day encrypted exclusion marker. On owner rule-store failure, use only vetted built-ins and leave other records in review; never enable finance auto-post without owner-bound rules.
- Existing sender-scoped user exclusions, `matchAll` and keyword boundaries still apply. Exclude messages are not bank transactions. Transfer and ambiguous notices require explicit review. No raw SMS, bank account, or old archive is transmitted or changed.

## Cases (test/m954_all_sms_rule_routes_regression_test.dart)

| Group | Synthetic verification |
|---|---|
| New app | Arabic numeric OTP, native-masked English registration code, Arabic/English login alternatives |
| Rule priority | User sender-specific exclusion; wrong-sender refusal; default promotion and payment reminder; default plus custom simultaneously; weak bank direction must not override a safe confirmed sender rule |
| Finance safety | Completed debit + OTP retained; completed transfer + OTP retained; actual completed payment plus OTP not excluded; income + expense remain reviewable with original facts; conflicting personalized income rule cannot override source-confirmed expense |
| Unknown | Unrecognized messages remain reviewable |
| Replay | Precommitted hash takes precedence; failed native exclusion ACK restores review candidate; 30-day native excluded fingerprint survives rescan |
| Routing/privacy | WorkManager and Home use same resolver; native intake masks original security digits; no automatic money creation or account guessing |

Use the existing full Flutter + offline financial/storage CI. No synthetic host test is evidence that a new installed Android app's live SMS notifications have been accepted on a device. Real device verify: receive OTP while Home open / background / signed-in resume, complete history scan, sender-specific custom rule creation/edit/delete, force-stop/relaunch, duplicate rescan, account spending SMS with an OTP phrase, and full app notifications ordering.

**No weakening of existing finance / backup / permission / privacy tests.** Any failed test must be fixed and rerun against exact PR commit SHA before merge.
