# M61 — Witness-verified encrypted finance runtime bridge (experimental)

## Scope

M61 adds a single source-checked SQLCipher finance interface to be shared in
a future Waffra HomeScreen/Android quick-add integration. It does **not**
activate encrypted storage in `main.dart` or migrate a real installation.

The same `.waffra-writer.lock` and local per-process queue protect two flows:

1. Home reads receive a full immutable encrypted snapshot and generation
   witness. Screen edits use the originally loaded baseline, patch only changed
   finance keys and fail closed on a same-field concurrent update.
2. Confirmed manual/SMS transaction batches reread the latest encrypted
   snapshot under lock, deduplicate SMS hashes and commit the transactions +
   deduplication list in the same SQLCipher transaction.

Before *each* read or mutation, **inside the lock**, the bridge reloads the
external SharedPreferences activation marker, refuses a pending cutover, checks
that secure key and all-writer routing proofs were supplied by a higher-level
coordinator, and consults the independently stored SQL cutover checkpoint.
Missing or contradictory witnesses block reads and writes, **never** fall back
to stale SharedPreferences balances. A single encrypted generation can be used
for app/widget refresh detection.

## Tests

Unit tests cover encrypted-only reads despite stale legacy values; interleaved
widget SMS + Home goal saves; same-field conflict protection; SMS deduplication;
missing routing/key verification; interrupted or missing activation pointers;
invalid SQL cutover metadata; and cold encrypted reopen.

The Android emulator integration rehearses a *synthetic* activated witness,
concurrent UI/widget finance operations, SQLCipher file signature and cold
reopen, while preserving original mock legacy data and nonfinance settings.

## Explicit release blockers

- Production `HomeScreen` and Android widget still use
  `WaffraHomeFinancePersistence` with the guarded **legacy source**; these
  call sites must be converted together and tested at app startup.
- `allWritersRoutedVerified` and `secureKeyVerified` are **external
  evidence**, not independently verified by this component. The real
  production selector and key/recovery service must provide these only after
  observing the actual installation.
- M55 receipt BLOB staging preserves the original `receiptPath` strings; UI
  receipt display, PDF, backup/restore and transactional attachments need
  lossless encrypted receipt-ID/path replacement before activating users
  who have receipts.
- Category catalog initialization, recurring reminders, challenges, trash,
  manual deletion, settings and any other finance mutations must use one
  runtime source. The real two-witness commit/recovery procedure, secure key
  persistence/recovery, backup restoration and interrupted-process tests are
  incomplete.
- Activation remains **off**. No Firebase cloud sync or real user data is
  modified. Do not merge this prototype as a complete production cutover.
