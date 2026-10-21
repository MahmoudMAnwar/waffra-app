# Storage M11 — manual end-to-end key recovery (draft / inactive)

**Purpose:** A different phone cannot decrypt end-to-end encrypted Waffra data
merely by signing in with Google. The user needs control over a unique vault
key, and a recovery route that does not send raw keys to Firebase.

## Proof of concept

`WaffraVaultKeyRecovery` wraps a 32-byte vault encryption key using AES-256-GCM
under an independently generated 256-bit random recovery code. The code is a
**43-character base64url secret** — not a human-chosen password or OTP. This
avoids the low entropy of user passwords, but users must safely store the
entire code outside their account. Vault identity, key version and recovery
revision are authenticated associated data: a wrapped key from one vault
cannot be replayed for a different vault.

The package exposes a one-time `recoveryCode` for a future protected UI,
plus `envelope.toPublicDocument()` containing only encrypted bytes and
metadata. No code or decrypted key belongs in logs, analytics, Firestore,
screenshots, SharedPreferences, source code or crash reports.

Tests cover:
- Recovery of a genuine encrypted transaction with a key restored on another
  client, without storing private ledger content in the recovery envelope.
- Wrong secret, wrong vault, invalid code and AES-GCM tampering refusal.
- Recovery-code rotation and strict allowlisted cloud-envelope serialization.

## Required product decisions before release

1. **Explicit user opt-in** to cloud backup and recovery, independent of
   Google sign-in. Explain precisely what cloud sync includes/excludes.
2. A secure, accessible code display with copy/confirmation and a recovery
   guide. Warn that loss of both original device key and recovery code can
   make data permanently inaccessible; never promise support can decrypt it.
3. Persist the vault key on the device using verified Android Keystore / iOS
   Keychain wrapping, and confirm backup/restore after reinstall and phone
   transfer. The code itself must NOT be automatically backed up by the app.
4. A new phone must prove the user controls the right Firebase account AND
   the recovery code; user may not silently claim the guest/other vault.
5. Recovery envelope replacement/revocation MUST be atomic with a monotonic
   server revision. Changing the code on one client doesn't invalidate a
   previously stored old envelope until authoritative replacement succeeds.
   Purge historical versions where feasible, handle offline devices and
   clearly communicate device revocation semantics.
6. Add brute-force/rate-limit policy at the account/recovery API level where
   relevant, account deletion/revocation, lost-device handling, privacy
   compliance and secure recovery UI tests.
7. Owner must configure and validate staging Firebase Firestore rules and
   recovery-doc access controls before any upload. The current
   `firestore.rules` candidate does NOT allow this new envelope schema, so
   it cannot be deployed without separate rules and emulator tests.

## Status

No backend integration, cloud sync, UI flow or live account binding is enabled.
This is an offline cryptographic proof of concept. Depends on M10 and the
existing M7 cloud cipher; keep the PR in Draft until all release gates pass.
