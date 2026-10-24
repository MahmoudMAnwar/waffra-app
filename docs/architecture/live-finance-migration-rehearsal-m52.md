# M52 — Locked, isolated finance migration rehearsal

Firebase is configured separately, but offline financial data migration does not depend on Firebase.

The new experimental adapter captures every recognized existing Waffra SharedPreferences finance field under the SAME native file lock used by HomeScreen and the Android quick-add widget, after recovering any interrupted M51 widget commit. It preflight-validates finances, writes one whole immutable copy into an **already opened disposable SQLCipher database**, verifies the copy on readback, then rechecks the original SharedPreferences checksum.

## Safety properties

- Zero transactions do not mean zero goals, categories, recurring data, trash, budgets, or SMS hashes.
- App identity, language, theme and non-finance preferences are never changed or copied as finance.
- Receipts are counted and flagged as **still needing file-byte migration**.
- No data are deleted from legacy storage; no activation marker is set.
- A previously used encrypted database, malformed finance input, or pending/active cutover refuses migration rather than resetting.
- The encrypted source remains disconnected from actual app UI and widget until all writers are fully routed.

## Tests

Nine tests cover empty data, full existing finance, goal-only old users, receipt detection, encrypted readback and cold reopen, bad amounts, non-destructive duplicate staging, disabled feature flag, and interrupted activation.

## Still required before real activation

Secure OS-backed key and recoverability, verified receipt bytes/backup, all app/widget/SMS/recurring paths on ONE encrypted source, crash-safe two-witness activation and rollback, Android app cold-launch and full APK acceptance tests. Firebase may remain ready in parallel. No cloud or bank-account integration is involved.
