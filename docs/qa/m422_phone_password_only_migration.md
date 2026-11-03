# M422 — Saudi mobile number + password only (draft, security migration required)

**Requested behavior:** Remove Google Sign-In, Apple Sign-In and unauthenticated guest from new entry surfaces. Use Saudi `05XXXXXXXX` mobile plus password for registration/sign-in. Registration step 1 is phone/password/confirmation; step 2 asks only name and gender (male or female). **No email or date of birth input.** Android and iOS use the same future credentials.

## Implemented now in this draft PR
- New registration entry no longer offers Google/Apple/guest.
- Phone-only wizard: validates 10-digit Saudi `05` number, password and matching confirmation, then name/gender.
- Local guest/demo profile with no phone is directed to sign-up on next launch. The previous financial journal is not reset or deleted.
- Existing phone/password profiles still use the previous on-device legacy password verification.
- An existing Google/Apple profile is not silently overwritten or deleted. A legacy-account access card remains temporarily for **one-time recovery and migration**.
- No changes to balances, SMS, budgets, goals, backup or financial encryption.

## Release blockers (do NOT ship the UI as a cloud-verified login)

The existing local login stores a salted SHA-256 password hash in SharedPreferences; that is **not** a server-authenticated identity and is not sufficient to secure Cloudflare Worker, account recovery, financial sync, or access on multiple phones. This draft does **not** claim complete phone+password authentication, and `WaffraGoogleAuth` must remain until all existing users are migrated.

Before merging:
1. Select and implement a verified server-side phone+password identity provider. Firebase's phone provider is SMS OTP, not a native phone/password provider. A custom identity backend may produce Firebase Custom Tokens after verifying identity (and use strong Argon2id password storage and per-user rate limiting). **Do not invent/synthesize emails** to use email/password as a shortcut.
2. Prove control of the Saudi number during registration and recovery with a reputable OTP provider; check actual per-message costs, quotas and abuse protection. No shared static OTP, no unauthenticated reset endpoint.
3. Implement password reset and number change via verified OTP, plus failed-login throttling, enumeration-safe responses, session expiration, revoke, device/session management and mobile+password sign-in on both Android and iOS.
4. Migrate existing Google accounts **in place without changing their Firebase UID or finance owner data**: after signing into old account, verify and link the new number/password identity, compare ledger and backup, commit a migration marker, and only then remove prior provider. For an old guest/local profile, preserve all current manual entries and goals while enforcing first-time signup.
5. After proven migration, permanently remove legacy provider code, Google/Apple auth dependencies and buttons, and retire the legacy salted SHA-256 verifier. The old-provider bridge must be inaccessible to new users.
6. Connect the authenticated phone identity to PR #352's Cloudflare service, verifying tokens server-side and per-user cloud consent. A local-only mobile profile must never count as cloud authentication.
7. Signed device, Android/iOS, migration/backups, restore, duplicate phone, account switching, logout/locked-app and clean-install tests; privacy/data retention and Play/App Store review.

## Planned test acceptance
- New users: registration requires phone, password, confirmation then name/gender; **no email, Apple, Google, guest**.
- Validation: empty fields, 05 prefix, exactly 10 digits, passwords match; errors under fields.
- Existing phone profile: correct/incorrect password, sign-out and re-login, offline behavior.
- Existing Google user: previous finance data remains; never overwritten by a new phone registration; migration controlled and reversible before old login is removed.
- Existing guest: cannot access homepage without creating an account, but old locally saved entries remain until reconciliation.
- No sensitive details in analytics/logs; no Cloudflare OpenRouter quota access without externally verified identity.
- Birth date removed from the signup UI; no mandatory email.

This changes authentication for financial data and is deliberately **separate from PR #352**, so SMS finance work cannot accidentally override login changes.


## M426 owner revision (2026-11-03)

The owner explicitly rejected SMS OTP, Firebase custom token login and paid phone verification. This PR now uses only a local phone login name plus password, in OS-backed secure storage with salted PBKDF2-HMAC-SHA256 (600k iterations). Old salted SHA-256 verifier is consulted only once to upgrade a successful legacy login; the old wallet is not wiped. Local phone is NOT authenticated remote identity; cannot safely authorize Cloudflare, cannot sync across handsets, and losing device storage requires encrypted backup restoration. M425 server-side phone/OTP prototypes are deleted, not deployed. First sign-in requires mandatory OS biometric and each return prompts again. Existing Google users retain a one-time legacy sign-in route; actual verified migration and financial content preservation must be tested on real phones before release. Do not merge based solely on this description.


## M428 legacy local finance preservation

A legacy Google/Apple account already opened on its original phone (behind the mandatory biometric gate) now has an explicit migration option in My Account. This sets a new local Saudi phone name and device-protected password but does **not** change the existing Firebase UID, delete Google account records, reset finance source, move SQLCipher keys or touch any backups. Existing Google login remains available as the recovery bridge for accounts not yet migrated. Never describe this as cloud identity migration or multi-phone synchronization. Test real balances, budgets, attachments and encrypted backup/restore on both physical devices before main merge.
