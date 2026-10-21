# Storage M15 — atomic encrypted entry mutation + outbox (draft)

This is a disabled-by-default proof-of-concept. It does **not** change
`main.dart`, SharedPreferences, the existing financial history, any phone's
financial records or Firebase. The source remains the legacy local ledger.

## New guarantee within the experimental encrypted SQLite vault

`WaffraDraftAtomicEntryWriter.commit` obtains M9's write gate, then uses one
Drift SQLite transaction to apply ALL THREE durable changes together:

1. Create/update/soft-delete one version-checked ledger entry in the working
   encrypted projection; no last-write-wins or lost editing conflicts.
2. Encrypt the sanitized record with AES-256-GCM, bind it to
   vault/record/device/mutation/version and enqueue exactly this ciphertext
   and immutable nonce in the encrypted offline outbox.
3. Write a durable per-vault mutation ID + financial payload digest to prevent
   accidental duplicate submissions after a restart.

Any failure rolls back all three; a replay with the same mutation ID and
payload leaves the original ciphertext/nonce unchanged. Reusing the mutation
ID with changed financial data fails closed. No plaintext financial entry,
SMS body, local receipt filename or bank credential goes into cloud payload.

Tests cover atomic insert, versioned update, soft deletion, isolation,
wrong vault, invalid dates/amounts, exact idempotency after DB restart,
stale edit refusal and immutable historical source.

## Important limitations / remaining work

- This prototype covers **ledger entries only**. Category/goal/recurring/
  challenge operations need matching single-transaction commands.
- It is not called by the live app; all UI/SMS/widget/recurring writers still
  use legacy SharedPreferences. A single app-wide gate must wrap them before
  any transition. Do not enable two competing stores.
- Outbox acknowledgements currently delete queued rows; a durable server
  receipt and version chain must guard crash replay across devices.
- The real Firestore adapter still needs transaction-based compare-and-set
  behavior for updates and delete tombstones, security rules, and conflict UX.
- Vault E2EE key recovery, consent, staging environment and owner Firebase
  access are mandatory before remote sync.
- Validate upgrade/downgrade, app rollback, encrypted backups with receipt
  bytes, iOS and Android devices, before merging any migration to main.
- This is NOT a production rollout or a warranty of zero data loss.

Keep the pull request Draft until the above release gates are met.
