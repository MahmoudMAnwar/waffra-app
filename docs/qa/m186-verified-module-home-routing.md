# M186 — conditional verified SQLCipher module trash in Home UI (NO-GO)

This follow-on milestone is **stacked after M185** and must not merge alone.

## Actual implementation

The `WaffraVerifiedFinanceAuthority`, `WaffraEncryptedFinanceSession`
and `WaffraVerifiedEncryptedFinanceBridge` route **category, goal and
recurring schedule** soft-delete/restore/pending-recovery into the M185
typed encrypted module tombstone writer. The authority confirms that the
requested route matches the module, the source is `verifiedEncrypted`,
and the source-read baseline has a valid encrypted witness. The native
Home/Widget file lock rechecks activation, OS-key/writer witnesses and
the cutover journal before the same SQLCipher transaction mutates any
finance table. There is **no fallback** to legacy preferences when
encrypted source attestation fails.

On Home, this backend is selected **only if** the already verified finance
source says encrypted. Before deleting, the screen checks the exact
rendered entity JSON and ID against a freshly loaded verified source,
rather than trusting an old tile, then requests explicit user consent
from the existing delete dialogues. The financial write queue serializes
the requested deletion; no category, goal or recurring array is edited
optimistically. After a durable commit Home reopens the entire finance
source before rendering fresh counts and balances. Recurring notification
schedules are resynchronized from the durable result, not guessed ahead.

Category, goal and recurring Recently Deleted buttons gain the same
conditional encrypted modal listing names and verified SQLCipher
`entity_id → expiry` metadata. Each restore performs a fresh
source-witnessed authority call and reloads finance only after the
transaction succeeds. Expired items cannot be restored from the modal.
There is no **permanent-delete button** for encrypted sources until a
separately certified trusted-retention clock and purge policy exist.
The current guarded-legacy UX/restore/retention is unchanged.

Restoration of categories resets budget to 0. Restoration of savings
goals resets saved amount to 0. Recurring schedules are restored **paused**
and never auto-post a past payment; linked income/expense history and
receipt BLOBs are preserved.

## What remains NOT proven

- The default production Home still constructs a legacy-only
  `WaffraVerifiedFinanceAuthority`; conditional M186 code is not live
  SQLCipher activation or a completed 24/24 route witness.
- Parent/child recovery is currently **parent-first** in the encrypted
  writer to avoid a partial two-record restore. An approved composite
  atomic parent+child restore and confirmation flow is separate work.
- Permanent module-trash purge, independently authenticated deletion UTC
  clock, encrypted active-source backup restore and full reset, Home/Widget
  source injection and OS key recovery remain pending.
- Physical Android, two-phone transfer with exact original invoices and
  transaction history, Play signing, public policy/account deletion, Data
  Safety/Crashlytics and final human GO/NO-GO remain separate gates.

Tests in `test/storage/m186_module_authority_ui_gate_test.dart` use
disposable synthetic SQLCipher vaults and fake external witnesses. They
exercise Authority → Session → Bridge → typed SQL writer for all three
modules, duplicate/stale/forged UI source, consent refusal, parent/goal
zeroing and paused recurring restore. **They are not on-device evidence.**

No source markers, real users, Firebase or Play configuration are touched.
**Release state: NO-GO.**
