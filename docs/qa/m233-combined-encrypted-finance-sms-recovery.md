# M233 — complete finance + receipt + original SMS portable recovery QA

The **existing** password-authenticated portable finance/receipt V2 archive
is combined with M231's independently authenticated bank-original archive
inside an Argon2id/AES-256-GCM outer package. Every inner archive is
authenticated and its finance source checksum, original-SMS ledger linkage,
SHA-256 deduplication hashes and receipt count must agree with the outer
manifest. Authenticated but mismatched payloads fail closed.

A QA-only verifier restores the financial ledger and receipt bytes into a
random disposable SQLCipher vault, attests every transaction/invoice before
and after a cold reopen, then independently restores the bank SMS originals
into a separate disposable SQLCipher side vault and checks byte-exact parity.
Temporary files and keys are never exposed to callers and always deleted.

**This is NOT a production restore.** In particular, no existing active
source is replaced, no original customer database is migrated, no external
OS key is persisted, and profile/biometric material is not included.
Tests cover wrong password, fake plaintext archive, source-identity mismatch,
authenticated manifest tampering, and real dummy image-byte preservation.

Remaining: integrate user-facing export with secure file handling, source-owner
validation, profile and settings parity, true atomic app/Widget/side-vault
activation with crash rollback and hardware-derived keys, 24 live route
proofs, and two independently tested signed physical Android phones.
