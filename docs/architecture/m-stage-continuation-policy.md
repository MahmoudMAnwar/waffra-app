# Waffra M-stage continuation policy (owner-approved, 2026-10-22)

## Standing instruction

Whenever an M-stage has **actually finished** and its required checks have passed, continue directly with the next dependency-ready M-stage without waiting for another message from the project owner. Parallelize work that does not depend on unfinished stages. Share links to commits, PRs, tests, and failures as they become available.

## Evidence required before calling a stage complete

1. Actual implementation and tests committed to GitHub, not just a milestone title, issue, or planning document.
2. Required unit, widget/UI, Firebase rules/emulator, Android encrypted storage and Android runtime integration workflows have concluded successfully on the **same final SHA** whenever applicable.
3. The work's acceptance criteria are met; passing CI on a partial draft PR is not the same as completing a whole stage or releasing to users.
4. All safety prerequisites and blockers documented, including app/widget writer parity, encrypted receipt bytes, key loss, offline replay, restore and rollback.

## Boundaries

* Use isolated branches and draft PRs for unverified changes; do not force-merge to main.
* Never silently enable an encrypted source marker, migrate a user's live data, deploy production Firebase rules, or upload raw/unencrypted user banking content.
* Production cutover, key recovery activation, destructive reset, and any irreversible external action require a separate verified release gate and project-owner approval.
* Stop on a security or data-integrity failure, report exact errors and resume safe independent work.
* Do not promise unattended continuous code development outside an active execution or configured scheduled task. The hourly continuation task may check repository state and take safe next actions when its tools support them.

This policy records the project owner's requested working cadence; it does **not** change runtime finance behavior or release gates.
