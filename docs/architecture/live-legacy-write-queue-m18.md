# Storage M18 — the first narrowly scoped live-app persistence integration

Unlike earlier storage spikes, this PR changes one existing app function:
`_HomeScreenState.persist()` in `lib/main.dart`. It intentionally does **not**
switch the financial data source, run a SQLite cutover, enable Firebase, or
modify UI design, localization, reports, categories or SMS interpretation.

## Bug/race eliminated within this app instance

Legacy `persist()` previously launched several SharedPreferences writes with
`Future.wait`. Multiple async calls to persist could overlap, and an older
slow save could overwrite newer values even after the latest user operation.

`WaffraLegacyWriteQueue` now:

- Synchronously serializes **each complete financial-state snapshot** before
  awaiting any async operation. Later in-memory edits do not modify an
  already enqueued snapshot.
- Applies full snapshot batches in submission order using awaited individual
  key writes, checking the returned persistence status.
- Returns the original failure to callers while allowing subsequent batches
  to run; failures do not permanently poison the save queue.
- Offers a `drain()` primitive for a future coordinated migration. This is
  only in-process and does NOT freeze native widgets or another Flutter isolate.
- Preserves all existing SharedPreferences keys and values, and refreshes the
  home widget after successful save as previously.

## What this does NOT solve

- SharedPreferences writes to multiple keys **are not atomic**. Power failure
  during a batch can leave inconsistent data; a genuine transactional encrypted
  repository is still mandatory for future cutover.
- Android native quick-capture writes may bypass this process entirely.
- Some direct SharedPreferences writers (SMS hash set, widgets, preferences,
  export/import and other flows) remain outside the queue. Audit all before
  any migration write barrier/cutover.
- UI state may already have mutated before a persist error is returned.
  Production save-failure UX, retry, rollbacks and full integration tests
  remain release blockers.
- Existing finance data is still the legacy source, and no private financial
  records may be uploaded solely from Google authentication.

## Verification and release position

Automated race/failure/order tests live at
`test/storage/legacy_write_queue_test.dart`. Review Flutter compilation and
full-app smoke before merging, because unlike earlier drafts this touches
`lib/main.dart`. Keep as a Draft PR, stacked on PR #20 for now. Do not deploy
production until a separate main-branch integration review and manual mobile QA.
