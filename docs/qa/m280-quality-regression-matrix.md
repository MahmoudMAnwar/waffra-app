# M280 — Ten-domain QA acceptance matrix

## Automated tests (disposable synthetic records; do not touch production)
| ID | Domain | Evidence and remaining device gate |
|---|---|---|
| financial_integrity | Exact integer minor-unit totals, 100-entry batch, 96 concurrent app/widget commits, no lost updates, no duplicates, rollback |
| crash_recovery | Encrypted cold reopen retains digest and generation; physical device force-stop mid-transaction remains pending |
| sqlcipher_24 | Existing real SQLCipher candidate source, atomic snapshot, restore preflight re-run; **24/24 active production cutover remains NOT VERIFIED** |
| two_device_restore | Wrong-password and tampered backup fail closed in host tests; physical phone A→B restore, receipts, note parity and cloud recovery pending |
| sms_fuzz | 100 diverse synthetic SMS, malformed unicode, rejected OTP/preauth/declines, direction and hashes |
| rapid_taps | Parallel identical SMS confirmations save once, parallel distinct app/widget confirmed transactions do not disappear |
| performance | Synthetic hundred-record and 96-record loads; actual 60/120 Hz frame jank, p95 tap-to-confirm, CPU/battery on physical phones pending |
| accessibility | Full Android/iOS RTL/LTR, dark/light, text at 200%, touch target and IME tests owned by M274/M277/M278; retest combined HEAD |
| penetration | M279 security rules, backup, PIN and permissions; manual OWASP MASVS API/TLS, rooted devices, memory and screenshot test pending |
| combined_apk | PR274–PR279 plus M280/M281 must be tested together, same exact SHA signed Android APK/AAB and real-device smoke pending |

## Additional feature QA required on same candidate
- Data health: duplicate suggestions do not delete ledger or reveal bank SMS.
- Advanced search: search predicates/filters operate on verified read-only snapshots, never on plaintext cloud or other user account.
- Receipt assistant: permission denial, giant files, corrupt images, no silent OCR claim, explicit user confirmation before expense write.
- Month closing: reconciliation rounding, year boundaries, cancelled close leaves ledger unchanged and snapshot generation stable.
- Diagnostic support: no account numbers, phone, receipt path, bank body, monetary amounts, exception stack or device identifier escapes.

## Release decision: NOT DEVICE CERTIFIED
Successful host/emulator checks are not proof of physical Android/iPhone safety or of activating SQLCipher across all 24 routes. The final release needs:
1. Integrate all PRs into one candidate SHA without changing finance routing or forcing main;
2. Full flutter analyze/test on that combined SHA, plus static/security/supply-chain, performance, Android/iOS safe-area tests;
3. Signed APK install/upgrade, app/widget cross-engine write, lock/biometrics and screen privacy, physical crash/restart, Wi-Fi/offline conditions;
4. Signed AAB/Play policy audit, separate iOS Runner certification, encrypted backup/restore on two devices;
5. Triage every failure. No auto-merge and no claim that any feature exists in an APK without verifying the generated artifact.
