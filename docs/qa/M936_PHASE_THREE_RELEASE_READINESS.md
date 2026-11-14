# M936 — Phase Three source release-readiness inventory (NO-GO)

**Issue:** [#641](https://github.com/MahmoudMAnwar/waffra-app/issues/641).
**Same Draft PR:** [#640](https://github.com/MahmoudMAnwar/waffra-app/pull/640).
**Status:** repository gate implemented; owner device, artifact, and launch approval **Pending**.

This begins non-destructive release readiness on the same Draft PR as Phase Two.
The exact earlier wording of "Third" has not been independently recovered; do
not treat this inventory as permission to broaden the product or enable a store
release. It is a bounded release *audit* rather than production activation.

## Code-side evidence (M936)

- `scripts/qa/m936_release_evidence_gate.py` validates an exact candidate
  40-hex source SHA and checks the independently retained M190 signed APK
  verifier, M267 two-device APK source/receipt verifier, M171 signed bundle
  source audit, M279 security/permission source audit, M449 release-note
  ancestry gate, and M935 owner-device acceptance plan.
- `test/qa/m936_release_evidence_gate_test.py` injects missing/changed
  security/audit files, missing UAT checklist, symlinked sources, and invalid
  SHA; they must be rejected. A complete source inventory remains **NO-GO**.
- The existing M550 early preflight runs these tests and the source inventory
  before expensive Flutter suites; **no new CI workflow** is created.
- No `lib/`, `android/`, manifest, finance writer, APK signing config,
  keystore, Flutter runtime feature, or cloud deployment is changed.

Run locally:
```sh
python3 -m unittest discover -s test/qa -p 'm936_release_evidence_gate_test.py' -v
python3 scripts/qa/m936_release_evidence_gate.py --source-sha "$(git rev-parse HEAD)"
```

A successful process exit means only that the **source controls are present**.
The JSON always returns `google_play_publication_permitted: false`,
`production_sqlcipher_cutover_permitted: false` and a NO-GO status.

## Owner-only readiness blockers

1. Complete Phase Two on the disposable test phone: real historical
   backup/restore counts and signed net parity, cross-restart, PDF, app screens
   and performance; don't touch spouse phone unless separately approved.
2. Compare signed candidate APK SHA256, signing certificate SHA256 and exact
   `main` source SHA independently; verify installed package using the existing
   M190/M267 tools on authorized physical phones. A GitHub build is not proof
   of installed APK identity.
3. Confirm final merged Android permissions and Saudi Play Data Safety
   declaration, Google login/Firebase certificate alignment, application
   versionCode, and Play internal/closed test distribution.
4. Inspect security protections on installed release build (biometric,
   recent-app privacy, SQLCipher encrypted database, permissions and receipt
   export). Check all 24 finance routes where relevant; don't claim hardware
   or route proofs solely from host CI.
5. Owner must explicitly approve launch only after signed artifact,
   two-handset private evidence and all unresolved defects are closed.

**Hard stop:** failure or missing evidence is a release NO-GO. Nothing in
this PR uploads an AAB to Google Play, changes signing, toggles financial source
cutover, or approves production.
