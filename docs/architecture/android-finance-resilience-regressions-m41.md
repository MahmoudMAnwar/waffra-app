# M41 — Android finance resilience regressions

The Android emulator workflow now runs a second finance-specific end-to-end suite as its **last storage test**. All input is synthetic and saved to app-owned temporary SQLCipher databases; current Waffra users and existing SharedPreferences data are not accessed.

## Tested on Android emulator

1. Confirm a batch of 100 normalized SMS transactions (50 income, 50 expenses); detect replayed hashes and return **0 newly saved**.
2. Start 20 overlapping app/widget-style finance append calls through the same experimental lock and verify all unique transaction IDs, exactly 120 records, exactly 110 unique SMS hashes and finance generation 21.
3. Close/reopen SQLCipher; confirm persistent 120-entry snapshot and verify no plaintext SQLite header.
4. Treat existing empty legacy transaction array and half-created activation pointer as **not eligible for fresh activation**.
5. Deliberately corrupt the encrypted snapshot's record checksum; fail closed on both reading and committing rather than silently replacing it.
6. Attach two encrypted image BLOBs to one transaction, reject unsafe replacement, close/reopen and verify image bytes.
7. Attempt reading via the wrong SQLCipher key, confirm rejection and then successfully reopen with the original key.

## Release gates remaining even after tests pass

These tests verify the *experimental storage services*, not live screens. Real app routes still store finance data in SharedPreferences; the Android widget is still an independent writer. No production source-activation witnesses have been written, and no migration or rollback on real user data has been performed.

The full device release gate additionally requires: production writer/source routing for all app paths, app UI transactions/categories/goals/challenges, widget/CSV/SMS/PDF/analytics parity, image UI backed by encrypted BLOBs, secure key recovery, legacy backup migration, crash recovery, test APK installation and end-user validation. Firebase comes last.
