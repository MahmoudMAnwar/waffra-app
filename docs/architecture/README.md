# Waffra local-first data architecture (ADR-001)

**Decision: APPROVED for design (2026-10-21). Implementation and cloud provisioning are NOT complete.**

## 1. Goals and hard constraints

- Saudi-market-first, Arabic/English Flutter app on Android and iOS; all core ledger operations work offline.
- Local storage is the **source of truth**, with optional, explicit, opt-in cloud sync. No financial data is uploaded merely because a user signs in with Google.
- Never connect to or store users' bank-account credentials. Bank SMS text is treated as sensitive, user-supplied input; deduplication hashes are also user data.
- Preserve all existing entries, categories, budgets, goals, recurring schedules, challenges, archived items, merchant categorization rules, receipt associations, SMS deduplication identifiers, and financial history.
- Support independent local vaults and account switching. Signing out **must not erase** data; signing in must not silently claim another local vault.
- No migrations or cloud writes during the documentation phase.

## 2. Proposed stack

| Layer | Decision | Notes |
| --- | --- | --- |
| UI | Existing Flutter UX | Keep transaction cards, reports, widgets, locale and theme unchanged. |
| Repository | `LedgerRepository` + typed commands | One boundary for UI, SMS, widget, reminders, PDF and AI analysis. |
| Local | Drift + SQLite, encrypted at rest | **Drift alone does not encrypt SQLite.** Verify SQLCipher-capable runtime on Android and iOS in a build spike before choosing the final driver. |
| Key handling | OS Keystore/Keychain-backed secure storage | Random per-vault DB key; no keys in SharedPreferences, source control or analytics. Define recovery before rotation. |
| Identity | Firebase Authentication | Authentication does not imply syncing or local vault ownership. |
| Remote | Cloud Firestore **Standard/Native**, Dammam `me-central2` | Create only after verifying the Firebase project, default-database location, pricing, regional support and cross-service data flows. Location is not changeable in place. |
| Sync | Optional adapter + durable local outbox | Offline-first, idempotent record IDs, conflict policy and deletion tombstones. |
| Receipts | Private app files initially | Local paths are never Firestore documents. Cloud backup of attachment bytes is a separately consented, encrypted feature in a later milestone. |
| Backup | Existing AES-256-GCM password-protected JSON import/export | Preserve compatibility. Existing backups **do not include receipt file bytes**; explicitly communicate this until backup v2 is implemented. |

### Data path

```text
Flutter screens / SMS parser / widget / reminders / analytics / PDFs
                         |
                  LedgerRepository
                         |
                 SQLite/Drift (encrypted)
                         |
              Durable local sync_outbox
                         |
              [opt-in and signed in?]
                         |
              FirestoreSyncAdapter
                         |
    /users/{firebaseUid}/vaults/{vaultId}/...  @ me-central2
```

The cloud adapter is disabled by default, even for authenticated users. There is no automatic account-to-vault merge.

## 3. Local ownership and data model

- `vault_id` is a locally generated UUID, never a phone number, email, CR number or Firebase UID.
- Every financial row has `vault_id` in its primary key or an enforced parent FK. Reads **always** scope to the active vault. A separate account-vault mapping is established only after explicit confirmation.
- Ledger values use integer **halalas** (`amount_minor`, SAR × 100). Preserve the original legacy number string for audit/round-trip verification. Reject or explicitly quarantine non-finite, out-of-range or unexpectedly fractional values instead of silently rounding.
- Financial transaction date is preserved as its original ISO text **and** interpreted calendar date. Do not change `YYYY-MM-DD` because of UTC conversion; source `DateTime` values may be offset-less.
- Categories retain stable legacy IDs, names, income/expense side, parent link and budget. Ledger entries also retain an immutable category name snapshot: do not fabricate a category FK when names are ambiguous.
- Goals retain `target` and **current** `saved`. Old builds do not persist individual goal contribution events: do **not** invent them. Future changes will record auditable goal events.
- Soft-deleted categories, goals and recurring schedules retain original JSON snapshots and `deleted_at`. Restore semantics must match the approved UX: category budget resets, goal current savings resets to zero, recurring restore requires a new due date. Historical ledger is unaffected.
- Existing `receiptPath` is one path or a JSON array of paths; normalize into ordered `entry_receipts` records, while preserving the original raw field.
- Recurring-generated entry IDs (`rec_{recurringId}_...`) must stay unchanged for idempotency. Preserve `recurringPostponed` keys.
- App-level visual preferences, onboarding and device lock settings remain in preferences or secure storage as appropriate, separate from money data.
- `docs/architecture/schema_v1.sql` describes logical tables and integrity constraints; use Drift migrations in the app rather than executing that SQL indiscriminately.

## 4. Sync contract, not enabled yet

Proposed cloud paths:

```text
users/{uid}/vaults/{vaultId}                  # ownership, schema version, no financial totals
users/{uid}/vaults/{vaultId}/entries/{id}
users/{uid}/vaults/{vaultId}/categories/{id}
users/{uid}/vaults/{vaultId}/goals/{id}
users/{uid}/vaults/{vaultId}/recurring/{id}
users/{uid}/vaults/{vaultId}/challenges/{id}
users/{uid}/vaults/{vaultId}/settings/current
users/{uid}/vaults/{vaultId}/tombstones/{kind}_{id}
```

- Firestore rules: `request.auth != null && request.auth.uid == uid`, **plus** path/field/type/size restrictions, vault ownership and minimal privileges. Do not deploy permissive test rules to production. Rules should be unit-tested on the Firebase Emulator.
- Only upload explicitly selected financial vault data after consent, with a clear list of included/excluded data, a pause/disable control and deletion workflow.
- Use device ID + monotonically increasing local version + mutation UUID as idempotency metadata; upload operations from an outbox, advance cursor only after server acknowledgement. Do not sync the database file itself.
- Server-assigned timestamp is authoritative for server receipt, not the device's business transaction date.
- V1 conflict policy: distinct IDs merge, identical mutation IDs are ignored; conflicting edits to the **same** record require a deterministic policy plus an audit/conflict record (do not use unqualified last-writer-wins for financial amounts). Preserve tombstones across devices; define offline deletion expiry separately from the 30-day UI recovery window.
- Do not put raw SMS, login credentials, cryptographic keys, original local file paths or unsanitized analytics in Firestore.
- Cloud encryption-at-rest and TLS do not automatically provide end-to-end encryption. Evaluate **client-side E2EE and account recovery trade-offs before enabling sensitive financial cloud sync**.
- Firebase Auth, diagnostics, backups, object storage, support tooling and potential foreign processors have separate data-residency implications. Firestore in Dammam **does not by itself establish PDPL compliance**.

## 5. Security, compliance and release gates

1. Verify the SQLCipher native implementation on Android and iOS, database open/restore, secure key provision and key loss behavior. Never claim encryption until tested.
2. Build staging and production Firebase environments with different application identities. Confirm whether the existing Firebase project's default database region is already fixed **before provisioning**.
3. Conduct Saudi PDPL data inventory/consent, privacy notice, retention, processor/subprocessor and cross-border transfer review. Complete platform data-safety disclosures and user data/account deletion flows.
4. Treat existing unencrypted legacy SharedPreferences as a security risk until migration and safe cleanup; avoid debug logging of finance records. OS auto-backup and crash reporting must not capture plaintext dumps or database keys.
5. Firestore cost model is usage-based; free quota is limited and service/region availability and billing must be checked before deployment. No promise of permanently zero costs.
6. Pass Android and iOS migrations on real devices, database encryption validation, backup/restore, logout/account switching, SMS bulk import, recurring idempotency, home widget, PDFs and AI consistency checks.

## 6. Delivery order

- **M0 (this PR):** source inventory, approved design, executable candidate SQL, and non-destructive migration/test plan. Documentation only.
- **M1:** repository interfaces, migration fixture tests, SQLCipher driver and key-storage proof-of-concept on Android/iOS.
- **M2:** implement encrypted Drift store and import existing local records in shadow mode. Verify parity before cutover.
- **M3:** feature-flagged cutover to SQLite as single source of truth, with rollback/recovery, observability and a staged rollout.
- **M4:** provision Firestore in the approved region under the owner's account, security rules/emulator tests, opt-in sync/outbox, device replacement/recovery tests.
- **M5:** production privacy/legal/store-readiness review and publish.

### Source inventory

Inspected `lib/main.dart` model classes `MoneyEntry`, `BudgetCategory`, `SavingGoal`, `RecurringBill`, `SavingChallenge`, `Person`, plus `load()`, `persist()`, `exportBackup()`, receipt handling and trash. Existing code uses `shared_preferences`, local receipt files in `getApplicationDocumentsDirectory()/receipts`, `firebase_auth` for identity, and password-encrypted backup in `lib/waffra_secure_backup.dart`. There is no Firestore collection or cloud financial sync implementation in the reviewed branch.

### Decision caveat

This is an **engineering design and migration plan**, not a completed database, migration, production security audit, Firebase provisioning or deployment. Do not enable financial cloud sync until all gates above pass.
