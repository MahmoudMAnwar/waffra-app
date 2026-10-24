# M38 — atomic encrypted receipt blobs for new installs

For a truly new Waffra installation, external image files and finance SQL metadata should not have to commit independently. This isolated experiment stores receipt byte arrays directly in **SQLCipher**, together with the transaction's receipt count inside one SQLite transaction.

- Attaches up to 10 receipt images (max 8 MiB each), no empty images, to an existing finance transaction.
- Encrypted receipt bytes, deterministic safe names, SHA-256 digest and image length live in a new protected SQL table with an entry foreign key.
- Validates saved count against transaction metadata in the same transaction. No external file path or raw Firebase upload.
- Reading re-verifies byte count, contiguous order and digest. Corrupt data refuses to render.
- Cold reopen recovers the images from the encrypted database. Unsafe second writes are rejected rather than silently overwriting images.
- Defaults off. Test uses temporary encrypted vaults and synthetic image buffers only.

## Release blockers

The running app still uses File-based receipt paths inside MoneyEntry. Switching the UI needs a migration strategy for existing old receipt files and APIs to display images from memory rather than FileImage. The current M29/M32 transaction repository explicitly rejects receipt paths and updates of receipt-bearing entries. Category/goal linked transaction deletion, backup/export, quota policy and Android heap/performance testing are needed before release.

Use M25–M27 external-file recovery tools for legacy archives; this new encrypted BLOB strategy only applies to verified new installs. No Firebase or bank-account access is involved.
