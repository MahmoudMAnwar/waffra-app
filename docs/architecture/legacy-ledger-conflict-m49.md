# M49 — protect real financial ledger against interrupted widget writes

The Android widget saves legacy SharedPreferences `entries` before writing SMS hashes and its `waffra_widget_last_save_v1` revision. If Android kills that Flutter engine after the entries update but before revision, the dashboard previously saw an **unchanged revision** and could overwrite the new transaction with its cached list.

M49 adds an exact persisted ledger witness:

- HomeScreen loads and remembers the saved **raw entries value** (null distinct from '[]').
- A widget sync refreshes both the remembered ledger and widget revision.
- Every dashboard persist and the destructive delete-all path, while holding the M47 common writer lock, compare the freshly reloaded on-device entries AND widget revision against the last known saved baseline. Any difference aborts before overwriting.
- After a successful dashboard full-finance save, update the baseline to the newly committed entry list, preserving repeated in-app edits.
- Unit tests prove early unmarked widget writes, changed revision without changed entries, empty-versus-missing and successful sequential dashboard appends.

This is **additional protection for the existing legacy app**, not an atomic multi-key SharedPreferences transaction or activation of SQLCipher. Full encrypted cutover with receipt migration, secure key recovery, all reader/writer routing, rollback and APK/device testing still must pass before enabling it. Firebase is deliberately untouched.
