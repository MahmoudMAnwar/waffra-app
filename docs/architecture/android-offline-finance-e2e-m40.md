# M40 — End-to-end Android rehearsal of offline encrypted finance

The Android emulator CI now runs a combined, *entirely synthetic* finance storage scenario:

1. Fail-closed source-policy decision for a genuinely new, writer-frozen device.
2. Create SQLCipher finance schema without sample user data.
3. Insert real income and expense records with exact integer halalas.
4. Create a saving goal, delete it to encrypted trash and restore with current saved allocation reset to zero.
5. Attach two images as SQLCipher BLOBs linked to the transaction.
6. Separately initialize the complete finance snapshot bridge and append a widget-style normalized SMS transaction atomically after explicit confirmation.
7. Verify encrypted database refuses the plain SQLite header, close/reopen, check amounts, goal, images and snapshot state.
8. Verify an encrypted file with no source activation witnesses is **recovery required**, not live-enabled.

### Coverage boundary

This is an Android **storage** regression, not a claim that the current screens, PDF exports, dark mode, SMS widget UI, archive migration or rollback UI are switched or tested. The relational ledger and full finance snapshot bridge intentionally remain separate until the production adapter reconciles all fields and sets an audited activation marker.

No user phone data, Firebase, real bank information or real receipt files are read or written.
