# M13 — Recoverable goals/categories (30-day prototype)

Implements the previously approved restore behavior for financial entities,
WITHOUT changing the running Flutter application.

## Local encrypted working copy

- Imports goals and categories, including already deleted records, from the
  verified lossless relational projection to a **separate encrypted working
  table**. The existing SharedPreferences source, immutable import JSON and
  ledger entries remain untouched.
- Rejects unverified vaults and duplicate IDs; re-preparing a vault never
  overwrites subsequent working-state changes.
- Future category and goal deletes receive deletion timestamps and optimistic
  versions; the recycle window is **30 days**.
- Restoring a goal sets its current **saved amount to zero**.
- Restoring a category resets its current **budget to zero**.
- In either case, past income/expense transactions stay untouched. Restore is
  not treated as a new financial credit/debit.
- Offline tests cover source parity, deleted/active imports, 30-day expiry,
  stale restores, independent vaults and historical-data immutability.

## Not yet connected / still required

- The **live app UI, list counters, delete confirmation and recycle bin** are
  not wired to this prototype. Main financial data remains SharedPreferences.
- Implement the full CRUD model for goals and categories, goal contributions
  as future auditable events (do not fabricate past contributions), receipt
  references and unified ledger analytics.
- Create a clear and tested 30-day cleanup policy after an encrypted backup
  and verified retention, avoiding accidental permanent loss. This prototype
  refuses restore after expiry but intentionally performs NO hard purge.
- Recurring schedule restore is separate and must require a newly selected
  next due date; it is not handled by the goals/category restore code.
- Synchronizing deletes/tombstones between multiple devices requires genuine
  atomic Firestore behavior; current cloud simulator cannot do that.
- Full UI writer integration, mobile release testing, Firebase project owner
  setup, E2EE recovery consent and PDPL/security review remain blockers.

**Safety:** The repository is disabled by default, has no app startup caller,
and is not ready for production migration or a main-branch merge.
