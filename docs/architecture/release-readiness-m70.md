# Waffra M70 — Combined finance, receipt and cloud validation

## Scope

This **draft, unmerged** release-validation branch combines:
- M67: independently gated SQLCipher finance session interface for Home, goals,
  categories, recurring values, SMS hashes and widget transaction writes;
- M68: password-authenticated portable finance + SQLCipher receipt BLOB
  backup/export, exact source/attachment parity, second-device restore;
- M69: verified-consent Firestore bootstrap, transactional compare-and-swap
  conflict decisions, authenticated read-only known-record previews;
- M70: Android database cold-restart and attachment round-trip test, complete
  Flutter unit/UI suite, Android emulator suite, Firestore emulator security
  rules tests, and Android ARM64 APK build.

## Non-negotiable release blockers

1. **Do not activate production SQLCipher yet.** MainScreen, Widget, reminders,
   category bootstrap and some preference writers still use guarded legacy
   SharedPreferences. Migration must freeze all writer engines and verify
   source/receipt consistency under one durable activation selector.
2. **Do not activate Firebase cloud uploads/downloads yet.** New-device record
   discovery requires an encrypted ID manifest, cross-device key recovery and
   conflict resolution that never silently overwrites the local ledger.
   The current transport only handles opted-in, already encrypted outbox items;
   remote known-record reads are previews and NEVER install into user finance.
3. **Do not deploy the candidate Firestore rules or merge draft PRs** before
   production consent/key security review, Firebase emulator coverage, schema
   rollout safeguards, rollback/wipe plan and on-device release verification.
4. **Do not treat a passing APK build or emulator suite as proof of a
   complete live migration.** Key-loss, device restore, crash during cutover,
   mixed-version installs, widget concurrency, duplicate SMS, accessibility
   and genuine two-device cloud-conflict acceptance must be demonstrated.
5. **No bank account integration, credentials or raw bank SMS storage/upload.**

## Final CI acceptance gates

- Strict Dart storage analysis and all Flutter app/unit/widget regressions.
- Offline encryption parity, portable export/restore and tampered-receipt tests.
- Android encrypted DB integration with M70 cold-restore test and per-test
  timeouts; Android isolated encrypted storage integration.
- Firestore emulator rules: authenticated owner access, encrypted-only payload,
  strict version increments, anti-replay/conflict and no physical deletes.
- Signed ARM64 APK artifact attached to the same tested commit.

No automation or workflow in this branch intentionally changes production
Firebase or a real user's on-device financial data.
