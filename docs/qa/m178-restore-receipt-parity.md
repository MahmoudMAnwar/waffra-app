# M178 — encrypted restore and receipt parity hardening (NOT a cutover)

This change strengthens **executable independent after-restore attestation**:
a portable, password-authenticated backup may legitimately rewrite only
`receiptPath` into an opaque SQLCipher BLOB reference. Every other
transaction field must match with the exact same key set. The attestor also
requires the restored encrypted finance snapshot to have the exact key set
from the authenticated archive (except `waffra_custom_goals_v1`, which is
preserved in its own typed SQL table).

Negative tests reject missing/extra record fields, changed amount and missing
or unexpected finance keys. The existing attestor continues to compare actual
receipt bytes/SHA-256, count, owner, slot and generation after SQL restore.

This is a real code guard in the experimental restore verifier, not a
documentation-only inventory. It never performs actual restore, changes
production source markers, enables SQLCipher, touches live receipts,
publishes Firebase or grants a release GO decision.

## Independent evidence still required

- Finish 24/24 real Home/Widget writer routes and restore/receipt typed SQL projection.
- Run full nonempty restore + deliberate crash/restart/rollback against a
  disposable Android vault; collect checksum-only evidence with no user data.
- Restore on two physical Android phones with offline/reconnect tests.
- Build the reviewed SHA with release keystore, check APK/AAB signing and
  Firebase OAuth SHA; install on real phone.
- Publish reviewed bilingual privacy and data-deletion URL, verify account
  deletion and Play Data Safety, then obtain explicit human approval.

**NO-GO** until independent device and deployment evidence exists.
