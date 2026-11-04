# M282 — M274–M281 combined release candidate acceptance

**Status: NOT PRODUCTION CERTIFIED.** This is a read-only/integration QA branch. Never auto-merge it to main and never treat individual green CI jobs as physical phone sign-off.

## Included eight milestones
| Milestone | Purpose | Verified evidence needed on identical aggregate SHA |
| --- | --- | --- |
| M274 | Responsive Android/iOS AR/EN UI journeys and golden candidate checks | Widget matrix / Android taps |
| M275 | Smooth finance confirmations, isolate large SMS batch parsing, double tap prevention and rollback | Full Flutter tests plus actual app intent tests |
| M276 | Synthetic finance performance baseline and Android profile test harness | Host p95 only, Android real frame pacing still pending |
| M277 | Accessible close notice at 48dp, RTL/EN footer and reduced motion | Real tappability at 200% text |
| M278 | 14 Android/iPhone Safe Area simulations, actual Android emulator + iOS simulator build | On-screen keyboard and physical phone review pending |
| M279 | Backup AEAD/PIN/cloud ciphertext/Firestore rules and permission gate | Firebase emulator, no real production credentials |
| M280 | Precise halala ledger accuracy and transaction count, 100 SMS, resilience to failed writes/restart, reject pre-authorization | Actual writer/snapshot unit integration and restore |
| M281 | Data health, local search with notes+attachment flag from verified Home, camera/manual receipt review, monthly-close PREVIEW, safe diagnostics | AR/EN widget journeys and all existing smart tools unbroken |

## Conflict-resolution witnesses
- M275 and M277 edit different areas of \`lib/main.dart\`; preserve the confirmation overlay and increase error notice close to 48dp.
- M280 fixes \`Online Pre-Authorization\` to reject pending holds rather than create a transaction.
- M281's latest Home projection includes both \`notes:e.notes\` and \`hasAttachment:e.receiptPath?.isNotEmpty??false\` so search reflects the actual local verified read model. No raw SMS is sent to Firebase.
- The M281 five tools are inside the Tools footer, **not** an extra Home card, and do not write finance.
- M279's upgraded Firebase emulator uses JDK21 in all existing rules workflows. No silent disabling of audit gates.

## Release criteria and blockers
- All 3 M282 exact-SHA integration jobs must pass, as must every required M274–M281 and historical main regression and SQLCipher job on **the same M282 HEAD**; historic green PR runs are evidence of isolation, not integration.
- Actual 24-route SQLCipher production switch is not activated by this PR; OS-backed key and backup/receipt integrity under crash/restart still need signing-safe runtime certification.
- Physical Android release APK/AAB, actual merged manifest, no secret logs, 2-phone backup/restore, app/Widget concurrent double-entry prevention and performance/profile results are **not** established by CI.
- iOS simulator compilation does not constitute a signed IPA. Native iOS Runner and physical iPhone OS toolbar/notch/keyboard/lock tests are still required.
- Receipt OCR is **not yet implemented**; the UI explicitly states manual review. The monthly close is a preview until persisted to verified SQLCipher with undo and journal.
- Search notes/receipt binding may expose the user's own local notes on an unlocked screen; existing device lock/screenshot protection and account isolation still apply. No silent sharing.
- No merge, production Firebase deploy, Play signing, account deletion or financial cutover until physical-device evidence and a release review.

## Post-green steps
Review release cutover checklist, verify all gates against the exact merged candidate hash, fix any failures without bypass, then merge to main with guarded/approved process and build signed Android AAB/APK from the resulting main SHA. Verify actual installed file and Firebase OAuth signature. iOS requires separate packaging and launch sign-off.
