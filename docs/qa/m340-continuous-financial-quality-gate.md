# M340 — Event-driven, whole-app financial QA gate

**Status:** PR-only candidate. No production cutover, no signed release, and no physical Android attestation.

## How it runs (no schedules)

The GitHub Actions workflow `.github/workflows/m340-continuous-financial-quality.yml`
runs on pull requests targeting `main`, on `main` pushes, and by manual
`workflow_dispatch`. No `schedule` or hourly ChatGPT tasks are necessary.
It checks out `github.event.pull_request.head.sha || github.sha` and
verifies `git rev-parse HEAD` equals the source SHA before each job.

Any new PR head cancels old M340 runs on that PR. Old run results must not
be reused as evidence for the new SHA.

## Required job matrix

| Job | Fail-closed acceptance |
| --- | --- |
| Finance, model and SQLCipher source control | Static checks for verified finance write authority, exact currency review, never-writing FX preview, conservative model answers, original-amount matching, and SQLCipher production defaults; mutation tests prove the gate detects disabled controls |
| Manual, bank SMS, OCR, FX and Ask Waffra | Runs existing high-risk and M335–M339 test fixtures including income/expense, 36 currency handling, OCR three-vs-six, FX quote consent, money precision, timestamps, duplicates, storage integrity |
| Analyze and test complete Flutter application | Runs Flutter analysis and **every** test under `test/`, not just files changed by this PR |
| **M340 exact-SHA quality verdict (device proof excluded)** | Requires every preceding M340 job to have result `success`. Failed, cancelled, pending or skipped jobs are not equivalent to passing |

## Important merge protection setup

Workflow failure does not automatically block a manual GitHub merge unless
repository protection makes this status check required. A repository admin
should configure a `main` branch protection rule / ruleset and require:

**`M340 exact-SHA quality verdict (device proof excluded)`**

Recommended additional required checks (retain the current repo-specific
names): `Waffra Full Offline Finance and UI Regression`, `M280 Finance
Integrity`, `M282 Combined Exact-SHA Acceptance`, `M124 Main
Integration Pre-Merge Audit`, `M103 Same-SHA Whole-App Release
Certification`, `M147 Main-Safe Readiness`, `M317 Qwen`,
`M287/M297 OCR`, `M292/M293 FX` and `SQLCipher NO CUTOVER`.
Because some existing workflows have path filters, before making a job
required ensure that it runs for **every** intended PR or adjust its trigger;
otherwise merge can remain blocked due to a missing check.

As of creation, no repository ruleset was returned by the available
read endpoint, and the connected GitHub integration did not have
permission to read or change `main` branch protection. **Required
status enforcement is not claimed as active.**

## Financial release / evidence blockers (must remain explicit)

- No AI-generated amount or type authorizes a transaction write.
- Manual, SMS and OCR transaction amounts need validated currency, minor
  precision, direction, category, and deliberate user confirmation.
- Foreign FX quotes require source, update time, rate, original currency,
  explicit consent and an atomic encrypted provenance record. The current
  M336 UI is a read-only preview; it does not persist converted money.
- SQLCipher encrypted source cutover is **OFF**. M340 does not enable it
  or prove device key recovery, 24 routes, backup/restore or widget parity.
- GitHub-hosted tests and Android emulator checks are **not physical
  Android hardware proof**. Actual OCR photos, 3-vs-6 SMS bubble detection,
  warm/cold Qwen latency, ANRs, haptics and RTL UI require a real-device
  acceptance run.
- Financial test fixtures must be synthetic; do not upload raw bank SMS,
  account numbers or user images as CI artifacts.
- A PR may not be treated as production-approved merely because its
  source checks or Flutter tests passed.

## Evidence to capture for each release candidate

Record the exact PR head SHA, all required workflow names and conclusions
on that SHA, physical Android QA device/build results, failed/retried
finance writes and storage-recovery evidence, receipt/backup parity, and
the manual release approver. No SHA change is permitted after final
acceptance without re-running the complete matrix.
