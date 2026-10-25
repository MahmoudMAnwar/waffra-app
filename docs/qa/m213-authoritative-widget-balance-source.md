# M213 — Source-verified Home/Widget balance refresh

**Scope:** Route `widgetBalanceRefresh`, one of 24 production finance
intents. Does NOT activate SQLCipher on customer devices.

The Android home-screen widget previously used Home's in-memory
`entries` list or the Widget confirmation screen's cached merged rows
to publish a balance. Those snapshots can be stale after parallel writes,
a crash or a source cutover. In M213 both Home and Widget engines call
`WaffraVerifiedFinanceAuthority.load(route:
WaffraFinanceRoute.widgetBalanceRefresh)` and require the returned
financial read-view's integrity before computing halalas from the
verified, persisted financial ledger. Neither engine copies original
bank-SMS text or encrypted data into the widget OS summary.

The shared pure projection validates ledger shape, unique transaction
IDs, explicit income/expense booleans and finite nonnegative amounts.
A finance source/key/parse failure hides the Android widget balance:
display `***`, never a stale cached number. Widget confirmation
still reports the REAL previous save result, even when optional balance
refresh fails, and does not encourage duplicate retries.

Home's eye-toggle callback also invokes a fresh source-bound refresh
instead of using the header's stale amount. All changes are read-only
and do not modify source markers, backup archives or receipt bytes.

**QA:** fast Flutter projection tests, static binding assertions,
M147 exact-head scope review, full Flutter/Android ARM64 compilation.
The count of physical devices verified remains **zero**.
Independent live source-activation witnesses, signed installation on two
physical Android phones, 24/24 real route traces, OS-backed key recovery
and all receipt and goal migration parity are still **production NO-GO**.
