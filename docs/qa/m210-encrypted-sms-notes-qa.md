# M210 — Original bank SMS retained inside encrypted finance database

Status: **QA-only / production NO-GO**. User authorized work on SQLCipher
activation and wants every **financial** record in the encrypted database,
including complete bank-SMS notes, transaction records, category/budget data,
savings, recurring operations and verified receipt bytes. Non-financial
device preferences such as UI language and theme are a separate decision.

## Implemented first safety-critical path

- An explicitly confirmed SMS record is written to the SQLCipher typed
  `fresh_finance_entries.source_json`, the encrypted canonical financial
  snapshot and its SHA-256 deduplication projection in one SQL transaction.
- Before reporting successful save, the writer validates **byte-exact note
  equality** between the confirmed in-memory SMS, encrypted canonical ledger
  and typed SQL row, still within the transaction. A mismatch aborts the
  entire write, including the hash and any financial amounts. No bank text
  is printed in errors, logs or CI artifacts.
- Flutter tests cover Arabic/English multi-line note preservation across a
  cold vault reopen and a sabotaged SQL projection that must roll back the
  whole financial transaction.
- Android emulator integration exercises the actual Home/Widget **route
  binding** to a synthetic activated SQLCipher file. Both the Widget and
  Home confirm synthetic SMS records and the opposite side reads the full
  notes after a cold reopen. It also checks the typed SQL source JSON,
  wrong-key refusal, and absence of original text from legacy preferences.
- M202 runs Android emulator tests and emits redacted scope evidence.
  Synthetic approval flags and injected test key are **not** production
  evidence, OS-backed customer key attestation or a standalone widget
  engine process.

## Remaining before turning on encrypted storage for users

1. Route all **24** Home/Widget/transaction/category/goal/recurring/receipt/
   backup/restore/reset paths to the same active SQLCipher authority; validate
   their source-specific mutation guards and no legacy preference fallbacks.
2. Freeze live writers and migrate the complete legacy ledger plus **receipt
   file bytes** with an atomic encrypted snapshot, typed SQL parity, encrypted
   SHA hashes and crash-safe two-witness activation.
3. Independently prove OS-backed key recovery and failure after a lost or
   incorrect key, and a signed app build on **two physical** Android phones
   including post-restart Widget writes and portable encrypted backup restore.
4. Complete privacy/account deletion, receipt expiry/rollback, source
   attestation, release signing and explicit release approval before changing
   active source markers. Google Play is last.

The existing legacy privacy guard is unchanged. Until a verified SQLCipher
source is actually active, the current app saves bank transaction metadata
only and does **not** persist raw original SMS notes to SharedPreferences.
This PR does not turn on automatic SQLCipher activation, create or migrate
real user data, switch source markers, access banks or deploy Firebase/Play.
