# M1003 / Issue #715 — root-cause review

Screenshot message originates in `lib/waffra_home_entry_sheet.part.dart`. The editor first changes ledger metadata then independently calls `linkUnassignedEntry`. For a nonzero-opening-balance account, `WaffraAccountContextRead.attachPreviouslyUnassigned` refuses the link without `openingExcludesHistory` confirmation; this editor omitted that confirmation while the account reconciliation UI had it. The new flow must ask before saving and commit metadata/budget plus account attribution in one verified SQLCipher transaction. No duplicate transaction or guessed account.

Potential black/blank routes: Home `ready=false` renders `SizedBox.shrink` while root may have revealed the screen; root `Stack` can have no visible authentication stage while waiting for a verified Home. Provide a private, nonfinancial safe status in these exceptional conditions. Preserve prior stage and biometric gate. These are source hazards, not proven physical crash sites.

Regressions: explicit cancel/unchecked attestation no changes; checked history+budget link atomic; stale source/missing account rollback; exactly one stored entry; no fake money; no blank Home recovery or missing root stage. CI and restored old backup on physical Android still pending.
