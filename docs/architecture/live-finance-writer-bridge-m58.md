# M58 — unify participating live legacy finance writers (draft)

## Running-app integrations

- HomeScreen now reads financial fields and Android widget revision together
  while holding the **same native cross-engine lock** used to save transactions,
  rather than reading the revision after the finance snapshot.
- The widget SMS entry point uses the shared finance boundary for its read and
  confirmed-save transaction. The existing three-key pending journal still
  stages/replays an interrupted Widget save before it becomes visible.
- HomeScreen's SMS deduplication writes, delete-all confirmation, recurring
  reminder finance flag and category catalog writes use the same guarded
  writer callback. Source cutover markers still refuse legacy access.
- Existing SharedPreferences and widget UX stay unchanged. This does not
  initialize a SQLCipher vault or attempt a legacy migration.

## Still needed to activate encrypted finance

1. A robust *single* durable source selector for every finance mutation,
   including quick-add, SMS, receipts, recurring, goals, deleted-item bins,
   PDFs and import/restore, across cold-start and separate Flutter engines.
2. Atomic encrypted commits coordinated with file bytes, one-time legacy
   migration/receipt manifest, backup/rollback and loss-of-key recovery UX.
3. Actual device/on-emulator tests for terminated/restarted app and widget
   while the encrypted source is ACTIVE; full UI/PDF/analytics parity.
4. Only after all those gates: explicit activation of the new local source.
   Firebase opt-in sync and account replacement/recovery come afterward.

M58 itself does not enable Firebase, move user financial data, publish APKs
or merge any PR. SharedPreferences multi-key saves remain non-atomic; legacy
writes remain the source until the final activation is independently verified.
