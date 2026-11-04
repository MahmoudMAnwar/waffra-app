# M228 — start of stage 1: 24-route SQLCipher source readiness

**Status: test/staging infrastructure, not production activation.** Base:
`8a460fa3d537ee7e8343b01e49d794140e66652a` (the real M227 merge). This change adds a strictly
read-only, exhaustive route preflight and wires its fail-closed decision into
the encrypted authority binding **after** checking the existing vault key,
active cutover checkpoint and original legacy source digest.

## What changed

- The preflight enumerates **all 24** `WaffraFinanceRoute` members using the
  existing source contract; there is no "24 passed" hard-coded boolean.
- For every route it reports guarded legacy, encrypted contract, or blocked,
  and lists unverified routes and missing key/SQL/external/recovery witnesses.
- The encrypted source binding rejects incomplete route contracts even after
  passing earlier release checks. A source/key/checkpoint mismatch still
  blocks access with **no fallback, no empty database creation, no auto-activation**.
- Tests deliberately remove each route in turn; every missing route causes
  refusal. They also test missing SQL/OS/external witnesses, corrupt source,
  immutable reports, and the fact that synthetic all-green claims are
  **never** equivalent to production authorization.

## Known production gaps (not declared solved)

The shipped Home and standalone Widget still start with **guardedLegacy**;
the independent activation/recovery release coordinator has not been approved.
Encrypted transaction and receipt writers exist for many routes but have not
all been proven end-to-end on two real signed Android devices. In particular,
`backupRestore` still deliberately refuses an activated SQLCipher source
rather than restoring from unverified legacy data. App/profile/attachment
migration and the encrypted original-SMS side vault need full recoverability
and parity evidence before actual cutover.

A green `WaffraFinance24RoutePreflightReport.allContractsAcceptEncrypted`
means *structural source-contract eligibility only*, and is not a live writer
test, OS key proof, authenticated migration, or user-data release decision.
`productionCutoverAuthorized` remains false by design. Real production
readiness requires independent 24/24 app/Widget evidence, encrypted receipts
and backups, cold start/restart/rollback, two real phones, and human approval.

## Next iteration

Integrate one missing route at a time under the existing native Home/Widget
lock, starting with encrypted `backupRestore` and side-vault SMS/receipt
parity, with rollback and corrupted archive tests. Gather independent Android
evidence per route before allowing any production source switch.

No real user data, keys, Firebase records, Play settings or activation markers
are touched by M228.
