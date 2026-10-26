# M232 — disposable SQLCipher bank-original recovery proof

**Experimental QA only; not production backup restore.** The encrypted
original-SMS archive added in M231 can now be authenticated against exact
ledger IDs and SHA-256 deduplication hashes and safely staged into a uniquely
generated *disposable* SQLCipher side vault. Batches use a 100-record
transaction cap. Every original is read back through a new encrypted-store
connection and byte-compared; the entire temporary directory and its ephemeral
key are discarded even when staging or verification fails. Callers cannot pass
an active database path, an OS key, or a source activation marker.

Negative tests cover wrong passwords, source mismatches, missing confirmed
originals and the zero-record case. Every returned proof explicitly denies
production cutover or two-physical-phone attestation.

**Remaining:** A complete finance+receipt+profile+SMS authenticated backup
format and atomic, crash-recoverable active-source restore coordinated with
Home/Widget, independent OS-backed key on each device, all 24 live route proofs,
and two signed physical Android devices. Nothing in this PR moves or replaces a
real customer's data. No app APK is released.
