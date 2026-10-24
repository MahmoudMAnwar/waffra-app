# M189 — physical Android acceptance capture (hardware only, NO-GO)

**Google Play intentionally remains the LAST phase.** The project still has
no verified release activation for SQLCipher or evidence that 24/24 live routes
work on two actual handsets. CI Android emulators are not physical phones.

This module adds a non-invasive way for QA to begin collecting the *first*
hardware artifact, without changing the app, opening databases, storing
transaction data, reading system keys, or producing pretend production
certificates.

## On a workstation with TWO connected Android phones

1. Build/install the same **reviewed** Waffra APK on two distinct physical
   handsets; use synthetic finance only, never a real user's finances.
2. Enable USB debugging and explicitly authorize that workstation on both.
3. Run:
   `python3 scripts/qa/m189_physical_device_source_probe.py --capture --output /private/evidence/m189-devices.json`
4. The tool requires exactly two different online ADB devices, rejects
   emulator/virtual Android, rejects missing Waffra APK and OS API below 30.
   It stores **salted one-run hashes** of ADB serial and OS fingerprints,
   platform version and package-presence booleans only. The private
   resulting JSON has 0600 file permissions. There are no SMS, money, raw
   serials, receipt bytes, screen screenshots, database paths or OS keys.
5. Seeing two phones detected **does NOT pass release**. Mandatory subsequent
   QA evidence: exactly 24 source-route tests, Widget cold startup and
   balance refresh, 100 SMS pasted including duplicates, verified encrypted
   receipts across restart/delete/undo, budget/category/goal/recurring restore,
   source-key cold start, forced process crashes and rollback, reset,
   backup/export and **source-backed restore to a second phone**, parity of
   every invoice and amount, and an actual signed APK launch/login test.
   Those need the application's own future trusted instrumentation and
   independent human inspection. This tool cannot fabricate them.

Run its source-only safety review anywhere (including CI):

`python3 scripts/qa/m189_physical_device_source_probe.py --check-contract`

`python3 -m unittest discover -s test/qa -p 'm189_physical_device_source_probe_test.py'`

The CLI checks the **exact** 24 defined route names and fails if source code
adds/renames one. Its report always says
`PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO`, with zero runtime route
witnesses, no hardware key proof, no verified backup restore, no permission to
cut over, and no Play submission approval. For an actual production
certificate, independently verify app-signed runtime receipts and source
handoff; never edit JSON booleans to pretend the tests ran.

## Gating

No activation markers, Firebase, Play settings, production SQLCipher
sessions, real customer data, clipboard, Android permissions or User Account
Deletion flows were changed by M189.

**State: hardware witness harness only; all production finance gates remain NO-GO.**
