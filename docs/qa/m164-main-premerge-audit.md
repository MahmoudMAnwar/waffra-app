# M164 — isolated M160/M161 main ancestry & conflict audit

## Verified source-level inputs
- Reference integration PR: #165, inspected head `0242b54d1e77f1539eef3fa12d77e06fbc9eeabf`; base main `dbd1605d61a8b522e6c0736ca9b1466b563c74aa`.
- GitHub commit comparison at inspection: **ahead 713**, **behind 0** (head compared with base), PR marked **mergeable** and **draft**. Mergeable is not evidence of successful CI.
- `docs/m160-main-reconciliation.md` describes manual reconciliation of main-only legacy backup QA with M158 UI/privacy/SQLCipher staging.
- `lib/storage/waffra_production_cutover_release_gate.dart` returns `automaticallyActivateSqlCipher => false`.
- `lib/waffra_secure_backup.dart` defines V2 Argon2id encryption and V1 PBKDF2 *decryption* compatibility. V1 exports are legacy/internal, never authorized as new user archive exports.
- Google services configuration and original guard/test files exist in reference branch. No real Google sign-in or Android installation was performed.

## Repeatable automated checks
Run `bash scripts/qa/m164_validate_m160_ancestry.sh` at a checkout with full Git history; this checks original main and M158 ancestors, detects newer main commits, flags whitespace/conflict markers, and fails closed if mandatory backup/guard source files or explicit no-cutover policy disappear.

## Outstanding blockers to approving main
1. Required same-head M160/M103/M124 CI must complete and pass; queued checks are not successes.
2. Review the full 386-file cumulative PR diff for unintended behavior/privacy changes (this audit is NOT a full per-line security sign-off).
3. Signed Android build and actual physical Android device + restore/Widget/receipt checks remain independent requirements.
4. No production SQLCipher source switch, data migration, Firebase production deployment, or main merge without separate owner approval.

**This milestone is a source review and repeatable guard only.** No real balances, production accounts or user data accessed.
