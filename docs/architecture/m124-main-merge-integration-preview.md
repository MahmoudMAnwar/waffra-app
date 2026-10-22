# M124 — Full integration preview targeting main (not a merge authorization)

This isolated draft branch retains **all candidate development through M123**
and adds only the independent main-integration CI workflow. It does not
switch storage, set Firebase markers, migrate user data or merge a pull request.

## Why preview the full chain?

Individual feature PRs are stacked against their parent branches. Their green
checks prove only the scoped feature diff, not that the complete set can be
safely merged into main. The M124 preview instead targets `main` and reruns
integration tests over the cumulative candidate.

## Invariants

1. `firebase/google-services.json` must match the current `main` copy
   **byte-for-byte**; never overwrite the registered Android OAuth values.
2. SQLCipher activation remains disabled: no new `WaffraEncryptedFinanceSession`
   construction in `main.dart` or the widget, and no unverified encrypted
   receipt panel mount in the legacy UI.
3. Main/widget bank SMS confirmation remains source-gated. Never select a
   different empty balance or plaintext fallback when encrypted witnesses
   require manual recovery.
4. Receipt recycle is experimental and reversible; a clock supplied by the
   device is *not* trusted time. 30-day rollback/expiry tests are not
   sufficient to authorize production retention enforcement.
5. All Android emulator tests use synthetic encrypted vaults. Passing these
   does not establish a physical device backup/restore or app migration proof.
6. Do not merge, deploy Firebase rules, change `main`, or opt in real-user
   storage before signed Android device QA, device-to-device restore, privacy
   disclosures, complete route audits and explicit owner approval.

## CI runs concurrently

- **Firebase/main source parity + opt-in safety**: fast static audit
- **Encrypted finance/receipt recovery**: Dart analyzer and finance tests
- **Receipt UI/source authority**: widget and policy tests

Existing Android emulator, full finance/UI, and M103 release-certificate
workflows also run on this cumulative PR because their path scopes changed.

## Decision rule

Treat *every* failed or cancelled required CI check as unresolved. The
resulting PR is a **draft merge preview**, not a production activation PR.
Current main may acquire new commits: rerun the parity audit and re-evaluate
the preview before any approved merge. Do not merge a large stacked chain
until review scope, change ownership, Android signed-app tests and all safety
blockers have independent sign-off.
