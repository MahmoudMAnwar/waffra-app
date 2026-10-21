# M43 — Live legacy-source access protection (production code path)

Prior PRs had implemented an encrypted SQLCipher finance infrastructure **only for disposable test databases**. The shipped application routes still persist transactions and related state through SharedPreferences, and Android's quick-add widget runs in a separate Flutter engine.

This milestone introduces a narrow, **real app path** that fail-closes unsafe legacy access when a future encrypted cutover is active or interrupted.

## Actual touched routes

- App/root startup detects either `waffra_encrypted_finance_active_v1` or `waffra_finance_cutover_pending_v1`; existing startup-error UI handles an unexpected marker rather than returning to an empty balance.
- Dashboard finance load, dashboard persist and Android widget-transaction reconciliation refuse to read/write old preferences when either marker exists.
- Widget initial load and confirmed-SMS save refuse old preferences if either marker exists; widget presents its existing local-data error message and cannot claim success.
- Before checking the marker, preferences reload from native storage so a second Flutter engine cannot rely on a stale cached flag.
- A corrupted/false marker is deliberately not treated as permission to go back to legacy: **marker presence is sufficient to block**.
- No marker is created or removed; existing legacy data, screenshots and other app settings are not mutated by the guard.

## Test and status

The tests cover existing-data preservation with no markers, active true/false/corrupt markers, pending marker, and actual widget view rejection. The stacked existing whole-app/Android jobs provide regression checks.

This is **not** completion of the source switch. Normal Waffra users still use SharedPreferences. Before any marker can be set, the future app must deliver: OS-backed encrypted key recovery, dual-witness activation/replay, cross-engine writer coordination, a single authoritative fully migrated finance source, image/UI compatibility, backups and user-visible recovery. Do not set a marker without such a ready route.

Firebase is deliberately unchanged. No bank-account integration.
