# M177 — close live Home auxiliary legacy-writer bypasses

M176 merged into main on `0af5716a26cf57f858b83fec6bcca13081f7f97b`
with all 15 PR checks passing. This PR removes direct HomeScreen access to
`_homeFinancePersistence.withLegacyWriter`, and routes the four auxiliary
storage families through `WaffraVerifiedFinanceAuthority`.

- **Catalog v2/v3:** explicit `categoryCatalogInstall` intent; compare the
  exact loaded categories against the current source under the native
  cross-engine writer lock before replacing categories, then write the
  installation marker last. Conflicts fail closed rather than overwrite.
- **SMS hashes:** `merchantRulesAndSmsHashes` intent; legacy set union under
  native lock preserves hashes written by the widget. The encrypted branch
  uses the already-present `addSmsHashes` SQL bridge only when all runtime
  evidence is independently valid.
- **Recurring reminders:** source-guarded legacy preference write; encrypted
  writes fail closed until their own SQL projection writer is certified.
- **Custom goal suggestions:** source-guarded read and write; encrypted reads
  and writes fail closed pending a verified SQL model for the custom list.

## Production state

**NO-GO.** No source markers, user data, keys, vaults, Firebase, Play signing,
backup archives, or production cutover are touched. The main app and widget
continue to use the guarded legacy source. CI uses synthetic data only.

The existing catalog flag remains separate from its category JSON in
SharedPreferences, so this is NOT an atomic SQL catalog migration. On a
partial legacy install, writing the flag last allows retry, and the stale
source check prevents concurrent overwrite. Actual SQL source cutover still
requires an independent crash-safe catalog transaction.

24/24 independently attested live routes, key-loss recovery, receipt
rollback, encrypted backup restoration on two real devices, physical-device
signing, privacy/Data Safety and human release approval remain required.
