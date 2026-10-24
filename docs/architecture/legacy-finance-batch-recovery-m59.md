# M59 — recoverable live HomeScreen finance batch

## Actual running-app change

The current HomeScreen still commits its data into SharedPreferences, but
saving its ledger, categories, goals, recurring, challenges, trash and budgets
is now preceded by a **single checksum-verified intent journal**. The pending
marker includes exact before/after values and is saved before the first
financial field is modified.

All cooperating HomeScreen and Android widget readers/writers go through the
same native file-lock coordinator. On restart after power loss/process death
the coordinator first replays any widget SMS journal, then the HomeScreen batch
journal, before allowing reads or writes. Every field must match its original
BEFORE or desired AFTER state. Any unknown newer value or invalid checksum
refuses the entire replay, keeping the original marker for recovery. The app
does not silently show mixed goals/transactions as though the interrupted
commit were complete.

## Limitations and security

- This is still TEMPORARY legacy SharedPreferences plaintext data; its
  pending journal briefly duplicates finance values on-device. Clear it
  after success and do not include it in cloud sync or analytics.
- This is a redo/replay journal, not a complete atomic database or cloud
  backup. A device that loses its full app storage still needs a backup.
- Replaying all fields is safe only for writers taking the common native
  finance lock; an older installed binary not honoring it is unsupported.
- Category catalog and other isolated legacy writes are locked but not
  grouped into the HomeScreen finance batch. Future cutover must block
  EVERY remaining write path and make SQLite plus receipt files authoritative.
- No SQLCipher activation, no real-data migration, no Firestore sync, no
  merge, and no APK release.

## Focused test cases

- Reopen after commit intention but before any finance key save
- Resume after only ledger and/or goal save completed
- Detect external modification without overwriting newer goals
- Tampered journal checksum and unsupported finance field/type
- Idempotent completion and original profile/SMS hashes preservation
- Restore under the same real cross-engine file lock before Home reads

The production cutover is still blocked by encrypted source-selection,
receipt-file recovery, complete Finance/Widget/SMS/backup/PDF parity, and
Android cold-start/reinstall validation.
