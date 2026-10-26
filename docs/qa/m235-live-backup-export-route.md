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
