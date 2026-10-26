# SQLCipher production cutover — readiness work (NO-GO)

Base: `09f2de05fb876c986abfc0029e3d74e7972c386e` (PR #265 already merged).
This branch is for readiness evidence only. **Do not flip activation flags, write source markers, or migrate user data.**

## Verified baseline
- M174 post-merge CI passed, but its `m174-main-sha-no-go` artifact intentionally asserts `productionSqlCipherActivated=false` and `releaseReady=false`.
- `WaffraProductionCutoverDecision.automaticallyActivateSqlCipher` is false.
- The source guard reports `all_live_writers_not_yet_routed` when an encrypted source is marked active.
- M201 inventory enumerates 24 routes, but explicitly records zero independently attested live-route witnesses and zero physical phones.
- M202 exercises a disposable Android emulator source binding; it does not certify a real widget engine, OS key recovery, or physical phones.

## Work sequence (parallel where independent)
- [ ] Inventory each of the 24 runtime call sites (Home, standalone Widget, manual and SMS save, edit/delete/undo, categories, goals, recurring, receipt attach/view/restore, backup/restore/reset). Record current writer, reader, source guard, evidence, and test.
- [ ] Implement a single guarded finance authority for real readers/writers on a feature branch. Keep legacy behavior intact and fail closed for inconsistent SQL activation.
- [ ] Add independent route-level integration tests, including concurrency, 100-message paste, duplicate handling, receipts, and restart/crash recovery.
- [ ] Verify nonempty legacy migration and rollback with synthetic data, including note text versus original encrypted bank SMS and attachment hashes.
- [ ] Verify signed exact-SHA APK and source-backed operation evidence on two distinct physical Android devices; require backup/restore parity A → B and OS-key recovery.
- [ ] Review account deletion, privacy policy, Firebase Data Safety, Crashlytics, signing and OAuth as separate release gates.
- [ ] Require explicit human authorization and independent activation deployment only after every gate is green. Google Play remains last.

## Stop conditions
Never infer production activation from green compile/unit/emulator tests. Never force a pointer to SQLCipher if any live writer still uses legacy. Never silently fall back to an empty balance or reset on key, database, digest or checkpoint errors. Never upload keys, raw SMS, financial details, or attachments as CI artifacts.

References: `.github/workflows/m174-main-sha-postmerge.yml`, `docs/qa/m201-24-route-migration-receipt-device-acceptance.md`, `docs/qa/m202-sqlcipher-android-binder-dryrun.md`, `lib/storage/waffra_production_finance_source_guard.dart`.
