# M147 — final `main` review candidate (DRAFT, no merge)

**This milestone does not merge code, activate SQLCipher, perform data
migration, deploy Firebase, or publish to app stores.** The candidate PR
targets `main` for direct comparison and remains in Draft until an explicit
separate merge decision.

## Exactly what is proposed for `main`

- The already-reviewed **isolated UI/backup line**:
  [M130 #137](https://github.com/MahmoudMAnwar/waffra-app/pull/137) →
  [M131 #138](https://github.com/MahmoudMAnwar/waffra-app/pull/138) →
  [M132 #139](https://github.com/MahmoudMAnwar/waffra-app/pull/139) →
  [M140 #147](https://github.com/MahmoudMAnwar/waffra-app/pull/147) →
  [M146 #154](https://github.com/MahmoudMAnwar/waffra-app/pull/154).
- Approved circular, physically-left add button in the Home/Categories/
  Goals/Recurring views, interface/tour tests, recycle cards, and backup
  export/legacy restore correctness and failure handling.
- The M146 test-only preflight and M147 read-only audit/CI.
- **No `lib/storage/` SQLCipher implementation, `native/` widget code,
  `firebase/` configuration, or package dependency changes** in the diff
  against the reviewed `main` baseline.
- Baseline main SHA `965e25a0d62ed94401b112086edccb0a4fde790b`;
  M146 approved CI SHA `fdad2c55fcc0c6e0676cfa9e4121bee34dfcdc02`.
  Both are pinned by the final audit. If main moves, the gate fails
  deliberately and must be reviewed and refreshed instead of force-pushing.

## Exact-head CI before making a merge decision

The M147 PR workflow, triggered against `main`:

1. Checks out the actual PR **head** (not GitHub's synthetic merge ref),
   compares against current `origin/main`, validates expected lineage,
   checks a literal allowlist of cumulative changed files, and rejects
   unexpected production SQLCipher, native Widget, or Firebase changes.
2. Runs the **complete Flutter test suite** on that same head. The successful
   M146 run already separately proved its six targeted UI/backup suites.
3. Compiles ARM64 Android release-mode on the same head. The generated
   APK is attached strictly as an **uncertified CI review artifact**;
   release-mode compilation is not proof of production signing or working
   Google login on a real phone.
4. Archives a JSON review report with flags
   `main_merge_authorized=false` and `store_release_authorized=false`.
   Passing checks is evidence for review, **not** automated authorization.

## Remaining gates and owners

- **Human merge review:** verify the actual PR diff, confirm intended UX and
  legacy backup semantics, ensure no migrations or secrets were introduced,
  and obtain explicit user permission to merge to `main`.
- **Device owner:** test a correctly production-signed Android APK on a real
  device, clean install and upgrade, Google sign-in with registered SHA and
  Firebase configuration, light/dark and Arabic/English screens, widget,
  export and restore of new and legacy backups, and app restart. Mark all
  observations as tested on a real device only when actually done.
- **Release owner:** review published privacy policy, account deletion/data
  deletion experience, Data Safety, Crashlytics, and the store listing before
  any external rollout.
- **Separate SQLCipher track:** M145 and earlier SQLCipher QA does not enter
  this candidate. Live Home/Widget encrypted writer routing, source
  validation, recovery, real-device two-device sync, and reversible user data
  migration remain independent cutover blockers.

## Rollback plan: only after an authorized merge

**Preferred method:** review and squash-merge this isolated, direct-`main`
candidate after explicit approval and all relevant CI checks. Record both
the base SHA and resulting squash-merge SHA, plus the signed release version.

If a regression appears after merging but *before releasing*, create a
separate reviewed revert PR against `main` that reverts the precise squash
commit, run the same CI, and require approval for the revert; do not silently
rewind `main`. A green revert does not automatically roll back installed
APKs or cloud state.

If a regression appears *after a release*, first stop rollout through store
controls, assess real-user impact, preserve recoverable encrypted backups,
and produce an explicitly versioned corrective update. Never delete or
rewrite real user data in a code rollback. Account auth state and app-store
rollout cannot be undone by Git revert.

**Stop conditions:** any failed required M147 step, unexpected diff,
changed `main` SHA, unverified device authentication/restore, or missing
explicit merge permission. No merge or store action is performed here.
