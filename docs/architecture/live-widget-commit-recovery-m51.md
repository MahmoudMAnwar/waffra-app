# M51 — Crash-recoverable Android widget SMS saves in the CURRENT Waffra app

Waffra currently saves its Widget's confirmed SMS transaction into three independent SharedPreferences keys:

1. `entries` — ledger;
2. `waffra_sms_hashes_v1` — duplicate prevention;
3. `waffra_widget_last_save_v1` — dashboard reload witness.

A process kill between these writes could leave incomplete state. M49 stopped the dashboard from overwriting an unmarked new transaction. M51 adds **durable replay** for the current legacy source, without relying on Firebase or experimental SQLCipher activation.

## Actual production changes

- Widget confirmed-save stages a single JSON journal envelope with before/after values for all three fields and a SHA-256 checksum.
- Only after journal persistence succeeds does the widget save its three finance keys. On success the pending journal is removed.
- Every participating dashboard or widget writer recovers an unfinished journal **under the same native cross-engine lock** before reading and writing any finance fields.
- HomeScreen initial load and Android on-resume synchronization check and recover an interrupted journal before interpreting finance balances; Widget initial settings/saved hash load also does.
- The recovery only resumes values matching the recorded BEFORE or AFTER state. Unexpected newer transactions or hashes refuse overwrite and preserve the journal for reconciliation.
- Unit tests simulate death after saving only entries, after entries and hashes, corrupted envelope, unrelated changed entries/hashes, idempotent replay and recovery from an app writer under the actual file lock.

## Caution

SharedPreferences itself does not provide a fully atomic multi-key commit, and the journal cannot stop unmodified old app versions from writing the same keys. New/old app upgrades and real Android termination scenarios still require emulator/instrumented checks. This bridges the safety gap in the current offline app but **does not switch screens, widget or receipts to SQLCipher**, and the 30-day trash/full backup migration remains a release gate.

No Firebase, bank account integration, or real user data was changed by this PR.
