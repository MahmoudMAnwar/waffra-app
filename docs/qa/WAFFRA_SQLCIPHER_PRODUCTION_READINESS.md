# Waffra SQLCipher production readiness — tracked after PR #402

**Tracking:** [Issue #421](https://github.com/MahmoudMAnwar/waffra-app/issues/421) · Dependency: [PR #402](https://github.com/MahmoudMAnwar/waffra-app/pull/402), [Issue #420](https://github.com/MahmoudMAnwar/waffra-app/issues/420).  
**State:** requirements recorded; implementation, CI and device acceptance **NOT DONE**. This planning branch is based on `main` to avoid contaminating the current feature PR. Reconcile with #402 after it merges.

| ID | Requirement | Owner | State |
|---|---|---|---|
| WAFFRA-DB-001 | SQLCipher authoritative production finance read/write + single-writer cutover across app/widget/entry points | Assistant | Pending |
| WAFFRA-DB-002 | Android Keystore, key recovery/rotation policy, encryption proof and privacy of logs | Assistant | Pending |
| WAFFRA-DB-003 | Fresh-install schema, startup, transactions, balances, process death and relaunch | Assistant + user device QA | Pending |
| WAFFRA-DB-004 | Lossless SharedPreferences v24 migration incl. IDs, transactions, budgets, goals, recurring, categories, SMS, receipts; rollback/idempotency | Assistant | Pending |
| WAFFRA-DB-005 | Retrospective historical account assignment and opening-balance parity; reuse #402/#420 | Assistant | Pending integration |
| WAFFRA-DB-006 | Encrypted V3 backup and restore with receipts and interrupted recovery | Assistant + user device QA | Pending |
| WAFFRA-DB-007 | Fix exact-SHA CI failures and automated encrypted runtime/migration/regression | Assistant | Pending |
| WAFFRA-DB-008 | Safe test on clean phone, then backed-up non-destructive update on spouse's phone after approval | User after assistant evidence | Pending |
| WAFFRA-DB-009 | Google Play signed AAB/APK, privacy/data-safety and third-party service disclosures | Assistant drafts + user approves | Pending |
| WAFFRA-DB-010 | Release notes, read-only ADB diagnostics, two-phone QA evidence and rollout/rollback gate | Assistant | Pending |

## Required acceptance sequence

1. Complete PR #402 code and exact-SHA CI. Test the new APK on the owner's **empty test phone**.
2. Resolve feedback and confirm the current finance source. Do not confuse SQLCipher integration tests or a shadow vault with **production activation**.
3. Implement a non-destructive, resumable, lossless migration and SQLCipher production cutover; use staging, row-count/amount/checksum parity, schema integrity and verified backups before changing source selection.
4. Verify automated and emulator tests, then produce a signed release candidate with clear release notes.
5. Obtain explicit approval before **any** test on the spouse's phone, where older app data exists. Ensure backup is independently restorable. Never uninstall/clear app data or execute destructive ADB commands.
6. Verify old records, linked/unlinked accounts, balances, images, goals, budgets, recurring, backup/restore and widget parity on device. Stop and preserve legacy data if any mismatch.
7. Document final CI results and Android evidence before production release.

## Status reporting

Always report **Done in code**, **CI passed**, **Android verified**, and **production activated** separately. Do not mark any row Done merely because it was recorded here or a CI-only sandbox passed.
