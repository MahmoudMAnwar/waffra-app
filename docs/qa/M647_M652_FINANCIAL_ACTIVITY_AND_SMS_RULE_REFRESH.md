# M647–M652 — Waffra Financial Activity, Transfer Detail & Incremental SMS Rule Refresh
Date: 2026-11-11
Status: requirements recorded / code not yet implemented
Branch: `feature/m647-m652-financial-activity-ledger-sms-reclassify`
Issues: #569 #570 #571 #572 #573 #574

## Owner requested use cases
1. Transfer details screenshot is confusing/oversized. Replace current ambiguous single string with an intentional sender **FROM / من** account card, visual directional arrow, receiver **TO / إلى** account card, amount, date, source and target account identities, optional fee, note and settlement status. No fabricated bank names; support RTL, mixed Latin names and dynamic sizing.
2. In the Home «عملياتك المالية» timeline, include a BLUE transfer card. When filter = "كل الحسابات", one card per verified transfer even though two ledger legs exist; when filter = one money account, show that account's signed movement. Transfer principal is neither income nor expense. Fees are independently recorded expense where actually posted. Detail tap opens small scrollable transfer sheet.
3. Include GOLD «حركة ادخار» cards for actual saved contributions and withdrawals, with goal name, amount, verified source child account, wallet destination, date, explanation and status. Creating an empty goal or merely linking an account does not create fictional income or banking movement. A goal wallet is a separate asset from a bank balance; single movement debits bank once and credits wallet once.
4. Include VIOLET «استحقاق مدفوع» cards for recurring and goal-linked due occurrences *only after actual confirmed payment*. If due but not paid, show an unpaid upcoming/due reminder only, **never** a debit. Keep due date distinct from payment date; repeated/retried payment may not debit twice. Paid recurring expense can be included in expense totals once, without separate duplicate ledger item just because presentation label is "due".
5. SMS rules: when an income/expense/transfer/exclusion user decision is durably confirmed, persist safe local reusable learning; increment rule generation/version. Notification/review refresh reclassifies only pending SMS with stale rule versions, in bounded asynchronous batches, and immediately updates visible prediction, review count/filter and prefills. Don't import every SMS on normal commit or block Home. Ambiguous/contradictory matches remain "تحتاج مراجعة"; no auto-posting, no automatic account guess, no sender-level exclusion without user approval; OTP excluded; prevent changing accepted/rejected historical records; honor excluded retention and SQLCipher owner/session boundaries.
6. Consistent color + semantics in Home timeline, detail sheet, filters and exported PDF: income emerald/green, expense coral/red, transfer blue, savings gold/amber, paid recurring due violet. Labels/icons remain readable without reliance on color only. Ensure RTL and Arabic font rendering and no PDF financial duplicates.

## Proposed presentation mapping (design tokens; UI team may tune contrast with existing theme)
| activity_kind | Arabic badge | Color family | Underlying finance effect |
|---|---|---|---|
| income | دخل | Emerald / green | inflow in revenue |
| expense | مصروف | Coral / red | outflow in expenses |
| own_transfer | تحويل بين حساباتي | Blue | bank-to-bank internal asset move, principal excluded from revenue/expense |
| goal_funding / goal_withdrawal | ادخار / سحب من الادخار | Gold / amber | bank ↔ independent goal wallet, not revenue/expense |
| settled_due | استحقاق مدفوع | Violet | one confirmed recurring settlement; optional expense summary once |

## Design data model
- Introduce/derive stable activity ID and typed activity kind, source posting ID/occurrence ID, owner/vault ID, effective event timestamp, verified source account ID, verified destination account or independent savings wallet ID, one canonical amount in integer halalas, fee separately, goal/recurring occurrence ID, notes and settlement status.
- Projection reads existing trusted SQLCipher journal rather than creating new financial writes to populate UI. No double-posting when one source event has two legs or appears under expense and due facets.
- Historical records lacking evidence must visibly say "حساب غير محدد" instead of inferring source by SMS sender name.
- Keep old data, migration paths, account filter, rollback and encrypted backup intact.

## Example walkthroughs
- Transfer: «من: مصرف الراجحي / تويش» → 100.00 SAR → «إلى: AlinmaPay»; one blue transaction in all-accounts list. Source-filter = −100, destination-filter = +100, portfolio change = 0 unless distinct confirmed fee.
- Goal: fund «صندوق الطوارئ» 5,000 SAR from verified Al Rajhi money account. One gold card with source and wallet, bank −5,000, goal wallet +5,000; no expense or income.
- Due: recurring «فاتورة الإنترنت» 250 SAR with due date 11/11. Before settlement: reminder only. After user-approved payment: one violet paid-due card, linked account −250, expense count increments once where appropriate.
- SMS rule: user confirms «شحن الجوال» as expense and its matching category; pending same-pattern messages become an expense suggestion on next notification refresh. Ambiguous matching stays needs-review; no ledger debit until reviewed/approved.

## Implementation sequence / checkpoints
A. Document numbered GitHub Issues and this spec, then link one Draft PR. No status marked Done before exact SHA QA and device acceptance.
B. Inspect actual transfer view, Home ledger list, account/goal/recurring source of truth and PDF export. Implement typed read-only unified activity projection with canonical account filters and validation.
C. Build visually clear transfer details and five distinct timeline cards; ensure no duplicate finance operations. Add native/widget tests.
D. Integrate source-event-driven goal contribution/withdrawal and settled recurring due cards, not artificial copies.
E. Hook local rule-generation invalidation and asynchronous bounded reclassification of existing pending SMS following durable user decisions; update notification/review state once per committed batch and preserve session cancellation.
F. Use shared presentation style mapping in Home and PDF, including labels/icons/RTL, plus tests and release notes after verified source changes.
G. Run targeted Flutter tests, SQLCipher/account transaction invariants, exact-head CI + PDF/Android physical device smoke. Merge only after green checks and explicit QA.

## QA / non-regression
- Transfer principal not revenue/expense; two legs atomic; fees only once; account filter and all-accounts no duplicates.
- Goal creation without funding has no ledger card; goal funding and withdrawal post once; separate wallet invariant; no underflow.
- Due announcement vs confirmed settlement, postpone, retry, duplicate tap, linked goal occurrence and financial failure recovery.
- SMS incrementally reclassifies stale pending, handles 2,000 items without Home freeze, preserves user exclusion and OTP security, never modifies settled finance; results persist across restart.
- Cross-platform text RTL/LTR and PDF category colors/types/totals. Existing M385/M449/M550 safety guards and only-main APK policy remain in force.
