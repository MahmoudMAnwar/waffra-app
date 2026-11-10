# M632 P0 Acceptance — Issue #547
## Code root causes
- `launchIntro` releases splash after **one frame**, whereas `WaffraLaunchIntro` takes 1650ms.
- `_runAutoSmsRefresh` executes every SMS's bank/OTP/fund parsing and SHA256 inside the Flutter UI isolate; startup auto-import may page 4 times and native updates can queue duplicate full refreshes.
- In the first SMS review, `canConfirm` includes category validation, and the account picker itself requires `canConfirm`, making initial account creation inaccessible.

## Change and invariant matrix
- Intro onFinished callback triggers exactly once after animation completes, never on first-frame readiness; startup source verification remains independent.
- Pure-data worker classifies a verified native SMS queue, returns waiting/ACK actions, and never performs storage or native I/O. No credential, bank data or logging goes to networks; stale owner/login/suspension blocks changes to UI and native ACK.
- Native encrypted pending is always the only source of candidates, original SMS preserved, no auto financial writes. Excluded/committed ACK remains batched and failed ACK restores items.
- First account creation uses same production verified account writer and fresh read, no auto account silently; existing accounts keep picker; only a confirmed valid amount, timestamp, category and account unlock Yes.
- Keep all existing security checks and tests; do not silence regressions by removing assertions.

**Evidence:** Source-level implementation pending; Android profile-mode p95 and both-device persisted-data migration pending. No claim physical freeze solved until measured.
