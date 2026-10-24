# M174 — main SHA-specific finance release evidence

M173 test success on a PR head is not evidence that the merge commit in `main`
has been built or exercised. M174 adds an independent workflow with:

- `pull_request` to `main`: negative cutover tests, fail-closed source scan,
  SHA-pinned checkout and an auditable **NO-GO** JSON artifact.
- `push` to `main`: the **same checks on the exact merged commit**, plus an
  Android ARM64 release-mode compile for later manual installation. This is
  NOT a verified, signed Play-distributed binary and NOT a physical-device test.
- `workflow_dispatch`: operator-triggerable rechecks without production side effects.

The existing M147 workflow had a fixed M146 source baseline and file inventory
from an older PR, which would incorrectly reject an unrelated future QA-only
PR despite a green Flutter suite. Its exact historical review remains intact;
this branch adds a separate SHA + scope review **only for M174**. No other
PR, experimental production activation, or product code is exempted.

## Release remains explicitly blocked

The report intentionally requires `releaseReady=false` with non-empty
`hardBlockers`. No user finance content, bank SMS, private receipt, key, account
identifier, or Firebase token is read or uploaded. A GitHub-hosted compile cannot
replace the required signed-device startup tests, two physical phones restoration,
24-route verified SQLCipher routing, safe historical migration, published privacy
and account deletion paths, or owner-approved store release.
