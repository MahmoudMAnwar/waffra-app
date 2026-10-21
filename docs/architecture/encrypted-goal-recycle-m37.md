# M37 — Encrypted goal recycle bin (30-day recovery)

This is an experimental, default-off persistence layer for the approved Waffra saving-goal deletion behavior.

### Implemented

- Delete goal atomically from the active encrypted goals table into a separate encrypted recycle table, including its **entire original JSON**, original target and deletion/expiry timestamps.
- Recoverable for 30 complete days; after expiry it cannot be restored. Permanent cleanup is separately opt-in and never affects transactions.
- Restore the same ID, name and target but set the **currently saved amount to zero**, preventing an old budget allocation from magically reappearing.
- Scan known goal reference forms in stored transaction JSON; if linked transactions are detected, refuse deletion until the user has explicitly acknowledged them.
- Preserve every historical transaction row unchanged through both deletion and restoration.
- All operations run in SQL transactions and survive encrypted cold reopen.
- Tests cover 30-day deadline, linked warning, history parity, no accidental double deletion and disabled gate.

### Safety and release gates

Goal IDs may also be referenced in app-specific formats not yet known to this prototype. This known-key scanner is not proof that all links are discovered: the UI adapter must audit the actual linked-goal model before enabling deletion. User-facing warning/confirmation dialogs and category/recurring 30-day trash still need separate integration.

The running app still uses SharedPreferences and this service is not called by live goal screens. No real user finance data, Firebase or bank integration is touched.
