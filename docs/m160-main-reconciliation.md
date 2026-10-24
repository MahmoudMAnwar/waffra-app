# M160 — reconcile main M147 with passing M158

Source parent commits:
- M158 integration head: `c0eef7e2bfb5bb6836750af48d8b499d0ab30e63` (four same-SHA jobs passed on 2026-10-23).
- Protected main M147 head: `dbd1605d61a8b522e6c0736ca9b1466b563c74aa`.

This explicit two-parent merge preserves the M158 finance/SQLCipher staging implementations while retaining main-only M131/M132/M140 backup QA, M146/M147 review workflows, and documentation. Overlapping files were reviewed and the more recent M158 versions retained: `lib/main.dart` retains approved physical-left FAB and tour while moving encrypted backup export to private file storage, `lib/waffra_secure_backup.dart` retains V2 Argon2id and V1 compatibility, `test/m127_ui_tour_backup_acceptance_test.dart` retains updated V2/file-export assertions, and `test/waffra_secure_backup_test.dart` retains V2 and V1 coverage. `firebase/google-services.json` was identical in main and M158; existing M158 Android workflow was kept to avoid regression.

**This tree reconciliation is not proof of safe production SQLCipher activation.** Old M147 scope audit deliberately denies merging storage migrations without separate approval; do not remove or weaken it. Required independent gates: same-commit Flutter/static/backup/Android checks, verified real-device signed APK migration and restore including receipts and Widget, explicit owner authorization for finance source cutover. No bank integrations or SMS clipboard backup export are authorized.
