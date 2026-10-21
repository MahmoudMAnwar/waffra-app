# M45 — Correct journal recovery after legitimate new finance writes

A live encrypted finance source changes with every new transaction, goal or SMS. The M44 journal stored the **initial migrated snapshot digest**, then compared every later snapshot to that original digest when the app restarted. This would incorrectly classify genuine post-cutover user activity as data corruption and prevent access.

M45 fixes the invariant:

- The cutover source and target digests remain **immutable witnesses** to what was copied at activation.
- SQLCipher records `activated_generation` when a verified cutover is acknowledged by the external source coordinator.
- Later valid commits are allowed to increase the finance snapshot generation and change the snapshot digest; each cold start verifies the *current* snapshot's own checksum and ensures generation has not gone backwards.
- A snapshot at exactly the activation generation **must still match the original digest**.
- Replayed prepare/activation after later writes is idempotent and never overwrites the checkpoint.
- Corrupted current snapshots and decreasing generation are still rejected.
- New regression tests execute activation → add an income → close/reopen encrypted SQLite → recover from the updated balance, plus tamper and rollback cases.

This is a test-only reliability fix. **It does not turn on live SQLite for app screens, Android widget or SMS**. No Firebase involvement.

Real release gating remains: all finance writers and UI readers routed together, independently verified migration/receipts, secure on-device key management, durable two-witness activation and rollback, full Android app/Widget regression and APK acceptance.
