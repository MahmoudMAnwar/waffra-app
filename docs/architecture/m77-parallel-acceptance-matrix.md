# M77 — Independent parallel acceptance tests

Branch basis: `feature/production-all-writers-routing-m75`, the last
fully green source before M76's new receipt transaction writer. **M77 is
independent of M76.** Keep the two draft branches unmerged until their
separate CI gates complete; do not confuse cross-branch green checks with
a validated combination.

## Independent now

- Firestore **local emulator only**: authenticated owner boundaries, no
  plaintext/private fields, initial record revision exactly 1, competing
  device revisions, encrypted tombstones, and stopped syncing without
  deleting previously committed ciphertext.
- Pure Flutter/local SQLCipher: two independent offline encrypted device
  queues, replay after a cold restart, no incorrect acknowledgement on a
  conflict, AES-GCM wrong recovery key/metadata refusal, authenticated
  re-encryption on an observed predecessor.
- Portable encrypted backup **disposable vault only**: failed password
  doesn't install an empty vault, subsequent correct restore preserves exact
  receipts/SMS hashes, different backup may not overwrite finance, cold
  reopening still reads every attachment.

All tests use fake records, fake keys and localhost/durable temporary files;
none connects to the user's live `waffra-app` Firebase project or a phone.
Firestore rules in this draft branch are candidates, **not deployed**.

## Dependent; cannot claim completion yet

- M76 receipt write and rollback on an activated source (wait for M76).
- HomeScreen, widget and every financial screen selecting SQLCipher together
  under durable two-witness activation without any legacy fallback.
- Production recovery key enrollment, secure second-device key transfer,
  encrypted ID discovery, real conflict resolution and intentional opt-in.
- Full Android end-to-end production source cutover acceptance, mixed-version
  update, loss-of-key, rollback/wipe, and ARM64 Release Candidate build.

On M76 success, bring these independent tests into the eventual combined
release-validation branch and run the **entire** test matrix on the same SHA.
