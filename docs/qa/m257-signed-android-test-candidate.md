# M257 — signed ARM64 QA candidate for build #705 Pull-to-Refresh report

## Purpose and limits

Prepare an **owner-only, non-production signed Android APK** that incorporates
the stacked M253→M254→M255→M256 code plus M257's safer bounded verified
refresh recheck. This is NOT a new production release or a SQLCipher cutover.
The user reported that in trusted installed build #705, pulling to refresh
sometimes showed the financial recovery screen and tapping Retry then
restored correct data. We cannot prove the underlying transient cause from
that screenshot alone. This change adds exactly one independent authority
reread after the first unsuccessful read/integrity check; a second error
still fails closed. It cannot display unverified cached transactions.

## Build rules

- Exact source SHA and branch are stamped inside the APK's assets.
- `.github/workflows/android.yml` is enabled for this one additional
  `feature/m257-refresh-recheck-signed-qa-candidate-20261026` branch only.
- Existing workflow requires complete Flutter/Python regressions,
  all completed same-SHA independent workflows, matching Waffra signing
  certificate, an intact signed release APK, SHA provenance receipt, and
  updated approved release notes before publishing the **QA Artifact**.
- Do **not** fetch or describe an APK as ready unless GitHub's **build** job
  and its **last** artifact-upload step are both `completed/success`.
  A green M257 source test alone is insufficient.
- The workflow also builds an internal AAB candidate as part of its existing
  process; it is **not** uploaded to any Play production track.
- No change to activation flags, secure keystore material, Firebase config,
  backup/export, receipts, SMS storage route, or app user data.
- Do not automatically merge this PR into `main` or change release-policy
  safeguards. This is an isolated test-only preview.

## Physical-owner regression to confirm before approving anything

Use only synthetic test transactions/receipts. First record the old known-good
#705 data safely; a signed APK with the **same** package ID may upgrade that
installation, so the owner must confirm the environment and rollback plan.

1. Confirm installed test app's source SHA and signer against the exact
   GitHub Artifact build receipt. If provenance is absent, stop.
2. Enter income + expense, a goal, a recurring payment, category budgets and
   an attached synthetic receipt. Confirm displayed totals.
3. Pull-to-refresh Home, Categories, Goals and Recurring repeatedly. Tap a
   different footer tab and back; quickly repeat gesture while Widget writes
   one synthetic transaction. Expect no bogus recovery screen and no lost
   balance, receipt, or category. Repeat after force-stop/reopen.
4. With a *deliberately corrupt/incomplete/disconnected* test finance source,
   the screen MUST still refuse to show unverified or empty data and demand
   safe recovery; the one reread cannot turn a real integrity error into
   apparent success.
5. Repeat online, offline, with a slow device, and after Android app
   lifecycle pause/resume. Keep redacted error observations privately.
6. On two actual Android phones, independently verify signed source/binary,
   OS-backed key recovery, 24 live routes, receipt byte parity, backup
   restoration and app/widget concurrent writers before production release.

## Approval state

Even with a signed test APK and green hosted CI: **PRODUCTION NO-GO** until
physical on-device #705 regression is witnessed, plus the M254/M256
two-phone tests, app deletion/privacy, source recovery and human approval.
