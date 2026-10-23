# M146 — main-safe UI and backup certification (draft)

This is a **review-only** integration candidate, based on M140 and the
isolated M130 UI/backup line, which is a direct descendant of `main`.
It does **not** contain the experimental SQLCipher production cutover stack.

## Scope and evidence

- Approved UI improvements from M130: consistent physical-left circular add
  button, Arabic/English and dark-mode UI coverage, tour and recycle cards.
- Backup behavior and security: 8-character alphanumeric **new export**
  password, explicit legacy backup restore, authenticated AES-GCM, malformed
  archives rejected, Unicode and cross-archive integrity regression tests.
- M146 workflow verifies `main` is still an ancestor, refuses any unexpected
  file outside the exact allowlist, runs six UI/backup suites, and attempts an
  ARM64 release-mode Android compilation without uploading or publishing.
- No code in `lib/storage/`, `native/WaffraWidget.kt` or `firebase/` is
  modified by this candidate.

## Explicit gates still open

- A passing M146 workflow does **not** approve merge, Play Store release,
  physical-device validation, real data migration or SQLCipher activation.
- Verify Firebase Google Sign-In on a signed physical-device APK before
  shipping; M146's compile job is not an end-to-end authentication test.
- Verify fresh installation and legacy encrypted/plaintext restore on a real
  device, plus app restart, dark mode and RTL/LTR.
- Preserve and separately review the SQLCipher M145 test-only integration.
  Do not pull its hundreds of ancestor commits into this small candidate.
- After exact-SHA CI passes, request explicit user approval for the
  separately reviewed `main` merge.

## Proposed review order

1. Confirm M146 CI and Android build, review diff against current main.
2. Review the isolated M130→M132→M140 lineage, avoiding duplicate merges.
3. Run signed-device smoke and document any blockers.
4. Obtain explicit merge authorization. **No merge is performed by M146.**
