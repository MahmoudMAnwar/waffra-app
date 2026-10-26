# M237 — safe runtime entrypoints for backupRestore and fullFinanceReset

The existing standalone encrypted restore parity preflight (M187) can now be
reached from Waffra's restore UI **only when** an independently verified
SQLCipher source is selected. It authenticates the chosen archive, stages
a completely separate random temporary encrypted SQLCipher file, attests
finance rows and receipt bytes, closes/reopens it, and verifies that the
original Home/Widget source generation/digest never changed. The UI shows
a non-authorizing result; it never swaps keys, ledger, receipt bytes or
app/widget pointers. Guarded-legacy imports retain their old path.

The full-finance-reset UI checks the latest authority before building or
publishing a legacy-style wipe. If source selection requires SQLCipher,
it **refuses** until an authenticated externally saved backup, OS key and
hardware recovery / journaled reset process have independent evidence.
Failure to load the source also refuses without displaying an empty ledger.

**Still NO-GO:** This deliberately does not activate source replacement or
perform encrypted full reset; account owner-bound restore, separate bank SMS
originals, crash-atomic source handoff and signed 2-phone tests remain open.
Synthetic CI results cannot certify either route in production.
