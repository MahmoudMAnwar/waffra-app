# M276 — Performance Baselines for Waffra (production quality, no fake FPS)

This work adds quantitative **measurements**, separate from user-facing
correctness regressions. All benchmark records are synthetic.

## What now runs automatically for a PR

| Scenario | Input | Collected evidence |
|---|---|---|
| Bank SMS splitting, parsing, deduplication | 1, 20, 100 messages | P50/P95/min/max host microseconds |
| SMS pre-save preview | 1, 20, 100 messages | P50/P95/min/max host microseconds |
| Full ledger serialization + hydration | 1,000 synthetic transactions | P50/P95/min/max host microseconds |
| Finance category aggregations | 2,000 synthetic entries | P50/P95/min/max host microseconds |

21 measured samples (after 4 warmups) per scenario; 8 scenarios total.
Every run asserts correct parse, unique fingerprints, complete ledger
round-trip, and correct category totals. Evidence includes the GitHub SHA and
is saved as `build/performance/m276_finance_microbench.json`.

The CI runner is **not a phone**. Host latency varies with VM hardware and
parallel traffic. CI therefore checks scenario correctness, a complete receipt
and percentile ordering, but does *not* fail on arbitrary hardcoded time limits
or represent this as Android production performance.

## Android renderer profiling — opt-in and not a release signoff

GitHub Actions workflow `M276 Finance Performance Baseline and Android Profile`
offers a `workflow_dispatch` Android job. It uses Flutter `--profile` in a
disposable Pixel 6 emulator with the dependency desugaring required by Waffra.
Flutter engine `IntegrationTestWidgetsFlutterBinding.watchPerformance`
collects real FrameTiming data while tapping 5 footer destinations repeatedly
and scrolling a synthetic 1,000-transaction list. Summaries are saved to
`build/performance/m276_android_profile_frames.json`.

This benchmarks a representative interface, **not** an actual logged-in
database commit. A physical-device gate is still needed for exact end-to-end
transaction confirmation and SQLCipher storage.

## Physical-device next measurements (release freeze)

Capture cold/warm start, 1/20/100 SMS confirm, one add/edit/delete/undo,
reports PDF export 100/1,000 rows, SQLCipher 24 route save/reload,
Widget balance refresh and cloud restore on two real Android phones.
Record P50/P95 response latency, UI/raster janky frame counts, peak RSS memory,
and correctness after kill/restart. Compare like-for-like devices,
firmware/build SHA, screen refresh rate and thermal/battery status.

Use **16.7 ms** as the per-frame budget on a 60 Hz display; compare actual
UI and raster frame times against the device refresh budget, not host timings.
Use a measured baseline from the last signed `main` APK before creating
numeric acceptance targets. Never fake profile output or mark SQLCipher
production-ready based on a desktop benchmark.

## User-visible regression rule

The existing release workflows still gate on functional tests. Do not merge
or release if parse, balances, receipts, duplicate prevention or real finance
source authority regress. Performance work must never bypass durability or
show a successful save before a durable source acknowledgment.
