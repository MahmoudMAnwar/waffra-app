# M238 — live UI port for the encrypted invoice-recycle route #20

This independent PR builds on M235. A verified SQLCipher transaction with
attachments exposes a source-gated "Move invoices to Recently Deleted" option.
It first reads the current source and exact ledger owner, then uses the
existing M121 lock-consistent `WaffraVerifiedReceiptScreenGateway` to capture
generation and cryptographic image digests. Only after explicit user approval
does it call the native-locked M117 recycle writer, moving bytes to SQLCipher
trash while preserving the transaction and its monetary totals.

Home reloads from the newly verified ledger rather than changing cached UI
before durable commit. Its Undo action independently reloads the new encrypted
recycle witness and restores the same original bytes. Stale owner, changed
generation, expired record, missing source, lost key, receipt mismatch and
unverified recovery fail closed. Legacy UI does not expose the new action.

This does **not** certify trusted deletion expiry clocks, full recycled
attachment navigation, physical hardware recovery or source activation.
Existing M119/M121 Android receipt retention and SQLCipher tests remain
required. Do not merge to main or release an APK before the 24-route gate.
