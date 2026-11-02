# M385 — Do not edit features the user did not ask to change

## Non-negotiable product rule

Preserve **all previously accepted product behavior and UI** by default.
A new feature, design cleanup, performance optimization, or code refactor
is **not** authorization to alter an unrelated existing capability.

Example: M374 incorrectly removed the numbered green receipt-corner badge when
the request was to improve attachment access through transaction details.
M384 restores the badge without altering the user's saved receipt files.

## Required workflow for EVERY PR

1. Translate the user's actual approved request into the concrete, reviewed
   `user_requested_changes` in `docs/qa/approved_change_scope.json`. Do not
   invent or broaden the request. If the user has not approved a destructive
   or user-visible behavior change, **do not make it**.
2. Enumerate every changed file under `allowed_changed_files` and ensure
   the list matches `git diff --name-only <base> <head>` exactly.
3. For each existing production/runtime/source/workflow file, identify exact
   permitted anchored functions or job bodies in `bounded_sections`.
   Compare original and candidate content outside those boundaries byte-for-byte.
4. For changes to a previously accepted function, extend **positive**
   regression tests that describe the old behavior. The test suite must
   never silently be rewritten to assert its disappearance as "correct".
5. Run all source guard tests and ordinary finance/UI tests on the **same
   exact SHA**. Any mismatch, unexpected file, missing anchor, removal of
   a protected file, or unapproved legacy-code edit blocks merge.
6. Get the owner's affirmative review of the scope, behavior and expected
   result. The manifest is a claim by the PR author, not authorization by
   itself. Do not merge solely because CI is green.

## How the gate operates

`scripts/qa/m385_approved_change_guard.py` compares the original PR base
SHA and the exact PR head. It rejects files missing from the manifest,
modifications outside permitted anchored areas, and whole-file edits to
existing source files without section boundaries.

`test/qa/m385_approved_scope_guard_test.py` intentionally tests forbidden
changes to old features, unrelated files, run checks and scope anchors.

The M174 exact-SHA PR check runs **both** the hostile tests and the gate.
Normal main pushes run the unit tests but skip the PR-only source comparison.

## Important limits and human approval

This is a **diff-boundary protection**, not a machine capable of knowing
what the owner intended or deciding whether an edited function is correct.
Changes inside a declared approved section can still be harmful; human
review, visual screenshot/Android testing, and full regression are still needed.

For independent approval, GitHub repository administrators must configure
the **main branch ruleset** to require:
- The M174 Main SHA Post-Merge SQLCipher Regression check at the exact HEAD.
- Review from CODEOWNERS and dismissal of stale approvals on new commits.
- No direct pushes/bypass to main except tightly authorized maintainers.

The `.github/CODEOWNERS` file identifies the owner but **does not enforce**
approval unless branch protection / ruleset is enabled in repository settings.
Do not claim the policy is fully enforced until both workflow checks and the
repository ruleset have been verified.

## Next change

Create a fresh scope manifest for that PR with exactly the user's requested
features, allowed files and function boundaries. Re-run the gate on every
change; never reuse another PR's manifest as a blanket permission slip.
