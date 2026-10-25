# M220 — Accurate partial SMS save and safe manual recovery

**Status: user-visible defect fix candidate; SQLCipher production NO-GO.**

## Reproduction

The import success popup could report e.g. **56 saved, 13 not saved**
without distinguishing why 13 were skipped. It always closed the bank
paste sheet immediately after saving some transactions, discarding the
unrecognized messages from the accessible review flow. In addition, choosing
"Cancel" in a duplicate prompt aborted all new transactions rather than
offering a safe duplicate-skip path.

The warning that the original bank SMS body was not stored is **intentional
M207 privacy enforcement**, not a SQLCipher failure. Unencrypted bank account
numbers and full SMS text must NOT be persisted to SharedPreferences. Existing
SMS content lost from earlier import sessions cannot be recovered here.

## Live UI fix

- Parse rejections are tracked by source index and reason (amount, category,
  duplicate). Candidate records retain their original source index and unique
  persisted transaction ID.
- After the finance authority commits, compare those IDs with its reloaded
  authoritative ledger. Refuse mismatched saved counts or any SMS that is not
  accounted for, instead of showing a false successful summary.
- If any messages remain unsaved, show **partial save**, accurate count and
  reason breakdown, plus **Review unsaved** action. Return to the existing
  manual bank-SMS transaction editor with only those messages.
- The original full SMS stays only in the active import sheet's in-memory
  controllers. No SharedPreferences, Firebase, SQLCipher staging side channel,
  logging or clipboard export of the raw text is added.
- When a manually reviewed transaction is created, its default title contains
  only the parsed title, not the complete original SMS. The latter stays
  visible in the ephemeral review field.
- Handle zero saved without locking the sheet, and allow skipping duplicated
  texts while still importing genuinely new approved transactions.
- Bank message parsing is not silently broadened. Failed detection still
  requires user review before financial entries are committed.

## Necessary production activation and acceptance work

The encrypted runtime source, all 24 Home/Widget/finance write routes,
account principal and OS key enrollment, byte-preserving receipts,
wrong-key/crash interrupted recovery, second real Android device restore and
privacy/data deletion remain **NO-GO** until separately attested. Never flip
`automaticallyActivateSqlCipher` to true to eliminate the warning.

QA must validate bulk 69 = 56 saved + 13 rejected, overlapping and missing
source mappings, proposed ID duplicates, writer-skipped IDs, 100-message
limit, manual corrected re-save without duplicate financial entries, Android
UI dialog scrolling, RTL/LTR text and no plaintext SMS leakage. This stage
uses only synthetic SMS fixtures.

No new APK should be distributed as production-certified until exact-head
regression and same-SHA Android build verification pass.
