# M182 — atomic source-witnessed recurring payment (NO PRODUCTION CUTOVER)

## Implemented, not just enumerated

The existing `recurringPostingAndPostponement` Home route previously only
allowed an encrypted *postponement-only* update. A human-tapped **Paid**
button now passes explicit confirmation to the verified finance authority.
On a verified encrypted source it extracts exactly one new deterministic
recurring payment from the captured Home ledger, and rejects every unrelated
changed finance field or mutation to existing transactions.

The verified encrypted bridge then takes the same native Home/Widget writer
lock and checks the independent encrypted source activation/recovery witnesses.
Inside **one SQLCipher transaction** it validates:

- Current recurring JSON and every normalized typed recurring SQL row match.
- The proposed posted entry uses the real recurring schedule's deterministic
  monthly ID, title, category, amount, income direction, due month and start.
- The payment has not already been committed; the preexisting encrypted
  transaction snapshot exactly matches SQL rows.
- Only that payment's own postponement entry may be removed, and its
  original postponement state has not changed since the UI loaded it.
- The payment has no receipt path (receipt BLOB installation remains a
  distinct verified transaction writer).

A repeat **Paid** confirmation with an unchanged ledger fails closed rather\nthan silently succeeding as a scalar no-op. The existing M175 route intent\ntest now asserts the Paid path contains explicit user confirmation, distinct\nfrom postpone-only.\n\nIt inserts one normalized SQL row and commits the new canonical ledger and
postponement map in that same SQL transaction. A crash, stale Widget race,
tampered schedule, duplicate entry or invalid category fails without partial
finance persistence. Unrelated Widget SMS hashes and transactions are kept.

## Testing and limitations

`test/storage/m182_encrypted_recurring_paid_atomic_test.dart` exercises
typed SQL finance persistence, actual postponement clearing, preservation of
a concurrent Widget SHA hash, explicit Paid consent, duplicate rejection,
forged amount/ID, stale postponed data, coupled budget edit, receipt refusal,
and disabled-session denial using synthetic disposable SQLCipher vaults.

These are **synthetic witnesses**, not physical-device production proofs.
The independent current default source remains guarded legacy; neither
Main nor Widget is allowed to select SQLCipher without OS key recovery,
dual durable source witnesses and **24/24 real live route audit evidence**.

## Still blocking release

Receipt-backed transaction delete/undo and recycling, user-data rehydration
after failed UI writes, full encrypted finance reset, verified restore to
an activated source, receipt-backed app attachment rendering, real Widget
startup/balance, encrypted source materialization, two Android physical
device tests and two-phone restore, signed APK/AAB, public privacy/account
deletion, Data Safety, Crashlytics proof and human final approval.

No source marker, activation flag, existing user data, production Firebase
or Play publication is changed in M182.
