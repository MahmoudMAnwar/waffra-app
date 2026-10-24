# M177 — complete Home finance authority boundaries (release **NO-GO**)

This change makes **real live-callsite modifications** rather than just
renaming a source route. Home previously made direct finance writes via
`_homeFinancePersistence.withLegacyWriter` even though SQLCipher activation
needs a single authoritative source for every caller. Those bypasses are now
replaced with `WaffraVerifiedFinanceAuthority` APIs.

## Actual persistence changes

| Route | Before | After |
|---|---|---|
| SMS fingerprint merge | Home directly combined old preferences and UI state | Authority validates SHA-256 and source; legacy merges with current Widget value **under the cross-engine lock**; encrypted bridge provides its own witnessed merge |
| Recurring notifications enabled | Direct `SharedPreferences.setBool` from Home | Authority selects source then guarded legacy commits under the coordinator; encrypted scalar fails closed until an atomic SQL writer is certified |
| Custom savings goal suggestions | Home called a legacy-only adapter directly | Both load and add check the source selector; SQLCipher fails closed until custom goal suggestions are included in its verified finance schema |
| Category catalog v2/v3 | UI wrote catalog and upgrade markers without checking read witness | Authority delegates to a guarded compare-and-swap version installer; stale concurrent catalog edits fail instead of being overwritten; source baseline refreshes after each version commit |

A NEW single bank-SMS entry entered through the Home entry sheet now uses
the same **atomic** `commitConfirmedSms` journal used by bulk imports and the
Android widget. The transaction and its fingerprint cannot be partially
committed: duplicates are rechecked inside the native lock, any explicitly
approved repeat is carried to the writer, and the Home ledger is updated only
after the durable result. This closes the earlier two-commit crash window for
that path.

Existing transaction edits with an additional SMS fingerprint still follow
the separate guarded edit and merge routes, so the PR does NOT claim full
24-route SQLCipher equivalence or new receipt lifecycle certification.

The encrypted `.waffra` backup handler now drains queued Home saves and
loads the **current authoritative finance snapshot** via the `backupExport`
route. It serializes finance fields, trash, SMS fingerprints, budget and
merchant rules from that witnessed read, not the potentially older in-memory
HomeScreen after a Widget transaction. This is a consistency improvement,
NOT two-phone recovery or backup portability certification.

## Race, crash and migration posture

- No raw bank SMS, credentials, receipt data, backup passwords or user data
  is transmitted to CI or logged.
- The legacy native lock and journal remain authoritative until release
  certification. Category versions store their marker **after** the list;
  repeating an incomplete installation after restart can recover safely.
- The new catalog operation compares the exact observed current catalog
  before any write, so a concurrent widget or app edit cannot be discarded.
- A false, pending, missing-key or corrupted SQL source does **not** select
  old preferences as a fallback. Custom goals and notification booleans
  deliberately have NO uncertified encrypted writer.
- The historical M161 negative regression is strengthened to require atomic
new-SMS ledger+hash confirmation instead of accepting an obsolete two-save
path. The new tests use disposable local storage, synthetic hashes and mock
  finance source reports. Passing CI is NOT physical-device verification.

## Remaining production blockers

Production still requires finishing all 24 independently verified live
finance routes. In particular:

1. Typed encrypted support for custom goal suggestions, recurring notification
   settings, category installation metadata, manual SMS-hash **atomic**
   confirmation, delete/undo, backup restore, receipts and privacy lifecycle.
2. A verified durable two-witness cutover coordinator, OS key recovery,
   transaction/receipt migration parity and abrupt-exit rollback on real devices.
3. Signed Android cold-start testing, two *physical* phone restore,
   account deletion and public privacy policy, Firebase Data Safety,
   Crashlytics and explicit human release approval.

No automatic SQLCipher activation or production deployment is performed.
