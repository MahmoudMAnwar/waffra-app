# M630: login finance contention and repeated verification

Base: `10d5682a`, main after PR #541. This supersedes the old local M609 experiment; no old UI/source changes are reapplied.

## Reproduction and root causes

The real SQLCipher regression starts another SQLite writer on the installation mutex, then releases it from a 150 ms event-loop timer. On unchanged main, lazy Drift opening/schema setup fails with SQLite BUSY before acquisition completes. An incomplete initialization can prevent the authenticated Home handoff. A worker-owned lock database with migrations disabled and bounded BUSY/LOCKED retries resolves the observed failure. It retains BEGIN IMMEDIATE through installation and closes on every exit.

Main already runs SQLCipher and snapshot decoding off the UI isolate. Each repeated snapshot read still launches a worker and repeats checksum, JSON/canonical encoding and full finance preflight. The read view then repeats that preflight. Cache only this CPU result for exact row bytes/digest/revision on the same store; mark only privately verified immutable states. Every access still reads SQL and checks readiness. New/changed/corrupted rows, rollbacks, and new connections cannot reuse a mismatched cached result. Weak associations do not retain closed connections globally. Publicly constructed snapshots receive the original validation.

## Same-host synthetic evidence

2,000 entries; cold encrypted reopen and 12 reads, Flutter 3.47.9 / Linux. Before and after use the same test and latest main base.

| Measurement | Main #541 | Patch |
|---|---:|---:|
| Whole workload | 1954 ms | 1293 ms |
| Repeated reads (includes cold reopen) | 1079 ms | 421 ms |
| Worst event-loop timer gap | 45 ms | 67 ms |
| Contended install lock | SQLite BUSY failure | Pass |

These runs show reduced repeated-read latency and the contention fix, **not improved frame pacing on this host**. The earlier ~2 second main-isolate stall was on obsolete PR #510; do not present that comparison as current-main evidence. Timer thresholds detect gross stalls, not 60/120 Hz frame budgets.

## Validation and outstanding acceptance

Regression coverage: real encrypted cold reopen, timer progress, installation contention, altered SQL with unchanged revision, digest corruption, immutable cached lists, rolled-back commits, new committed generations, and forged public snapshots. Full storage suite and changed-source analysis are run before publication. Source-only auth/Home tests remain useful guards, not physical biometric tests.

Required Android profile acceptance: fresh install/login/permission/biometric/Home, logout then login with preserved finances, and retry after interruption. Capture existing WAFFRA_HOME_LOAD_STEP stages and frame timings on the owner's device. No emulator/device is available in this environment. Do not merge on failed exact-head CI or claim all remaining device freezes solved.
