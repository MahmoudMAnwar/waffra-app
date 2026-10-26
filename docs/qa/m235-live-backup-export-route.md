# M235 — Real backupExport route through verified SQLCipher authority (QA)

Implementation starts connecting the *runtime* financial route inventory to
the already implemented encrypted ledger/receipt writer. This PR wires route
`backupExport` end-to-end:

- Home drains its finance write queue, selects the verified authority, and
  chooses the encrypted exporter only if the selected source is SQLCipher.
- Authority validates exact `backupExport` route, key/source witnesses and
  strong passphrase, refusing guarded-legacy access to the encrypted writer.
- Encrypted session delegates to native Home/Widget bridge.
- Bridge rechecks real activation/recovery witnesses UNDER its native lock
  before exporting snapshot, typed finance and encrypted receipt bytes.
- Any mismatch, missing linked image, tampered content or OS-key loss blocks
  the operation. Never fall back to a legacy JSON export or fabricate success.

A synthetic activated-source Flutter test exercises the full authority,
session, bridge, encrypted exporter and receipt vault against a disposable
SQLCipher file; another test corrupts a receipt and proves export refusal.
This synthetic test is **not a verified production release witness**.

Twenty-three other enumerated routes still need independent real runtime
evidence and where missing, application-level wiring; do not infer that
all 24 are complete from this individual success. The existing portable
archive uses a compatibility envelope and remains subject to migration to
the strong user backup format and full profile/SMS/device parity checks.
No APK release, no main merge, no source activation, no real customer data.


## Runtime 24-route connection inventory (structural, NOT hardware certified)

This is an executable-source handoff checklist, not a 24/24 pass count.
"Existing" means candidate authority/bridge entry points can be identified;
it does not mean that the independent signed real-device route proof passed.

| # | Route | Candidate runtime state |
|---|---|---|
| 1 | appStartup | Existing verified-source binding; release evidence required |
| 2 | widgetStartup | Existing isolated widget binding; dual-engine proof pending |
| 3 | dashboardRead | Existing authority load; verified cold-read acceptance pending |
| 4 | widgetRead | Existing authority load; standalone widget proof pending |
| 5 | manualTransactionSave | Existing typed append bridge; phone QA pending |
| 6 | bulkSmsConfirmedSave | Existing atomic encrypted SMS+hash writer; phone QA pending |
| 7 | widgetSmsConfirmedSave | Existing cross-engine SMS writer; phone QA pending |
| 8 | transactionEdit | Existing projected edit CAS; independent QA pending |
| 9 | transactionDeleteAndUndo | Existing encrypted recycle/undo; expiry QA pending |
| 10 | deleteAllTransactions | Guarded for unattached records; full invoice-safe delete still pending |
| 11 | categoryCatalogInstall | **M235 wired v2/v3/v4 encrypted Home startup**; markers atomic |
| 12 | categoryCreateEditDeleteRestore | Existing module editor/projection; full UI proof pending |
| 13 | goalCreateEditDeleteRestore | Existing encrypted goal editor; full UI proof pending |
| 14 | recurringCreateEditDeleteRestore | Existing encrypted recurring writer; full UI proof pending |
| 15 | recurringPostingAndPostponement | Existing combined posting/CAS; independent QA pending |
| 16 | challengeAndBudgetUpdate | Existing encrypted scalar writer; independent QA pending |
| 17 | merchantRulesAndSmsHashes | Existing hash merge and merchant rule writer; QA pending |
| 18 | receiptCopyAndAttach | Encrypted byte writer exists; **M235 guards old plaintext picker** until safe in-memory UI attach is wired |
| 19 | receiptView | **M235 wired encrypted ledger ID → receipt blob → Image.memory**; legacy remains source-specific |
| 20 | receiptRemoveAndRollback | Existing encrypted recycle candidate; complete UI / expiry proof pending |
| 21 | widgetBalanceRefresh | Existing verified source-backed refresh; hardware Widget proof pending |
| 22 | backupExport | **M235 wired Home → authority → native SQLCipher snapshot+receipts**; full archive migration pending |
| 23 | backupRestore | Disposable recovery proven; active source handoff and crash journal **not wired** |
| 24 | fullFinanceReset | Encrypted confirmed reset candidate; production UI/cold recovery proof **not wired** |

### Production blockers (still NO-GO)

Implement source-backed in-memory receipt attachment in Home for route 18
instead of accepting filesystem paths. Complete source-owner locked and
crash-atomic `backupRestore` (23), then fully verified reset and deletion (24,
10), including protected bank-message originals, profile/account data and
receipt retention. Validate all 24 independently on two physical signed Android
phones, including cold restart and recovery from interrupted writes. The current
Home binding deliberately injects **no production release evidence** and
does not activate SQLCipher automatically.

M235 CI synthetic successes, if achieved, cannot replace those proofs.
