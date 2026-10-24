# M185 — encrypted categories, goals and recurring trash (NO-GO)

## Source-guarded candidate

The standalone `WaffraEncryptedModuleRecycle` now models three previously
blocked `WaffraFinanceModule` delete/undo routes: category, goal and
recurring schedule. It requires an explicitly confirmed delete, an immutable
encrypted snapshot generation+digest, an externally verified source gate
*inside the same Home/Widget native writer lock*, and an independently typed
SQLCipher projection witness for the complete active module.

Within a **single** SQLCipher transaction deletion removes one exact row
from the active typed table, archives the original entity in
`fresh_finance_module_recycle` with a SHA-256 financial checksum and
a 30-day expiry, updates the app-compatible `waffra_deleted_*_v1` JSON list
and commits the new canonical active module snapshot. The transaction
revalidates the SQL active projection and the SQL/JSON tombstone afterward.
On any mismatch it rolls everything back; there is no legacy fallback
after encrypted source selection.

Restore validates the archived entity and its full trash/parity witness,
the 30-day time window and current financial generation, and inserts the
typed SQL row + canonical module snapshot while consuming the tombstone
in the **same SQL transaction**. Category budgets are reset to **0** and
saved progress on goals is reset to **0** on restore, matching Waffra's
approved UX. Historical income/expense transactions, SMS-hash identities
and invoice bytes never change.

Important constraints: a parent category with active children cannot be
deleted before its children; restoring a child whose parent is still
deleted fails closed (future UI can request parent-first restoration).
Recurring schedule deletion is blocked while *any* postponed recurring
payment exists, preventing orphan schedule state. Purge after expiry is
not exposed until the independently verified deletion-time and recovery
clock policy is implemented.

## Test evidence, not real device certification

`test/storage/m185_encrypted_module_recycle_test.dart` uses only disposable
synthetic SQLCipher databases to exercise all three module types, goal saved
and category budget zeroing, orphan parents, pending recurring posting,
stale Home/Widget witnesses, typed SQL tampering, archived checksum
tampering, expired restore, invalid trash parity, missing user consent,
source mismatch and default-disabled behavior.

The entire file is deliberately disconnected from live Home screens,
`WaffraVerifiedFinanceAuthority` and the Android Widget. These are next
integration steps and MUST NOT be claimed as completed/production enabled.

## Remaining blockers

Source-gated authority/session/UI integration, trusted 30-day retention
and expiry clocks, permanent purge, activated-source backup restore,
transaction/receipt device reopen, full reset, startup and Widget source
routing, **24/24 actual live route witnesses**, signed Android release,
two physical phones with cross-device encrypted restore, public bilingual
privacy/account deletion, Crashlytics/Data Safety and explicit human GO/NO-GO.

No production SQLCipher activation marker, user data, Firebase or Play
publishing is changed.

**M185 status: source-gated standalone module recycle candidate; NO-GO.**
