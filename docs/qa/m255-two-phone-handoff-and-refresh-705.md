# M255 — Independent two-phone handoff (NOT physical evidence; release NO-GO)

This draft adds **software-only** pull-refresh source safety tests and a precise
private hardware acceptance script for the final stage. It does **not** create
an APK, attest to Android phones, sign a binary, enable SQLCipher, migrate
finance, touch `main`, or permit an app-store release. M253/M254 remain drafts.

## Verified boundaries

- M253 source snapshot: `1a957d06ce51a9e20b04bfa4856db87e22fafb4f`.
- M254 reviewed pre-hardware source: `ade7a89019b4545f7a93d5c2b68951f0595f0faa`.
- M255 candidate source: **use exact final M255 PR head**, not the above
  ancestors or build #705. Bind the final candidate **before** any tests.
- User-approved installed build **#705** is a *rollback/reference only*, not
  proof of source parity or a signed M255 candidate.
- Fail-closed: any uncertain read, invalid source witness, key problem,
  mismatched certificate, corrupt archive or skipped route means **NO-GO**.
- All bank/SMS/receipt/goal data in the testing protocol must be synthetic.

## Assistant-owned items (before involving user)

1. Assert first-install guarded-legacy refresh defaults without inventing
   encrypted records; reject malformed legacy and incomplete encrypted
   financial sources via `test/storage/m255_verified_pull_refresh_safety_test.dart`.
2. Coalesce overlapping manual pull-to-refresh gestures into one awaited
   authoritative read. Test concurrent, reentrant, successful and failed
   reads. Never substitute a cached in-memory ledger or auto-promote source.
3. Create all M189/M190/M254 evidence reports with **exclusive owner-private
   (0600) permissions at file creation**, never chmod only after writing.
   Fail closed on symlink destinations or existing files, and never log paths.
4. Run all normal app/SQLCipher unit-widget regressions on **the same M255 SHA**
   and verify that M254 forged-device/certificate/GO refusals still pass.
5. Prepare this immutable 24-route evidence matrix and conservative #705 test.
6. Identify and quarantine any same-SHA failures on the draft; do not sign or
   upload an APK, merge or activate the production vault.
7. Independent local release engineer must later prepare a **signed testing
   candidate** linked to an independently reviewed exact source SHA and APK
   SHA-256 / signer certificate SHA-256. CI emulator/debug builds do not count.

## Human/hardware final stage — only when ready

**Prerequisites**: two independently owned/authorized Android 11+ physical
phones, one laptop with trusted Android Platform Tools / SDK build tools,
an independently produced **non-production** signed test candidate, verified
package/signer/source provenance and a human witness. Install only in a testing
environment that cannot overwrite the user's #705 install or authentic data.
A separate package/application ID may be needed; when it differs from
`com.waffra.app`, M189/M190 pinning scripts must be explicitly reviewed and
updated for that test app. **Never** override the package check just to pass.

1. Obtain independently verified `git rev-parse HEAD` + source provenance;
   record signing certificate and APK SHA-256 out-of-band. No private signing
   key, app identifiers, device serials or raw financial evidence in GitHub CI.
2. On private POSIX test machine with both devices connected, run
   `python3 scripts/qa/m189_physical_device_source_probe.py --capture
   --output /private/m189.json`; a *presence only* check (not real security proof).
3. With the independently pinned APK run
   `python3 scripts/qa/m190_signed_apk_preflight.py
   --apk /private/review.apk --expected-apk-sha256 <SHA256>
   --expected-cert-sha256 <CERT_SHA256> --output /private/m190.json`.
4. Offline consistency check:
   `python3 scripts/qa/m254_physical_release_evidence_review.py
   --physical-report /private/m189.json
   --signed-apk-report /private/m190.json
   --expected-commit-sha <EXACT_M255_SHA> --output /private/m254.json`.
   Files must be owned by the current user and mode 0600. These three
   utilities must **still return NO-GO** for production.
5. Independent witness confirms the installed **same** signed binary on
   both devices; M189's package-presence report alone is insufficient.
   Capture only **redacted** test results in the private release system.
6. Execute every route and recovery test below on independent real devices;
   repeat after kill/restart and cross-device restore, verify exact
   transaction count, amount, category identity, receipt **byte hashes**,
   and ledger/source provenance. Do not mark any route passed on the strength
   of emulator tests, source flags or guessed JSON.
7. Human reviewer signs the private evidence report and decides release
   eligibility. The draft PR cannot grant itself a GO decision.

### 24 finance route witnesses (each required, not implied by CI)

| # | Route | On-device independent witness needed |
|---|---|---|
| 1 | `appStartup` | Fresh + existing encrypted vault reopen; never silently reset |
| 2 | `widgetStartup` | Widget source consistent on reboot / process death |
| 3 | `dashboardRead` | Ledger, categories and balances match encrypted authority |
| 4 | `widgetRead` | Widget read matches authoritative Home digest |
| 5 | `manualTransactionSave` | Confirm/cancel, exact single atomic append, restart parity |
| 6 | `bulkSmsConfirmedSave` | Confirm <=100 synthetic messages, duplicates, ambiguous commit |
| 7 | `widgetSmsConfirmedSave` | Atomic widget SMS entry/hash, same Home ledger |
| 8 | `transactionEdit` | Edit survives cold reopen, rollback rejected stale edit |
| 9 | `transactionDeleteAndUndo` | 30-day encrypted recycle / undo with receipt parity |
| 10 | `deleteAllTransactions` | Explicit consent, concurrent-write conflict, rollback |
| 11 | `categoryCatalogInstall` | Idempotent catalog install; no phantom categories |
| 12 | `categoryCreateEditDeleteRestore` | Parent/child recycle, budgets, history not corrupted |
| 13 | `goalCreateEditDeleteRestore` | Goal recycle and restore to zero allocated value |
| 14 | `recurringCreateEditDeleteRestore` | Recurring recycle/restore without double posting |
| 15 | `recurringPostingAndPostponement` | Due payment posted once, postpone no phantom expense |
| 16 | `challengeAndBudgetUpdate` | Budget and challenge atomic update under interruption |
| 17 | `merchantRulesAndSmsHashes` | Rule and hash collision/dedup preserved after restart |
| 18 | `receiptCopyAndAttach` | Receipt encrypted bytes, atomic attach and error rollback |
| 19 | `receiptView` | Only owning ledger entry opens correct encrypted bytes |
| 20 | `receiptRemoveAndRollback` | Remove/undo with exact byte/hash parity |
| 21 | `widgetBalanceRefresh` | Balance and source check after simultaneous Home write |
| 22 | `backupExport` | Password-protected portable archive and digest |
| 23 | `backupRestore` | Offline restore on second phone; corrupted/wrong-key refusal |
| 24 | `fullFinanceReset` | Only with prior verified backup, biometrics & consent |

### Separate failure / reliability acceptance

- **#705 pull-to-refresh regression**: create synthetic income, expense,
  budget, recurring and category data. From Home, Categories, Goals and
  Recurring, pull to refresh repeatedly, with widget updates before/during
  refresh, on slow and offline network. Normal local refresh must not present
  a false data-integrity failure requiring Retry. The same transaction
  counts, amounts and saved receipts must remain after process death.
  A *real* unreadable or tampered source must instead keep the fail-closed
  recovery screen; do not solve the UI glitch by swallowing integrity errors.
- Cross-device portability: OS-backed key availability and cold reopen on
  each real phone, authenticated archive export, independent restore on phone
  2, byte-for-byte receipt hash parity, no changes to phone 1.
- Abrupt kill during Home + Widget simultaneous save, app restart,
  storage permission revocation and retry; never create duplicate SMS or
  an empty substitute vault.
- Privacy: account deletion, clipboard absence of encrypted backup plaintext,
  screenshot/recents protection settings and Firebase/crash consent.
- A real independent reviewer must witness source→binary signing provenance.
  Package presence / SHA typed into JSON is **not** sufficient.

## Release decision

**NO-GO** until all 24 real-writer routes, independent two-phone recovery,
receipt bytes, signing/source binding, privacy/Data Safety and explicit human
release approval are complete. No automation may treat a populated worksheet,
green test suite, or mock flags as production authorization.
