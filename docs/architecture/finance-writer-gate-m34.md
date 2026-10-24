# M34 — single-writer coordination rehearsal

Waffra's current HomeScreen persists finance through SharedPreferences, while the Android quick-add widget uses its own SharedPreferences writes. Switching only one side to encrypted SQLite would cause conflicting balances, duplicate SMS entries or silent overwrites.

This milestone introduces a **disabled-by-default, disposable writer gate** to support future synchronization:

- A per-directory in-process queue makes cooperating async callers run one at a time.
- A native advisory exclusive lock coordinates cooperating processes that use the SAME private lock file path. No lock is assumed for processes or old versions that do not participate.
- A revision guard refuses saving from a stale snapshot; the caller must reload and retry through a safe state merge.
- Tests simulate overlapping writers and exceptions and ensure a failed callback releases the gate, with no finance record writes.

## Crucial limitations

This is **not** production writer freezing, nor is it an atomic SQL/receipt transaction. Any app variant, Android widget service, isolate or recovery process that does not acquire the same gate can still write. The current main.dart and widget are NOT yet wired to this gate.

A full deployment needs:
1. Gate every finance writer: dashboard, receipt editor, recurring posting, bulk SMS, quick-add widget, imports, backups and goal/category edits.
2. Read the authoritative revision, mutate and commit generation under the same lock and data transaction. SharedPreferences multi-key writes remain non-atomic, so use this barrier only with a durable encrypted repository transaction once switched.
3. Cold-start marker and interruption recovery, key recovery, data migration for upgraded installations, and device tests.
4. Do not reuse a disposable demo lock path as the real app lock or trust a caller-supplied arbitrary folder.

Firebase remains the final step and is not required for any local storage coordination.
