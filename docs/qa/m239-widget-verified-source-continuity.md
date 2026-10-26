# M239 — Standalone Widget read safety and source continuity

The Android quick-capture Widget is a separate Flutter engine and does not
inherit a Home widget's previously validated finance values. This candidate
checks the full snapshot with `WaffraFinanceReadView.requireIntegrity()`
when loading `widgetRead`, then validates a *fresh* authority snapshot
again before `widgetSmsConfirmedSave`. If source type changed since the
Widget opened, the save is refused; the user must reload and reanalyze to
avoid committing against an old known-hash/category baseline.

A `verifiedEncrypted` source must contain a real authenticated finance ledger
and its category catalog. Missing encrypted keys or no matching income/expense
categories never fall back to legacy preferences, first-run defaults or a
fabricated “Other” category. The usual **guardedLegacy** first-install and
offline SMS UI behavior is intentionally unchanged.

Safety regression: corrupted guarded legacy finance shows a protective error
and does not permit confirmed saving. Additional source/caller ordering checks
prove validation precedes the native-locked SMS writer. Production route #4
(widgetRead) and #7 (widgetSmsConfirmedSave) still require independently
certified hardware/dual-engine SQLCipher roundtrips before release.
No SQLCipher cutover, main merge, end-user APK or real-bank access.
