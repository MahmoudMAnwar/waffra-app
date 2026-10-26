# M236: launch the 20 outstanding finance routes as independent QA lanes

This PR launches **20 separate GitHub Actions matrix jobs**, one for every
WaffraFinanceRoute except the four amended by M235 (#11, #18, #19, #22).
All jobs are queued independently with fail-fast disabled, and up to ten
execute simultaneously to limit external package rate limiting.

Each route must show a real source-boundary callsite in app/widget/authority
and must reject interrupted recovery, absent encrypted keystore witnesses and
a missing exact-route audit, without touching guarded legacy preferences.
This is an initial **negative-safety boundary** for each route; it is not a
claim that all 20 routes are fully wired, that live data migrations worked, or
that backupRestore and fullFinanceReset are production-ready.

Next independent implementation streams need successful runtime SQLCipher
roundtrips for: startup/cold reads and widget (#1–4,#21), typed ledger/SMS
writes and dedupe (#5–10), category/goal/recurring/challenge/merchant edits
(#12–17), encrypted attachment rollback (#20), and atomic authenticated
active backupRestore/fullFinanceReset (#23–24). The last two remain explicit
production blockers. On two real signed Android phones, certify all 24
plus exact receipt bytes, original SMS, crash recovery, and OS key loss.

**NO-GO**: No source activation, main merge, user APK, release credential,
or fake production evidence can be created by M236.
