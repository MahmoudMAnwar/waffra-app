# M180 — typed SQLCipher custom goal suggestions (release NO-GO)

This is **actual source-selected runtime code** (not an architecture document):
`WaffraVerifiedFinanceAuthority.loadCustomGoalSuggestions` and
`addCustomGoalSuggestion` use the verified encrypted finance session if and
only if the independently witnessed SQLCipher source is selected.

The encrypted bridge holds the **same native Home/Widget writer lock** used
for finance changes, rechecks the SQL/external source witnesses **under the
lock**, validates current encrypted snapshot integrity and reads/writes a
dedicated `fresh_finance_custom_goals` table. The fresh vault bootstrap
creates an empty typed table; authenticated portable restore already uses the
same table for custom goal suggestions.

## Durability and correctness

- Reject missing typed table, corrupt/non-contiguous positions, duplicate
  normalized suggestions, invalid names or excess capacity.
- Trim new suggestion to 1–100 characters, check latest SQL state under the
  native lock and atomically insert a new sequential row in an SQL transaction.
- The backup exporter already reads this table under the same native lock.
- A duplicate race returns false; an interrupted SQL transaction rolls back.
- Never read or write old SharedPreferences from the verified encrypted branch.
- Experimental SQL stays disabled by default; guarded legacy remains the
  selected production finance source until the independent release gate.

Synthetic integration tests use disposable SQLCipher databases, mock source
reports and fake activation markers, **not real phones**. They verify
encrypted persistence, duplicate races, corrupted projection rejection,
invalid input and pending-source denial.

## Outstanding, independent release blockers

24/24 **real** source/route witnesses; complete category catalog version
markers, delete/undo, encrypted restore and receipt projector parity;
two physical Android device tests and key recovery, signed APK/AAB and
Play-installed Google sign-in, public AR/EN privacy and account deletion URL,
Firebase Data Safety, Crashlytics consent proof and explicit human approval.

No source marker, production key, live finance data, Firebase backend or Play
track is changed or deployed.
