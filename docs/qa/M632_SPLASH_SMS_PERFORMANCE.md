# M632 P0 — splash, first SMS account and post-Home jank
Issue: https://github.com/MahmoudMAnwar/waffra-app/issues/549
Status: Recorded / implementation pending. No real-device acceptance yet.

Owner acceptance:
- Launch splash's Waffra and وفرة text must finish actual 1650ms animation without re-adding post-login delay. Startup I/O runs concurrently.
- First SMS review with no account: distinct Add Account action, inline create from sender/verified bank, assign created account to current review, enable Yes only once the exact financial fields have been validated, do not pop the review or create an extra account confirmation picker.
- Post-Home automatic SMS processing must not starve UI frames: no four-page immediate native history scan, bounded paced batches, no repeat full pending-read for every notification, cancellable on logout; on-demand rescan still processes remaining native cursor pages and no messages silently dropped.
- Profile-mode per-stage no-sensitive timings; real Android jank/first-frame captures must validate. Existing SQLCipher, biometric, owner, source SMS hash and category gates remain fail closed.

Official references: Flutter docs https://docs.flutter.dev/perf/isolates , https://docs.flutter.dev/tools/devtools/performance , https://docs.flutter.dev/perf/best-practices
