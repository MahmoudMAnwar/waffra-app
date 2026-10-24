# M181 — real encrypted finance route implementations and 24-route gap matrix

**Not production certified.** This change adds actual source-guarded SQLCipher
writes, plus runnable negative tests. It does NOT claim that enumerating all
24 routes is proof of 24 live app/widget routes.

## Actual source changes (experimental encrypted branch only)

1. **categoryCatalogInstall** — v2/v3 install CAS-checks the exact current
   snapshot *inside* Home/Widget native writer lock. Typed category projection,
   canonical encrypted snapshot and the version marker in
   `fresh_finance_settings` commit as **one SQL transaction**. Crash rolls
   back both. Already installed versions cannot silently rerun.
2. **manualTransactionSave** — extract exactly ONE new, unmodified transaction
   from Home's captured list; reject coupled edits. Delegate to the existing
   SQLCipher unified confirmed entry writer, which atomically persists the
   normalized SQL ledger and financial snapshot under the same native lock.
   A concurrent Widget hash or transaction is preserved.
3. **challengeAndBudgetUpdate** — constrain to budget scalar, challenge and
   category-budget fields; rely on snapshot CAS and the existing typed
   category projection.
4. **recurringPostingAndPostponement** — only the *postponement-only* finance
   map is allowed via atomic snapshot CAS. Adding a recurring payment with it
   still fails until a dedicated combined transactional writer exists.
5. **merchantRulesAndSmsHashes** — strictly constrain the learned merchant
   mapping update; the separate verified SHA-256 hash merge remains intact.
6. **deleteAllTransactions** — permit a strictly scoped, explicitly approved
   SQLCipher ledger+hash reset **only when there are no receipt blobs, archives,
   orphan receipts or ambiguous SQL/snapshot records**. Reject stale screen
   witnesses and any simultaneous Widget edits. This remains unavailable for
   receipt-bearing finance until independently reviewed retention semantics.

## Every currently defined route (24)

| Route | What current candidate can do | Remaining independent evidence |
|---|---|---|
| appStartup | Source guard, legacy active | Native encrypted source activation/recovery startup |
| widgetStartup | Source guard, legacy active | Independent Widget encrypted source startup |
| dashboardRead | Encrypted read API exists | Live Home installation and physical-device proof |
| widgetRead | Encrypted read API exists | Live Widget installation and physical-device proof |
| manualTransactionSave | **M181** typed atomic manual append | Live activated source + Android evidence |
| bulkSmsConfirmedSave | Atomic SQLCipher writer candidate | 100-SMS actual live Android and recovery |
| widgetSmsConfirmedSave | Atomic SQLCipher writer candidate | Standalone widget live encrypted source |
| transactionEdit | Existing typed projection for safe edits | Receipt/SMS attached edit parity |
| transactionDeleteAndUndo | Blocked for encrypted | 30-day retention + receipt undo atomicity |
| deleteAllTransactions | **M181** receipt-free only | Receipt-bearing deletion/retention parity |
| categoryCatalogInstall | **M181** v2/v3 typed CAS+marker | Startup cutover/restore parity |
| categoryCreateEditDeleteRestore | Typed create/edit candidate | Recycle/restore/permanent delete projector |
| goalCreateEditDeleteRestore | Typed create/edit candidate | Recycle/restore/permanent delete projector |
| recurringCreateEditDeleteRestore | Typed create/edit + M179 scalar candidate | Recycle/restore/permanent delete projector |
| recurringPostingAndPostponement | **M181** postponement only | Atomic payment+postponement writer |
| challengeAndBudgetUpdate | **M181** scalar/budget CAS | Real-device routes and analytics parity |
| merchantRulesAndSmsHashes | Existing hash merge + **M181** merchant map | Actual Home/Widget source consistency |
| receiptCopyAndAttach | Existing verified encrypted receipt candidate | Live picker bytes + receipt cold reopen |
| receiptView | Existing encrypted BLOB reader candidate | Live viewer and device restart evidence |
| receiptRemoveAndRollback | Existing receipt recycle candidate | Full retention/expiry and device evidence |
| widgetBalanceRefresh | Existing Widget refresh | Balance source must read actual SQL witness |
| backupExport | M177 live source-read; encrypted portable exporter candidate | Real portable export from activated source |
| backupRestore | Experimental empty-vault restorer | Live source-gated restore and recovery |
| fullFinanceReset | Blocked for encrypted | Authenticated full reset with receipt/key cleanup |

**24/24 independently certified: NO.** UI still constructs a default
`WaffraVerifiedFinanceAuthority` without an active encrypted session.
The production guard still reports `all_live_writers_not_yet_routed`; the
release gate's `automaticallyActivateSqlCipher` is **false**.

## Negative tests / no fake evidence

M181 uses synthetic, disposable SQLCipher vaults with test-only source
witnesses. Tests require version CAS, typed row parity, SQL rollback, exact
manual append, duplicate/stale rejection, retention-safe clear with explicit
consent, and preservation of unrelated Widget hashes. They do **not** prove
OS-backed keys, two real phones, signed Play build, account deletion, real
backup restore or production privacy.

## Next source-gated implementation

Prioritize atomic recurring payment+postponement; then cross-entity recycle,
receipt-backed delete/undo, encrypted backup restore into verified sources,
full reset, real Widget startup/refresh. Require independent tests for each
before creating verified route witnesses.

No actual user data, source markers, Firebase, Play publishing or production
SQLCipher were modified.
