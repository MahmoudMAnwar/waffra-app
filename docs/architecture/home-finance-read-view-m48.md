# M48 — HomeScreen finance reads behind one typed source view

Waffra currently uses SharedPreferences as the finance system of record. The new encrypted finance snapshot and app/widget patch services are not yet activated.

This stage **refactors the real HomeScreen.load() path** to use one typed finance-source view for all 14 recognized finance keys (entries, categories, goals, recurring bills, challenges, 30-day recycle bins, postponed recurring, learned merchants, SMS hashes, monthly budgets and reminder settings).

- Legacy source view reads existing SharedPreferences unchanged; all account, language, screenshot, onboarding, tutorial, backup metadata and other nonfinance settings still come directly from preferences.
- An encrypted view implementation consumes the verified SQLCipher finance snapshot without *ever* falling back to an old legacy entry or goal if the encrypted key is absent.
- Absent keys remain distinct from saved empty lists; invalid value types are rejected.
- Tests check old finance parity, precise money and SMS hash types, no cross-source fallback, missing-vs-empty fields and rejection of sensitive nonfinance keys.

**Important status:** HomeScreen.load() is currently wired through `fromLegacy` only; we have NOT switched it to encrypted finance. Its category-install metadata and active finance writes still use SharedPreferences and cannot be redirected until all app/widget writers are routed through the M46 single-source patch layer, migration checkpoints, receipts and recovery.

The goal is to make that eventual verified cutover a single controlled source-selection change rather than altering every screen separately. Firebase remains outside this milestone.
