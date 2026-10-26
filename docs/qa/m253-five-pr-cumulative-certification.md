# M253 — M248–M252 exact-SHA integration and independent SQLCipher release evidence

**Scope:** Cumulative read-only certification **candidate**, never activation.
This branch is based on M252, which descends linearly through M251, M250,
M249, M248 and M247. Review comparison MUST be M247 → this candidate.
No main merge, financial source change, SQLCipher production activation,
APK distribution or release signature is authorized by this milestone.

## Immutable code-review boundaries
- M248: explicit manual-save consent, typed SQL rollback, empty delete-all refusal
- M249: Home UI redraw from independently confirmed ledger after failed manual write
- M250: bulk pasted SMS ambiguous commit re-reads authoritative ledger; no blind retry
- M251: source ready/read witness checked at entry/consent/commit; queued Home writes drained
- M252: single SMS atomic entry+fingerprint with fail-closed recovery; manual recovery drain

## Executable candidate tests
1. Full Flutter suite on the exact PR SHA
2. Real disposable SQLCipher transaction consent, CAS, delete-all and rollback
3. SMS batch and single-message recovery, duplicated hashes, source-guard/UI refusal
4. 24-route structural inventory, actual route matrix dispatch and release refusal
5. Android **emulator-only**: native encrypted DB, cold reopen, rollback, receipts,
   restore, widget/Home and migration; this is NOT signed real-phone evidence
6. Contract check of physical-device evidence collector (contract tests do not
   attest a physical phone or its signed binary)

## Production blockers not discharged by CI
- Recoverability of Android OS-backed encryption key on actual signed installations
- Two independent physical Android devices and documented offline backup/restore
  from identical signed application build, with DB/key identity and cold reopen
- App/Widget concurrent finance writes and device process-kill recovery attestation
- SQLCipher rollback/recycle/receipt byte matching on device, migration/legacy parity
- Authenticated portable backup restore to a *real* active source without data loss
- Account deletion, privacy policy publication, Firebase Data Safety and crash-consent
- Receipt expiry trusted clock and explicit human release approval

The existing `WaffraProductionCutoverReleaseGate` and route audit remain
fail-closed. A synthetic all-green unit test is **not** physical evidence.
Evidence must carry checked signing fingerprint, exact SHA, distinct physical
device identifiers (non-sensitive test aliases), logs and independently reviewed
proof; do not store user finance data, tokens, credentials or SMS text in CI.

## Stop rules
Any regression, missing attestation, wrong source checksum or missing pre-existing
key blocks release. Do not reset user data, silently select legacy, repair by
creating a new empty vault, or merge this candidate into main until independently
approved. Android emulator success only advances QA.
