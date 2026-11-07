# M323 — Waffra autonomous Flutter CI repair (Codex)

## What it really does

After every **same-repository** feature-PR CI workflow has finished on the **exact source HEAD**, the M323 workflow detects actual failed or timed-out checks, collects a bounded diagnostic snapshot, and runs the Codex GitHub Action with a workspace-only sandbox. Codex edits Flutter/Dart code and can add regression tests. A separate trusted publisher applies only validated `.dart` patches and pushes a fast-forward commit to the **original feature PR branch**. This push triggers the next PR CI cycle through a dedicated GitHub write token. It never directly commits or merges to `main`.

The workflow reacts to critical `workflow_run` completions and also scans open PRs every hour for remaining checks or race conditions.

**Autonomous cycle cap:** 3 source-code repairs per PR branch (commit subject `fix(auto-ci):`), and only **one AI model attempt per exact commit SHA** while its attempt marker artifact is retained. A new commit means a new SHA, so a genuine repair can proceed to the next cycle. A stale SHA loses the fast-forward check and cannot overwrite a human update.

## Required one-time setup (not done automatically)

1. Merge the reviewed M323 implementation PR into `main` after its independent CI validation. `workflow_run` automations only activate from the default branch.
2. In [Waffra GitHub Actions secrets](https://github.com/MahmoudMAnwar/waffra-app/settings/secrets/actions), add `OPENAI_API_KEY`: an **OpenAI API-platform key**, not a ChatGPT subscription or password. Calls may incur API charges.
3. Add `WAFFRA_AUTOFIX_GH_TOKEN`: a **fine-grained GitHub personal access token** limited to `MahmoudMAnwar/waffra-app` with **Contents: Read and write** and repository metadata read access (or an equivalent appropriately scoped GitHub App installation token managed by the workflow). The token identity must have permission to push to the nonprotected feature branch. It must not bypass branch protections. Do not put the token in a tracked file.
4. Ensure Actions are enabled and the repository permits the official Codex Action. Review third-party action pinning as part of repository policy.
5. Use GitHub Actions **Run workflow** for a first controlled trial, or let the next failed PR CI event trigger automatically. Inspect the initial auto-fix commit and rerun results before expanding scope.

Both secrets are checked before anything is sent to Codex; without them, triage exits without initiating a model call. This repository change **does not create secrets or activate the agent by itself**.

## Safety policy

- Only PRs targeting `main` with branches originating in this repository are eligible. Fork PRs, `main`, Codex/autofix branches and incomplete CI are ignored.
- A source SHA must have all its discovered PR workflow runs in a terminal state. No stale passing run can excuse failures on a newer SHA.
- Code-writing credentials are **never** present in the Codex generation job. The model receives a read-only diagnostic snapshot and may only produce patches. The separate publisher job rechecks the patch with a trusted copy of the guard from `main`.
- Only `lib/**/*.dart`, `test/**/*.dart` and `integration_test/**/*.dart` may be written automatically; deletions, workflow edits, signing, secrets, platform and dependency configuration changes are rejected.
- At most 12 Dart files and 850 changed lines in one proposed patch. A clean patch, Flutter analyzer, and the original branch's unchanged head are mandatory. No force pushes.
- No automatic production SQLCipher cutover, migration, release signing, APK publication, finance-data deletion, security policy changes or `main` merge.
- CI-only or infrastructure problems (SDK/NDK/emulator, stale `main`, signing) might need a **separate human-reviewed workflow fix**. The Codex instruction explicitly avoids guessing at these issues.
- The workflow uses OpenAI Codex to analyze code and CI logs. Do not include real customer financial data, credentials, or raw sensitive records in test logs; review repository privacy policy before enabling.

## How to know it works

1. A controlled failing test on a trusted open feature PR finishes after other PR workflows; triage identifies its exact head SHA.
2. An `m323-attempt-<SHA>` artifact records that one model attempt was initiated on that revision.
3. The Codex job generates only Dart source/test edits, and both the generation and publication guards accept the patch. The original PR gets a commit `fix(auto-ci): ... (round N/3)`.
4. GitHub workflows start again because the scoped write token (not `GITHUB_TOKEN`) authored the push.
5. If another source-level failure remains, repeat on the new SHA up to three rounds. If all required checks succeed, stop. Merging and production APK creation remain governed by independent release checks and approvals.
6. If Codex cannot safely fix a failure, no change is published, and the attempt marker avoids repeated identical API charges until its retention expires.

Run premerge acceptance with `python3 -m unittest discover -s scripts/qa/tests -p 'test_waffra_autofix_cycle.py' -v` and inspect the new `configuration-tests` job on M323 PR.

## Limits to document

This is **automatic code repair, not guaranteed bug resolution**. The selected failing logs may be incomplete, CI environments may be flaky, and generated patches can be rejected. The M323 workflow never silently changes a release-ready status and does not replace physical-device SQLCipher, OCR and Google Sign-In acceptance.
