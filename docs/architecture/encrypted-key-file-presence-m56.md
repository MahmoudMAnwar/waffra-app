# M56 — fail-closed encrypted database/key presence

Opening a finance vault after Android device restore, app data wipe, secure-storage loss or interrupted setup is dangerous if an old encryption key exists without a database (or vice versa). Creating a new empty financial database would look like deleted money.

M56 strengthens the existing OS-backed SQLCipher shadow vault opener:

- Only **both absent** is a new installation eligible for key generation and a new vault; only **both present** may reopen an existing vault.
- **Key present / file absent** is a recovery-required state, not permission to silently initialize a fresh empty balance.
- **Database present / key missing** is a recovery-required state, not permission to generate a new key and overwrite user data.
- Symlink or unexpected filesystem object at the encrypted vault path is rejected.
- Tests cover all four presence combinations, wrong-key rejection and reopening original encrypted data with the original correct key.

## Production release limits

This change does not enable finance source migration, create activation flags or integrate Firebase. Existing Waffra user data remain in SharedPreferences until every HomeScreen/widget/SMS writer and receipt reader is routed through the verified encrypted source. Backup/restore, secure user-visible recovery flows and Android release APK testing are still required.

Firebase setup is ready independently and remains the last integration stage.
