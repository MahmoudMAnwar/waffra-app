# M202 — Real Android SQLCipher binder dry run, NOT production activation

**NO-GO for production. No new feature, no external data and no real-user
storage touched.** This change runs a new Android emulator integration test
against the same `WaffraProductionFinanceAuthorityBinding` constructor used
by Home and standalone Widget at startup.

## Actual Android acceptance (disposable)

- Creates a private *temporary* SQLCipher file and initializes a minimal
  two-witness synthetic source cutover with a hard-coded test-only key.
- Binds the Widget startup route to an existing encrypted file, confirms a
  synthetic POS expense with a SHA-256-shaped fingerprint, and checks its
  exact integer minor-unit count.
- Closes the Widget's SQLCipher connection, reopens through the Home startup
  binding and checks the same transaction ID, amount and generation.
- Rechecks Widget read after the Home cold reopen.
- Confirms the first 16 bytes are not the plaintext SQLite file signature.
- Verifies the wrong key and missing release evidence both reject startup.
- Confirms the test-only legacy SharedPreferences ledger is untouched.
- Deletes all temporary test data at the end; test failures also clean up.
- Requires an actual Android **emulator** runtime, not Dart mock-only tests;
  no ADB capture or synthetic attestation is misreported as a real phone.

## What this does NOT prove

The fixture injects a synthetic source guard and all-green synthetic
release flags **only inside integration_test**, so it is not an OS-backed key
or genuinely approved source cutover. This proves a real SQLCipher disk read,
an atomic write via existing authoritative paths, restart integrity and
source separation, but **not**:
- 24 independent live UI/Widget operation witnesses;
- on-device OS key or biometric enrollment and recovery;
- source-backed two-physical-device authenticated backup/restore;
- real app/wide Widget UI cold-start behavior;
- full account deletion or public privacy/Data Safety release approvals.

The pre-existing M201 CI suite already covers synthetic 24-route fail-closed
contract checks, historical migration, receipt parity, backup and recycle.
M202 strengthens actual on-Android **binder** exercise; it does not replace
any prior live-device release blocker.

## Operator-only tasks after this PR's CI is green

Install the exact reviewed signed APK on two physical Android phones,
exercise the real app and standalone Widget through independent route
instrumentation on an explicitly authorized isolated finance source,
run real source-backed A→B encrypted restore and receipt hash parity, and
review release evidence separately. Do not edit source markers manually or
set `automaticallyActivateSqlCipher` to true. Google Play stays last.

Artifacts from this workflow explicitly report **zero attested physical
phones and zero independently proven live finance routes**.
