# M952 — five-axis continuation audit (Issue #657)

Baseline: merged #654 (M944) and #656 (M949–M951), including previously added 115 distinct functional cases. Do not count those cases again.

| Axis | First tranche work | Evidence | Status |
|---|---|---|---|
| 1 SQLCipher keyset | Inspect existing 2700-row source-backed pager + verification lease; preserve | M944 existing SQLCipher test and API; no new source mutation | Partial audit |
| 2 Large lists | Sender ID cache refreshed only after mutated queue; preserve all sender IDs, 100-card window and consent | Existing M940 SMS suite + new source contract | Code pending CI |
| 3 Finance parity | Review existing M948/M949–M951 parity; no writer change or real backup | Existing 10000-entry host tests and encrypted fixture suites | Partial audit |
| 4 Home split | Review existing extracted Home parts; avoid arbitrary extra wrappers | M944 extraction contracts | Partial audit |
| 5 CI | Duplicate start/suite, unknown suite IDs must fail closed; no raw error upload | Extended Python hostile-runner unit tests | Code pending CI |

**Acceptance:** only exact-head GitHub CI results count as passing; separately report passed / failed / skipped and approximate failure groups. Original financial encrypted source, owner approval, UI, + and Snackbar unchanged. Full real Android/legacy private backup tests remain external UAT, not falsely green.
