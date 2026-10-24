# M179 — source-witnessed encrypted recurring reminder scalar (NO-GO)

This incremental change fixes the previously **fail-closed** SQLCipher branch
of `WaffraVerifiedFinanceAuthority.setRecurringReminderPreference`.
The activated encrypted-source candidate now writes the **single** finance
boolean `waffra_recurring_reminders_enabled_v1` through
`WaffraEncryptedFinanceSession.saveRecurringReminderPreference`. It never
escapes into SharedPreferences after the encrypted source is selected.

## Technical contract

- `_requireRoute(recurringCreateEditDeleteRestore)` must pass: two independent
  durable source witnesses, OS-key recovery gate and complete 24-route audit.
- Capture an immutable `WaffraEncryptedHomeWitness` before the write.
- Reuse the existing `saveChangedFields` SQLCipher writer, which holds the
  cross-engine native lock, rechecks the source marker inside that lock, then
  compares the exact old scalar in one SQL transaction before committing the
  new revision/checksum. A concurrent change to the same boolean fails closed.
- A concurrent Widget SMS hash merge or transaction write is preserved.
- The Home UI awaits a *durable new authority read* before claiming success.
- Legacy's guarded transaction coordinator remains unchanged.

The synthetic integration test constructs a disposable SQLCipher vault with
test-only activation witnesses. It asserts persisted encrypted booleans,
same-key optimistic-concurrency rejection, unrelated concurrent hash survival,
blocked pending markers and disabled-session refusal. **Synthetic witness
passing is not real-device cutover evidence.**

## Outstanding release blockers

No production source selection or migration is performed. The separate
encrypted typed projector still needs custom-goal suggestions, catalog
installation metadata, backup restore, receipts, delete/undo and full reset.
24/24 real writers, two physical phones, restore, Android release signing,
public privacy/delete URLs, Firebase Data Safety and explicit launch approval
are independent mandatory gates.
