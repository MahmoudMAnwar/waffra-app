# M1003 / Issue #715 — root-cause review

Screenshot message originates in `lib/waffra_home_entry_sheet.part.dart`. The editor first changes ledger metadata then independently calls `linkUnassignedEntry`. For a nonzero-opening-balance account, `WaffraAccountContextRead.attachPreviouslyUnassigned` refuses the link without `openingExcludesHistory` confirmation; this editor omitted that confirmation while the account reconciliation UI had it. The new flow must ask before saving and commit metadata/budget plus account attribution in one verified SQLCipher transaction. No duplicate transaction or guessed account.

Potential black/blank routes: Home `ready=false` renders `SizedBox.shrink` while root may have revealed the screen; root `Stack` can have no visible authentication stage while waiting for a verified Home. Provide a private, nonfinancial safe status in these exceptional conditions. Preserve prior stage and biometric gate. These are source hazards, not proven physical crash sites.

Regressions: explicit cancel/unchecked attestation no changes; checked history+budget link atomic; stale source/missing account rollback; exactly one stored entry; no fake money; no blank Home recovery or missing root stage. CI and restored old backup on physical Android still pending.

## M1006 — concrete post-restore visual path, 2026-11-16

**Code trace (confirmed):** `lib/waffra_home_account_tools.part.dart` sets `sqlcipherRestoreCommitted=true` then `restoreStage='HOME_REFRESH'` and awaits `_loadFinanceSafely()`. The latter unconditionally sets `ready=false`, clears the presentation and handles its own errors by storing `_financeLoadFailure` rather than rethrowing. Before M1003 the Home shell was zero-size, so the existing dark blur/dialog barrier revealed a near-black blank background. M1003 supplies a green full-screen safe placeholder, but forest #064D3B can still appear black under the dialog barrier; M1006 uses illuminated sand #F8F6EF and subtle progress instead.

**Safety-critical completion gate:** after `await _loadFinanceSafely()`, check `ready==true && _financeLoadFailure==null` before declaring restore/home parity and closing the dialog. A recovered committed-but-not-loaded archive stays committed; tell user to preserve rescue and retry the verified source, not to reapply or delete financial entries. Never show pre-restore balances or fabricate successful home data.

**Distinct uncertainty:** The exact physical handset rendering is unobserved; image colors/frames must be checked on Android with the user's real historical archive. The code path and hidden failure success condition are independently verifiable.
