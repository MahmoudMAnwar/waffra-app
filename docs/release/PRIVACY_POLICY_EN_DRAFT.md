# Waffra — Privacy Policy Draft (Pre-release review required)

**Status: Draft only — not approved, published or legally reviewed.**
Last reviewed: 22 October 2026.

## Who operates this app?
Waffra (وفرة) is a personal finance-organizing app intended for users in Saudi Arabia. Before launch, replace all placeholders with the publisher's real legal identity, support email and accessible public privacy-policy URL.

## Information processed
Waffra handles transactions entered by users, including bank notification text users **voluntarily copy and paste**, amounts, descriptions, dates and categories; budgets, goals, recurring transactions, receipts selected for attachment, and generated reports. Depending on the authentication method, account information may include profile name, email, account identifier, avatar and supplied details. Settings may include language, appearance and security preferences.

**Waffra does not connect to users' bank accounts or request online banking passwords or credentials.** Its Messages-app shortcut is not blanket permission to read messages.

## Why and how information is used
Data is used to organize income and expenses, provide reports and goals, and support authentication. Some operations are local to the device. Firebase Authentication may process login information. Encrypted Firebase synchronization is still being integrated and **must not be presented as active production functionality until actually activated and verified**.

The release team must verify all active local storage paths, Firebase authentication/Firestore processing, third-party service processors, encryption properties, key management and data retention against the **actual release build**. This draft does not promise complete server-side encryption or remotely deleting stored data before those behaviors exist.

## Permissions and diagnostics
Users may choose to attach receipt images/files, enable reminder notifications and unlock with biometrics. The app should request only necessary permissions. Crashlytics is **not currently present in the app's listed dependencies**. If crash reporting is enabled later, disclosures and informed choice must match implementation, and raw bank notifications, balances, receipt content, tokens, passwords and encryption keys must never be sent as diagnostic attributes.

## Account and data deletion
**The complete in-app and web-accessible account deletion process is not yet certified.** Google Play launch is blocked until both paths are live and tested, including deletion of account-linked hosted records, documented data retention exceptions, and user guidance for local data/backups. This document is not itself a deletion mechanism.

Public account deletion URL: **[REQUIRED: replace with functioning unauthenticated page]**.

## Security and retention
Before release, independently test legacy-to-SQLCipher migration, signed-out access, E2EE recovery, receipt storage, backup and rollback. Document actual retention periods and providers once confirmed; do not claim unverified guarantees.

## Contact
Publisher/legal entity: **[REQUIRED]**
Support/privacy email: **[REQUIRED]**
Public privacy-policy URL: **[REQUIRED]**

---

**Review gate:** Update and legally review AR and EN policies and Google Play Data Safety declarations against the final distributed AAB, SDK collection behaviors, Firebase settings and real delete-account implementation, not feature proposals.
