# M240 — Independent route-inventory and real encrypted-writer regression gate

## Why this follow-up exists

M236 runs each of the twenty remaining `WaffraFinanceRoute` source
boundary tests with `flutter test --plain-name`. That deliberately selects
one named test per matrix lane. It **does not execute** the separately named
`M236 inventory exactly equals the twenty routes outside M235` test.
Twenty successful matrix jobs therefore do not alone prove that the matrix
covers all twenty outstanding enum members.

This independent gate executes the inventory test and, concurrently, the
M235 positive disposable SQLCipher storage suite to detect regressions in
the actual receipt BLOB / backup export writers. This does not rewrite M236
while its existing jobs are queued or running.

## Evidence and remaining parallel engineering streams

- **Routes 1–4 and 21 (Home/Widget reads, startup, balance):** prove active
  source selection, cold reopen, independent Flutter engines, tampering and
  missing-key refusal on *signed physical phones*.
- **Routes 5–10 (manual, bulk SMS, widget SMS, edit, delete/undo,
  delete-all):** prove exact debit/credit values, original SMS notes and hash
  deduplication, native-lock concurrency, transactional rollbacks, and
  successful durable reopen, not just an enum callsite.
- **Routes 12–17 (category/goal/recurring/challenge/merchant writes):**
  prove typed persisted rows, links to historic transactions, 30-day trash
  restoration, CAS conflict handling, and no skipped or duplicate postings.
- **Route 20 (receipt removal/undo):** prove BLOB ownership, immutable
  digest, retention clock and byte-exact recovery without touching balances.
- **Routes 23–24 (active backup restore and full reset):** require
  authenticated owner-bound restore, crash-atomic active source handoff,
  external recoverable backup and an independently verified rollback. M237
  currently supplies *preflight and refusal* only, not live restore/reset.
- **M235 routes 11, 18, 19, 22:** positive disposable source integration
  is meaningful but remains non-authorizing until same-head cumulative,
  real-device and cutover evidence exists.

## Promotion rule

Never count source-boundary/caller-string tests, synthetic audit flags,
disposable SQLCipher fixtures or a green route-inventory test as equivalent
to a production-certified route. Record separate states for
`callsite/negative-boundary`, `disposable SQLCipher roundtrip`,
`signed Android A/B recovery`, and `approved production cutover`.
A complete 24-member inventory is **necessary but not sufficient**.

No PR merge to `main`, automatic database-source activation, user APK,
real bank data or production certification from M240.
