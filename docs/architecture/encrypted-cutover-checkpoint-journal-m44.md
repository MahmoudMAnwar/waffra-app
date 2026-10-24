# M44 — durable encrypted finance cutover checkpoint, fail closed

Waffra's current finance UI and Android widget still use SharedPreferences. The encrypted repositories and M43 guard protect users from unsafe access after interrupted source conversion, but cannot activate a new finance source until every writer is coordinated.

This experimental journal persists durable **prepare → verified → active** evidence in SQLCipher, using exactly one unique source digest and one unique target finance digest.

- Prepare refuses unmatched encrypted finance content, invalid digests, staged migration data or attempts to overwrite a previous source checkpoint.
- Verify independently rereads and authenticates the entire encrypted finance snapshot. It rejects any transaction with a remaining legacy receipt path, which needs a separately proven image-byte migration.
- Marking external activation is not allowed until both external-source evidence and routing of **all** writers are acknowledged. This API does not create/alter a real external source marker or change user account data.
- Cold-start recovery requires SQL phase active, external marker, readable encryption key, routed writers and unchanged target digest. Disagreement leads to manual reconciliation; no silent new blank balance or legacy fallback.
- Tests cover replay, restart, lost key, interrupted marker, digest mismatch, unknown receipt path, disabled experimental gate and source parity.

**NOT YET READY FOR LIVE SWITCH:** This journal has no full-durable writer freeze or actual authenticated external activation marker, production UI adapter, receipt display/migration and user-visible rollback. Existing M43 guards still block old writers when activation/pending marker exists. The user must never get a marker set by this experimental service on an actual device. Firebase remains last.
