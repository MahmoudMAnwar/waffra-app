# M219 — Android Keystore proof of existing finance-account owner

**Candidate-only. SQLCipher production NO-GO. This is not key enrollment.**

M218 requires a platform HMAC signer rather than receiving raw key bytes
in Dart. M219 adds a concrete `waffra/account_owner` Flutter MethodChannel
implemented in the **actual** `native/WaffraMainActivity.kt` template used
when CI assembles the signed Android Flutter app.

## Contract

- Dart passes only an approved canonical domain-separated UTF-8 JSON
  array `["waffra-profile-owner-v1", vaultId, sourceSha256, firebaseUid]`,
  encoded as a `Uint8List`. Both Dart and Android reject other shapes,
  malformed SHA-256 hashes, missing identifiers and oversized challenges.
- Native Android verifies the challenge Firebase UID against
  `FirebaseAuth.getInstance().currentUser.uid` and rejects anonymous
  sessions. It is *not* enough to trust a Dart-provided editable UID.
- Native opens only **existing** `AndroidKeyStore` alias
  `waffra_profile_owner_hmac_v1`, obtains its `SecretKey` handle and calls
  `Mac.getInstance("HmacSHA256")`. The key is never exported to Dart, copied
  into SQLCipher or derived from a short PIN.
- A missing/unavailable key, wrong Firebase user, bad challenge or native
  plugin errors fail closed. Responses contain only 64 lowercase hex
  characters. Exceptions deliberately suppress identity and keystore data.
- The code does not create a key, enroll a principal, mutate account data,
  access SMS, issue Firebase tokens, activate cutover or alter the source.

## Integration requirements still blocking release

The OS-backed key must be enrolled by a separately audited and deliberately
user-authorized service, with a durable account/vault owner binding and
device-loss/recovery policy. The native current-user check is **not** a fresh
Firebase ID-token server validation. Account-switch, token expiry, phone
sign-in, Google/Apple sign-out, biometric gates, backup transfer and deletion
must be attested independently. An AndroidKeyStore alias alone is not proof
of hardware-backed protection: test the actual handsets' security level.

The M219 signer remains unreferenced from live account screen flows.
M218 account writes are also candidate-only pending account enrollment.
Live finance routes (24), receipt byte parity, interruption recovery, backup
restore to two different physical Android phones and approved release evidence
still have no production GO sign-off. No production APK, cloud migration or
Google Play rollout is authorized.

Synthetic Dart MethodChannel tests cover allowed challenge, missing service,
OS key refusal, invalid signatures, JSON and domain mismatches, missing UID,
bounds and no secret passed through Flutter.
