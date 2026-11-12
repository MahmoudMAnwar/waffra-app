# M661 — Custom Excluded SMS Rule Refresh and Honest Learning Feedback

Date: 2026-11-12
Issue: https://github.com/MahmoudMAnwar/waffra-app/issues/589
Related wider M660: https://github.com/MahmoudMAnwar/waffra-app/issues/588
PR: https://github.com/MahmoudMAnwar/waffra-app/pull/590
Status: **Code committed; exact-head CI and real-device acceptance pending**

## Reported real-phone discrepancy
1. Exclude one SMS from a family; similar still-pending SMS survive a refresh.
2. Save a separate manual `مستبعدة` rule and refresh; owner sees identical-looking candidate messages still in review.
3. The existing message-exclusion success snackbar cannot distinguish single-ID exclusion from reusable learning. No on-device diagnostic indicates a manually saved keyword was applied, mismatched, or unavailable.

## Source-level root causes
- `WaffraSmsLocalRules.suggestedRule(kind:'excluded')` only learns fixed verification terms. This is **M660 future template-learning scope**; it cannot learn `تمت إضافة المستفيد` today.
- Saved manual `+ Add rule` returns no `true` flag to the calling Home route; thus `_openSmsRules` doesn't invoke the prior queued-SMS refresh for normal seedless rules.
- Sender-scoped custom rule preview looked up sender as `''` for queued samples, falsely showing zero matches.
- Failed encrypted rule reads were ignored, leaving saved owner rules non-operational with no user notice.

## Implemented M661 hotfix in Draft PR #590
- `WaffraSmsRuleSettingsPage.onRulesChanged` called only after durable encrypted store write, for add/edit/remove, including seedless manual `+ Add rule`.
- Home reuses existing 900ms debounced `_receiveAutoSmsNotice` -> `_refreshAutoSmsInbox` -> pure isolate `waffraM632ClassifySmsQueue`, with a bounded native `excludeMessages` ACK for truly matching, nonfinancial custom exclusions.
- Match previews pair actual queued body/sender by index, not senderless text; information stays in memory, no additional persisted PII.
- If encrypted owner rule load fails, one explicit warning says custom exclusions are not active; built-in suggestions remain available and no falsely successful custom application is claimed.
- Single-SMS exclusion success differentiates learned sender rule from single-ID exclusion. The user can see why subsequent similar SMS do not disappear with the unchanged current limited learner.
- **Not included:** broader message-fragment and event-family learning for all four types (#588); no new auto finance write, cloud call, history rescan, or sender-wide exclusion.

## Source safety
- `lib/waffra_sms_local_rules.dart` remains unchanged: `resolveSpecial` disallows excluded rules for known completed income, expense and transfer.
- The native owner-scoped encrypted SMS fingerprint remains durable across rescan, separate from 30-day recoverable labels.
- Existing SQLCipher finance, transfer anti-double-charge, account-linking and 30-day lifecycle remain unchanged.

## Required checks
- New `test/m661_exclusion_rule_apply_regression_test.dart` covers manually saved sender-scoped nonfinancial beneficiary addition, second beneficiary name, mismatch sender, actual transfer negative, explicit M660 unimplemented boundary, source callback after write, sender-accurate preview, visible vault error, and native ACK worker safety.
- Run full Flutter tests, strict analyzer warnings/errors, M385 source scopes, M550 behavior contract, M449 release-note ancestry, SMS/Android finance emulator and PR exact-head gates.
- **Real device not verified.** The user must install the APK produced from main *after* this PR merges, confirm custom rule save -> already pending matching SMS disappear without historical scan -> future same-sender messages stay excluded. Old device builds and GitHub PR source tests are not proof.
