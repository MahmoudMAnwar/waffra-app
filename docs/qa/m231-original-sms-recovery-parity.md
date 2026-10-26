# M231 — guarded-legacy original bank SMS parity preflight (QA)

This is a **read-only prerequisite**, not SMS recovery/backup deployment.
It matches confirmed canonical ledger SMS IDs to a cold-opened,
OS-key-backed encrypted side vault and checks each original's fingerprint
against the saved dedupe hash evidence. The output contains counts only;
never raw bank messages or an unencrypted export.

Missing originals, incorrect hashes, changed ledger witnesses and lost secure
keys are reported or rejected; neither a new vault nor a missing record is
invented. In a real legacy bank SMS archive, a verified count of all originals
does **not** mean the archives themselves have been transported to another
phone. Cross-device encrypted original-note export/import, receipt reconciliation
and crash-safe cutover remain required separately.

CI tests use synthetic messages and disposable SQLCipher stores only.
No production SQLCipher activation, Firebase deploy, real banking access,
user-facing APK or destructive migration is part of this candidate.
