# Waffra migration plan: SharedPreferences v24 -> encrypted Drift SQLite v1

**Status:** Implementation specification only. No current user's data has been accessed or changed.<br>
**Safety principle:** Import a copy, prove parity, then switch reads. Do not delete, mutate or overwrite legacy sources during initial rollout.

## 1. Source of truth today (audited 2026-10-21)

Current financial data is persisted via `SharedPreferences` in `lib/main.dart`; entries and core models are JSON arrays, receipts are separate files. Inventory:

| Legacy key / source | Shape | Proposed target |
| --- | --- | --- |
| `entries` | JSON array of `MoneyEntry` | `ledger_entries` + `entry_receipts` |
| `waffra_categories_v24` | JSON array of `BudgetCategory` | `categories` |
| `waffra_goals_v24` | JSON array of `SavingGoal` | `saving_goals` |
| `waffra_recurring_v24` | JSON array of `RecurringBill` | `recurring_bills` |
| `waffra_challenges_v1` | JSON array | `saving_challenges` |
| `waffra_deleted_categories_v1` | `[{category,deletedAt}]` | Deleted `categories` + saved tombstone JSON |
| `waffra_deleted_goals_v1` | `[{goal,deletedAt}]` | Deleted `saving_goals` + saved tombstone JSON |
| `waffra_deleted_recurring_v1` | `[{recurring,deletedAt}]` | Deleted `recurring_bills` + saved tombstone JSON |
| `waffra_recurring_postponed_v1` | Map generated entry ID -> date | `recurring_postponements` |
| `waffra_monthly_budget_v1` | Double | `vault_settings.monthly_budget_minor` |
| `waffra_monthly_budget_enabled_v1` | Boolean | `vault_settings` |
| `waffra_recurring_reminders_enabled_v1` | Boolean | `vault_settings` |
| `waffra_learned_merchants_v1` | Map merchant -> category | `merchant_category_rules` |
| `waffra_sms_hashes_v1` | String list | `sms_dedupe_hashes` |
| `getApplicationDocumentsDirectory()/receipts/` | Image bytes, local files | `receipt_assets`; originals preserved |
| `MoneyEntry.receiptPath` | Single path OR JSON array | Ordered `entry_receipts` |
| `waffra_widget_last_save_v1` | Widget revision | Widget checkpoint; ensure in-flight capture flushed before snapshot |
| `waffra_custom_goals_v1` | Custom goal suggestions/catalog | Investigate exact shape; don't conflate with live `SavingGoal` records |

Keep account/profile, locale, onboarding, appearance, screen protection, reminders/UI configuration and backup metadata under explicitly reviewed keys outside finance tables until a dedicated migration. In particular: `waffra_profile`, `waffra_registered_profile`, `waffra_last_login_*`, `waffra_local_password_*`, `waffra_pin_sha256`, `waffra_allow_screenshots`, `waffra_protect_recents_v1`, `waffra_appearance_mode_v1` and `waffra_backup_last_*` require a separate identity/security audit; **never sync PIN or password hashes**.

Existing `exportBackup()` v24 serializes financial records but **does not package receipt image bytes** and omits SMS hashes; it cannot alone prove complete recovery. `WaffraSecureBackup.decrypt()` presently accepts an older plaintext backup for compatibility; plan a warning/re-encryption policy, not accidental import of untrusted data.

## 2. Preconditions before any cutover

1. Pass a SQLCipher runtime and OS-keystore integration proof-of-concept on both platforms. Drift is the query/migration layer; it does not encrypt SQLite automatically.
2. Add `LedgerRepository` and a feature flag, initially `legacy` for all existing users.
3. Unit-test strict, version-aware decoders for each source key. Distinguish **absent**, **present-empty**, **corrupted**, **duplicate ID**, **invalid amount**, **unknown future version**. Avoid legacy `fromJson` defaults that silently replace missing dates with `DateTime.now()`.
4. Implement atomic SQL inserts, `PRAGMA foreign_keys=ON`, durable migration journal and encrypted exception/quarantine storage, plus database integrity check.
5. Freeze ledger writes while snapshotting, including widget, recurring auto-posting, SMS bulk import and editor saves. Flush pending writes; release lock after staging/cutover or failure. No concurrent writes to both stores without a defined reconciliation protocol.
6. Collect an **on-device** preflight inventory (counts, non-sensitive flags, source checksum). Never transmit transactions or raw SMS to logs/CI/support.
7. Expose optional manual encrypted backup/export (plus separately copied receipt attachments when available). Never silently upload legacy data.

## 3. Deterministic non-destructive state machine

```text
LEGACY_ACTIVE
    |
    v
PREFLIGHT  --key/encryption/source failure--> LEGACY_ACTIVE
    |
    v
SNAPSHOT (in memory, raw values + source manifest SHA-256)
    |
    v
STAGING (single SQLite transaction, off-screen/feature flag)
    |
    v
VERIFY (counts, exact IDs, normalized values, date, receipts, checksums)
    |  invalid/incomplete -> quarantine + stay LEGACY_ACTIVE
    v
VERIFIED (journal committed, SQLCipher data accessible after restart)
    |
    v
CUTOVER (persist read-source marker only after successful verification)
    |
    v
SQLITE_ACTIVE (only SQLite becomes financial write source)
```

- Journal key: `(vault_id, source_sha256, target_schema_version)`; rerunning an identical migration **must not** duplicate rows or receipts.
- Create a stable device-local `vault_id` independent of Google login, then import into that vault. Never auto-associate historical data with whatever Firebase user happens to sign in.
- Staging **transactional**: failure rolls back imported rows and leaves legacy values intact. Invalid rows are recorded in an encrypted quarantine; block cutover until all active financial records are losslessly represented or explicitly resolved.
- Snapshot checksum covers raw key-name/value pairs in deterministic key order, including both present and absent markers. Do not hash unstable `Map.toString()`. Store only the digest and counts in non-sensitive telemetry.
- Keep original JSON snapshots encrypted in row metadata during the first versions for round-trip audit. No legacy preference deletion in the same release as cutover.
- After cutover, expose recovery/export before any legacy cleanup. **App downgrade after new SQLite writes is NOT guaranteed** to recover new transactions from an older binary; do not advertise downgrade safety or dual-write without explicit design and tests.
- Future cleanup of old plaintext preferences is a **separate, opt-in/controlled release task** after a proven encrypted backup, recovery and app-upgrade path. Consider OS backups that may contain old copies.

## 4. Lossless field conversion and dangerous edge cases

| Source | Migration rule |
| --- | --- |
| `MoneyEntry.id` | Preserve ID byte-for-byte. For missing or duplicate IDs, assign a deterministic import ID derived from source key, original index and payload hash, retaining `legacy_entry_id` and original snapshot; never collapse distinct transactions. |
| `amount` Double | Convert SAR to integer halalas **only with exact agreed 2-decimal semantics and range checks**. Preserve original numeric text; quarantine amounts with extra precision/NaN/infinity/unsafe conversion until explicit policy. Negative values are invalid for existing positive amount + income flag model. |
| `date`, `startAt`, `lastDone`, `deletedAt` | Preserve original ISO and local calendar day without timezone shifts. Reject invalid transaction dates into quarantine instead of substituting today's date. Missing optional challenge lastDone is null. |
| Category links | Keep original transaction category text even if the category was deleted, duplicated or renamed. Derive a category ID only on a unique, type-matched mapping. Never rewrite historical category labels in migration. |
| Deleted category / goal / recurring | Preserve source `deletedAt` **and** source payload. Do not run the legacy 30-day purge as a side effect of migration. Apply retention after a successful verified cutover and safety checks. |
| Goals | Keep target/saved as observed; historical contributions are unknown. On *future* restore, set `saved_minor=0` and create an audit event while leaving ledger unchanged. |
| Recurring items | Preserve current due day, start date, active flag, original ID and postponed mapping. Generated `rec_...` transaction IDs must remain stable. |
| Receipts | Interpret `receiptPath` with the current `waffraReceiptPaths` behavior (single string or JSON list), preserve order and original raw value. For each path check existence and optionally SHA-256; **missing file is flagged, never used to delete the transaction**. Do not move/delete originals on initial import. |
| Merchant rules + SMS hashes | Preserve exact pairs/list membership; do not auto-share to cloud. If hash encoding is old or unknown, retain original string without recalculation. |
| Category catalog | Version flags `waffra_category_catalog_v2_installed` and `_v3_installed` prevent duplicate defaults. Import after legacy catalog upgrades have been fully applied; don't rerun catalog seed into the new vault. |
| Raw data errors | Any malformed row gets exact key/index and encrypted raw JSON in quarantine, with an error identifier. Do not log personal details or count it as a successful import. |

## 5. Verification manifest and acceptance gates

Check **per entity**, not merely an overall item count. Produce local diagnostic results (never containing financial text):

- Source count = imported count + quarantined count for each key; **0 quarantined active financial rows** required for automatic cutover.
- Preserve unique legacy IDs and deterministic collision mapping; no new or missing ledger IDs on retry.
- Exact income/expense transaction counts, sums by side and by local month in **halalas**, all dates, all category snapshots.
- Exact category IDs/parent IDs/budgets, goal IDs/target/saved, recurring IDs/active/day/postponements, challenge progression, merchant rules, SMS hashes, deleted-item expiry timestamps and order of receipts.
- Per-entry receipt count and file existence flags; no attachment path leakage to cloud. Spot-check multiple image preview (file bytes unchanged) and PDF attachment count badges.
- Reopen the encrypted DB after cold app restart and keychain reload; no plaintext SQLite header or readable SQL content in the DB file.
- **Re-import same snapshot twice:** identical checksums, row counts, totals, no dupes. **Forced interruption:** fail before marker, reload on legacy store, resume safely.
- Non-empty, zero-data, 10k+ entries, Arabic/English titles, Unicode emoji, huge/zero/fractional amounts, malformed JSON, duplicated IDs, timezone boundary, corrupted file, uninstalled/reinstalled backup, guest-to-Google sign-in, logout/account switch, concurrent SMS and widget writes.
- Running on old app version is not part of guaranteed reversible migration; test protected recovery paths and rollback before general release.
- Android and iOS release/profile builds, performance under low memory, battery, app startup time, offline-first behavior, automated tests and manual smoke testing must all pass.

## 6. Rollout and rollback protocol

**R0 – design:** This document and schema only. No user-facing change.

**R1 – test-only shadow migration:** Behind an internal flag, keep legacy reader/writer authoritative. Stage SQLite imports from synthetic and consenting tester data, compare, restart and report **anonymous pass/fail flags only**.

**R2 – production guarded cutover:** Gate on 100% financial row parity, zero unhandled errors, encryption verified, unchanged receipts, signed-off manual encrypted backup. Deploy to staged cohort and monitor locally. Read from SQLite only after journal reaches VERIFIED.

**R3 – stable SQLite:** Ship stable repository interface to SMS parser, recurring engine, home widget, PDF and AI analyzer. Test consistent sums and transaction IDs. Keep old preference sources untouched as short-term recovery input (but do not read them in normal operation).

**R4 – opt-in sync:** Only after user accepts clear consent text, install and test Firestore rules, enable per-vault outbox and device recovery. Separate original local vault from remote vault until explicit account linking.

**R5 – cleanup:** After at least one successful stable release, independently approve safe deletion of superseded plaintext legacy keys and legacy backups, with user recovery already working.

### Explicit stop conditions

Stop and do **not** switch storage on: missing/bad crypto key, incomplete/unsupported source version, non-representable amount, broken source JSON, orphan/colliding IDs not deterministically recoverable, staged DB corruption, receipt-association mismatch, unverified data counts or financial totals, or concurrent write not captured in snapshot. Offer non-destructive recovery; no silent reset.

## 7. Proposed implementation contracts

```dart
abstract interface class LedgerRepository {
  Future<MigrationStatus> migrationStatus();
  Future<LedgerSnapshot> readSnapshot(String vaultId);
  Future<void> saveEntry(String vaultId, MoneyEntry entry);
  Future<void> deleteEntry(String vaultId, String entryId);
  Future<void> saveGoal(String vaultId, SavingGoal goal);
  Future<void> saveRecurring(String vaultId, RecurringBill bill);
  // All financial mutations must be atomic; sync outbox enqueued in SAME transaction.
}
```

Migration code should be pure parsing/validation plus database operations, not direct Flutter UI code inside `main.dart`. Provide fixtures and tests before wiring app startup to the importer. Credentials, PIN and crypto keys do **not** belong in this interface.

**No cloud is created or enabled by this design.** A later user-owned Firebase Console action will be needed to confirm the selected Dammam location and production policies.
