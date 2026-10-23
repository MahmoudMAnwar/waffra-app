# M145 — pre-merge QA integration audit (review only)

**Merge status: BLOCKED.** A green M145 job means only that the *two M144
test-only branches* can be combined cleanly at their sealed commits. It is
**not** approval to merge the SQLCipher stack into `main`, to switch the
running app to SQLCipher, to migrate real data, or to ship an APK.

## Verified branch lineage

- `main` → isolated UI and legacy-backup line:
  [M130 PR #137](https://github.com/MahmoudMAnwar/waffra-app/pull/137)
  → [M131 #138](https://github.com/MahmoudMAnwar/waffra-app/pull/138)
  → [M132 #139](https://github.com/MahmoudMAnwar/waffra-app/pull/139)
  → [M140 #147](https://github.com/MahmoudMAnwar/waffra-app/pull/147).
  This is the preferable *small-scope candidate* for a separately reviewed
  UI/backup merge. It still needs its own exact-SHA CI/release review.
- The SQLCipher experimental QA stack has extensive older ancestors.
  [M139 #146](https://github.com/MahmoudMAnwar/waffra-app/pull/146)
  → [M141 #148](https://github.com/MahmoudMAnwar/waffra-app/pull/148)
  → [M142 #149](https://github.com/MahmoudMAnwar/waffra-app/pull/149)
  → [M143 #150](https://github.com/MahmoudMAnwar/waffra-app/pull/150).
- M143 has **two distinct sibling M144 branches**:
  [#151 two-connection writer QA](https://github.com/MahmoudMAnwar/waffra-app/pull/151)
  (`d1218ed66ddcab2c9bc53fb8939b3c7e348fa28a`) and
  [#152 unsafe lock-path QA](https://github.com/MahmoudMAnwar/waffra-app/pull/152)
  (`b0b7fd5dfebecc58de18e14eb700641816901e57`).
  Both descend from M143
  (`11f9eb500963fcf81d46070f3ef4773d88647140`).
  Their changed paths were checked as disjoint.
- M145 is based on #152 and copies the **unchanged #151 test** into its
  review branch, alongside the #152 test. The dedicated M145 workflow
  exercises both M144 test suites together and validates their Git history.
  Do not treat the duplicate milestone number as two independent approvals
  to merge the same QA twice.

## Automated read-only audit

Run `python3 scripts/m145_premerge_audit.py` in the PR checkout. It checks
the exact source SHAs, common M143 parent, changed-file whitelist, path
non-overlap, bit-identical copied test, Git `merge-tree --write-tree` preview,
and the number of commits diverged from `main`. It emits a machine-readable
`build/m145-review-report.json` and an Actions step summary.

**The audit deliberately leaves
`main_merge_authorized=false` even on success.** `merge-tree` creates no
merge commit and the task performs no branch update or app data operation.

## Blockers before any `main` merge

1. Decide which **reviewed, minimum-scope** PR family may go to main first.
   In particular, do not merge the 600+-commit SQLCipher stack because its
   isolated tests passed. Reconcile the current `main` divergence.
2. Verify a clean, cumulative integration candidate on the *exact*
   intended main base, with Android APK build, offline finance/UI, recovery,
   and release certification. A green test on a sibling branch is not enough.
3. Finish real-device Home/Widget single-writer routing, encrypted
   source-authority checks, backup and receipt parity, two-device
   restore/sync evidence, and production migration rollback rehearsal
   **before** any live SQLCipher cutover.
4. Verify account/data deletion, privacy policy, Data Safety, crash
   reporting, signed-device smoke, and explicit user approval for each
   production-impacting action. No Firebase/Google Sign-In mutation.
5. Review and either supersede or incorporate both #151 and #152 without
   duplicating their tests, commits, or workflow changes.

M145 is a *review artifact* only. No real records or Google credentials are
used and no direct write to `main` is part of this milestone.
