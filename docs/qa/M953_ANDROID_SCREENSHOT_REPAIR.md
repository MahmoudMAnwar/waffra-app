# M953 — Android screenshots: transaction edit and review UX audit (Issue #659)

Eight owner-supplied Android screenshots, Nov 15 2026, latest installed main. The images establish visible failures; no physical handset or actual private archive accessed by CI.

## User-visible changes proposed and source references

| ID | Report | Changed code | Acceptance evidence |
|---|---|---|---|
| M953-01 | Existing income/expense date edit to older month/year reports "تعذر حفظ المعاملة" | `waffra_home_entry_sheet.part.dart` | Verified source-aware **one-ID** snapshot patch, never rewrite other historical sparse SMS/V24 data, no duplicate debit, exact SQL + Home readback; `test/storage/m953_verified_historical_edit_regression_test.dart` |
| M953-02 | Existing edit matrix amount/description/notes/category/budget plus account | entry sheet + canonical encrypted projection | New encrypted edit test for amount, notes, category, 2024 leap date, and no unapproved budget association. **Moving an already-linked entry between bank accounts still needs separate atomic account-relink writer, NOT yet implemented or claimed safe** |
| M953-03 | Chronological Home cards need visible 1, 2, ... | dashboard + compact cards | Number from current visible filtered unified chronological projection, not a persistent database ID; includes income, expense, transfer, savings and due rows |
| M953-04 | Notifications latest below instead of above | Notifications page and owner SMS queue adapter | Order by native receivedAt descending, stable tie on original queue position; keep sender filters and selections |
| M953-05 | SMS buttons truncated; exclusion missing | bank SMS confirmation | Two readable primary actions + full-width Exclude for verified non-sensitive notice, separate Exclude for unknown non-sensitive notice; transfer and sensitive OTP retain their explicit safety decisions |
| M953-06 | Scroll bar overlays text and controls | Due editor and Backup/Restore modal | Move dialog scroll content away from RTL scroll indicator using directional end padding; Android screenshot approval still pending |
| M953-07 | Redundant total Goals/Dues beside "All" filter | goals/recurring page | Remove standalone count tiles; preserve counts in All and each filter option |
| M953-08 | User-visible "المتكررة" should be "الاستحقاقات" | footer, Goals/Due, recurring editor/trash, category workflows, Tools, copy/i18n | Only visible labels change. No persistence-key, storage table, enum, Home index, restore schema or recurrence-rule renames |

## Financial edit coverage / caveats

- Editing existing **manual income** and **expense** must preserve ID, category, exact amount in halalas, original source, account link, SMS fingerprint, receipts and every unrelated row.
- Dates: yesterday, old month, old year, leap day, year boundary, old imported SMS. No future/invalid calendar acceptance beyond existing validation.
- Edit failure must first reload the verified source instead of misleadingly asserting that prior data remained unchanged if a write might have committed before a response failure.
- Real **transfer source/destination change**, **saved Goal money**, **settled Due debit**, and **relinking already-linked bank account** are account-balance mutations and **not covered by this first metadata-edit patch**. These require separate authenticated, atomic transfer/relink/goal-due writers plus dedicated tests. Do not bypass current safety restrictions.
- Budget reassignment must preserve historical amount/source and only create an allocation following existing explicit confirmed budget route. A metadata edit alone must not invent a budget allocation.
- Dynamic order/row-number calculations are presentation-only; do not sort or rewrite encrypted ledger itself.

## Test & release gates

- Run all existing Flutter tests, M946, finance/security host suites plus the new Android screenshot regression tests.
- M385 exact per-file/section change scope and M550 full registered-source behavior review required; legacy tests updated only when the owner approved a different visual contract.
- Exact HEAD **passed/failed/skipped** counts must be collected from CI, not estimated from authored test files. Android text/keyboard overflow and restore with real archive cannot be marked passing based on source-only tests.
- Keep as Draft until CI passes and owner reviews. No change to + FAB or Snackbar geometry, no restoration of deleted cloud AI/receipt OCR.
