# Waffra — Permanent Requirements Register

> Source of truth for newly submitted changes. **Record the requirement and GitHub Issue before coding**; link the implementation PR, tests, code commit(s), and real device validation. Never mark an item Done just because a commit exists.
>
> Started: 2026-11-06. Existing historical batches are in `docs/qa/WAFFRA_32_NEW_CHANGES_M470_TRACKER.md`. The NEW numbering here is a separate sequential series, not a rewrite of those 32 entries.

## Status definitions
- **Recorded / Not implemented**: acceptance criteria captured; source change not yet implemented.
- **In progress**: implementation has started on the PR branch.
- **Code ready / CI pending**: source and tests committed; exact-head CI incomplete.
- **CI passed / device pending**: relevant latest SHA tests passed; real-device UI not yet validated.
- **Done**: approved behavior demonstrated with passing tests, owner/device sign-off where required and merged to `main`.

## Requirements index

| ID | Requirement | GitHub Issue | Implementation PR | Status | Code and test evidence |
|---|---|---|---|---|---|
| WAFFRA-NEW-001 | Home balance card: replace top bank/account heading with its account dropdown; remove floating lower dropdown; show full long names without truncation and avoid overlaps | [#401](https://github.com/MahmoudMAnwar/waffra-app/issues/401) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Not yet committed or tested |

| WAFFRA-NEW-002 | SMS review → entry: prefill title, amount, type, main/subcategory | [#403](https://github.com/MahmoudMAnwar/waffra-app/issues/403) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-003 | Preserve SMS source and protected original instead of mislabeling manual | [#404](https://github.com/MahmoudMAnwar/waffra-app/issues/404) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-004 | Preselect new financial-account institution from the sender | [#405](https://github.com/MahmoudMAnwar/waffra-app/issues/405) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-005 | Allow adding custom account subtype, not only listed presets | [#406](https://github.com/MahmoudMAnwar/waffra-app/issues/406) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-006 | Prepopulate verified masked last-four in child account creation | [#407](https://github.com/MahmoudMAnwar/waffra-app/issues/407) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-007 | Reuse trusted sender and last-four to select child account next time | [#408](https://github.com/MahmoudMAnwar/waffra-app/issues/408) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-008 | Keep full readable original SMS accessible while reviewing and editing | [#409](https://github.com/MahmoudMAnwar/waffra-app/issues/409) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-009 | Back navigates exactly one step, preserves SMS draft/context | [#410](https://github.com/MahmoudMAnwar/waffra-app/issues/410) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |
| WAFFRA-NEW-010 | Remove successfully posted SMS from pending; dedupe and rollback | [#411](https://github.com/MahmoudMAnwar/waffra-app/issues/411) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Awaiting code, exact-head CI and Android QA |

| WAFFRA-NEW-011 | Reuse the already-confirmed bank + child account selection on submit; no second account modal | [#412](https://github.com/MahmoudMAnwar/waffra-app/issues/412) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Existing `reviewSmsAccountLinks` unconditionally opens dialog; no test run yet |

| WAFFRA-NEW-012 | Learn reusable safe description keywords after confirmed manual **and** SMS income/expense, merge into same review-only rules without assigning bank accounts | [#413](https://github.com/MahmoudMAnwar/waffra-app/issues/413) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | `lib/waffra_sms_local_rules.dart`, `lib/main.dart`, `test/m473_manual_sms_keyword_learning_parity_test.dart`; exact-head CI + Android unverified |

| WAFFRA-NEW-013 | Account rename dialog shows persisted last-four suffix and allows user to correct it, preserving balances and verified SMS account mappings | [#414](https://github.com/MahmoudMAnwar/waffra-app/issues/414) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Documentation only; no app-code changes authorized |
| WAFFRA-NEW-014 | SMS bank account confirmation shows selected child's already-saved last-four digits; refreshed when account selection or suffix changes | [#415](https://github.com/MahmoudMAnwar/waffra-app/issues/415) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Documentation only; no app-code changes authorized |

| WAFFRA-NEW-015 | In manual and SMS-derived transaction entry, provider is selected first; child-account dropdown is dimmed until provider is confirmed; both lists include their own inline add option; remove duplicate bottom Account button and keep date | [#416](https://github.com/MahmoudMAnwar/waffra-app/issues/416) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Recorded / Not implemented** | Documentation only; no app-code changes authorized |

## WAFFRA-NEW-001 — Detailed acceptance contract

**User screenshot (2026-11-06):** Current green balance card shows the account name (`مصرف الإنماء - الإنماء باي`) at its top; a second dropdown with the same truncated name appears on the bottom-right and overlaps the illustration. User explicitly rejected this placement.

1. Replace the bank/account heading **inside** the green balance card with a tappable **account selector** in exactly the heading area (upper central area). For `All accounts / كل الحسابات`, the same selector shows that full label. Preserve a single picker, remove the bottom-right floating picker.
2. Show the **entire** selected provider/account name, even if very long. No `TextOverflow.ellipsis`, no fixed `maxLines:1`, no `maxWidth:156` that cuts names. Wrap onto multiple lines and size the card/control/layout to content. Keep the arrow visible and the whole control tappable.
3. Do not overlap the amount, privacy-eye, illustration/wave, comparison badge, surrounding cards, or the collapsing balance header. Support RTL, LTR, narrow devices and font scaling.
4. Keep verified account selection and all-account balance/metrics filtering unchanged. Do not alter financial amounts, SQLCipher storage/authorities, transaction linking, or the mandatory source-account rule.
5. Add Flutter widget/layout/regression coverage for long/short Arabic and English account names, multiple text scales, picker open/select, visible full text, no second picker and no overflow; verify actual Android UI before marking Done.

**Current source anchor:** `lib/main.dart`, class `WaffraBalanceHeader`; the top heading is `WaffraText(heading...maxLines:1)`; the bottom picker has key `m470-balance-account-picker`, positioned at `right:10,bottom:10`, constrained to `maxWidth:156`, `maxLines:1` with ellipsis. This is a documentation-only initial commit.

**Tracking:** Issue [#401](https://github.com/MahmoudMAnwar/waffra-app/issues/401); implementation [PR #402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**


## 2026-11-06 — SMS review → financial posting screenshot batch

**Issues #403–#411 / WAFFRA-NEW-002…010:** registered before coding in [draft PR #402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Observed:** The 276 SAR top-up SMS goes to an empty manual entry form; after saving, details falsely show 'إدخال يدوي' with no original SMS; first bank account form does not preselect sender/suffix; message disappears from editing context when Back is pressed and the confirmed SMS remains pending. Source screenshots stay with the user, without copying bank recipients or private full SMS to GitHub.

### WAFFRA-NEW-002 — SMS review → entry: prefill title, amount, type, main/subcategory

**Issue:** [#403](https://github.com/MahmoudMAnwar/waffra-app/issues/403) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Use the scanned SMS facts to prepopulate operation title, actual SAR amount, expense/income type, date, matched main and subcategory; example 276 SAR phone top-up. Editable suggestions; uncertain fields must be reviewed, no fabricated category or fee/principal swap.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-003 — Preserve SMS source and protected original instead of mislabeling manual

**Issue:** [#404](https://github.com/MahmoudMAnwar/waffra-app/issues/404) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Persist immutable SMS ID/hash, sender and secure original reference even if the user edits the SMS-derived entry with the manual-style editor. Transaction details must say bank SMS reviewed and confirmed by user, not independent manual entry or no original SMS.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-004 — Preselect new financial-account institution from the sender

**Issue:** [#405](https://github.com/MahmoudMAnwar/waffra-app/issues/405) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** First scanned SMS from confirmed sender e.g. AlinmaPay suggests/prefills its matching provider/institution in Add Account. User confirms correct institutional identity and supplies child-account data. No automatic money posting or unverified provider binding.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-005 — Allow adding custom account subtype, not only listed presets

**Issue:** [#406](https://github.com/MahmoudMAnwar/waffra-app/issues/406) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Offer 'إضافة نوع حساب' in the new account type/subtype dropdown; validate and persist custom type for later reuse without bypassing trusted bank/wallet/cash accounting classifications.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-006 — Prepopulate verified masked last-four in child account creation

**Issue:** [#407](https://github.com/MahmoudMAnwar/waffra-app/issues/407) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Derive correct source/destination account suffix (e.g. ••••8308) from reviewed message, prefill child account suffix, user confirms; never use an unrelated recipient, phone number, 4-digit OTP, fee or amount.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-007 — Reuse trusted sender and last-four to select child account next time

**Issue:** [#408](https://github.com/MahmoudMAnwar/waffra-app/issues/408) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Remember approved provider and unique child account mapping from sender plus masked account suffix/direction. Subsequent SMS suggests/chooses verified matching account, asks when ambiguous, never inherits Home filter or blindly trusts sender name.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-008 — Keep full readable original SMS accessible while reviewing and editing

**Issue:** [#409](https://github.com/MahmoudMAnwar/waffra-app/issues/409) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Show sender, date and full read-only original SMS in both review and entry, with safe mixed Arabic/English/number direction and OTP redaction; user must not navigate back to retrieve message text.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-009 — Back navigates exactly one step, preserves SMS draft/context

**Issue:** [#410](https://github.com/MahmoudMAnwar/waffra-app/issues/410) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** Sender list → message review → editor → account selection/creation uses correct Android/dialog back stack; back returns to previous step, not Home, preserving draft, message and review-scroll context.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

### WAFFRA-NEW-010 — Remove successfully posted SMS from pending; dedupe and rollback

**Issue:** [#411](https://github.com/MahmoudMAnwar/waffra-app/issues/411) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402).

**Acceptance:** After verified commit of income, expense or transfer, mark exact reviewed SMS ID/hash recorded, remove from pending view and refresh counts. If save fails/cancels keep review row/draft. Preserve original for audit; prevent duplicate records/charges/rescans.

**Validation:** targeted Flutter/widget source checks, actual signed Android screenshots and end-to-end flow, SQLCipher verified-writer/deduplication tests where applicable. Preserve existing M470 rules and current `main` behavior.

**Status: Recorded / Not implemented.** Existing historical fixes may partially cover this item; check behavior rather than inferring completion from committed source.

**Non-regression invariant:** No accidental automatic transaction posting, no sender-only trusted account selection, no default from Home header; all newly posted money entries require the user-confirmed financial account. On failure, retain draft and pending state; after success, remove only the correctly identified SMS from pending and preserve encrypted provenance.


### WAFFRA-NEW-011 — Prevent duplicate account confirmation dialog

**Issue:** [#412](https://github.com/MahmoudMAnwar/waffra-app/issues/412) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**Android screenshot, 2026-11-06:** User already chose bank/provider and its child financial account while adding a scanned-SMS-derived income/expense. On pressing **تأكيد وحفظ العملية**, the same two fields are shown again in the large **اختار الحساب المالي للعملية** popup. One financial account selection must be sufficient.

**Source-confirmed root cause:** `lib/main.dart` already passes `chosenManualAccount` through `initialSelectedIds` to `reviewSmsAccountLinks([result], ...)`, but `reviewSmsAccountLinks` still always builds and opens another account selection modal. The first-SMS account creation path similarly sets `createdFromSmsAccountId` and then always shows the dialog.

**Expected:** Reuse the previously and explicitly approved selected account ID (including newly created child account) without a redundant modal, but always validate current account existence, bank/provider match, activity and up-to-date verified SQLCipher generation before any write. Only show a selector for absent, invalid, newly ambiguous or changed choices, never silently assign one. Respect mandatory accounts and prevent duplicate finance posting; retain draft and SMS provenance on failure.

**Tests to require:** manual income/expense, SMS-derived income/expense, created account, already selected account, archived/changed account, provider mismatch, no account selected, multiple SMS candidates, cancel/back/retry and signed Android UI test. Account selector never appears twice for a valid selection.


### WAFFRA-NEW-012 — Unified learning from saved manual and SMS income/expense

**Issue:** [#413](https://github.com/MahmoudMAnwar/waffra-app/issues/413) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**User expectation (2026-11-06):** Every **confirmed** manual or reviewed bank SMS income/expense should contribute safe, reusable keywords learned from its final user-approved title/description and category/subcategory. A future SMS containing matching description keywords gets a **suggestion** of direction and category; category and finance-account decisions remain editable and require normal verified confirmation.

**Current source evidence:** `lib/main.dart` calls `_learnManualCategoryPreference` after a manual financial commit, and `_learnSafeSmsRule` after qualified SMS confirmation. In `lib/waffra_sms_local_rules.dart`, `manualCategoryPattern` learns one entire description phrase, `upsertLearned` groups direction/sender/bucket and maps keywords to categories. No general token/phrase extraction across equivalent SMS descriptions; the manual operation doesn't know SMS sender/suffix or bank-account identity, and cannot create a trusted sender→account binding.

**Acceptance criteria:** (1) Extract cautious merchant/description phrases, normalize Arabic/English, drop numeric/secret/generic/ambiguous terms; (2) merge keywords to existing income and expense review-only buckets, map phrases to final user-approved subcategory, don't clone endlessly; (3) no implicit SMS account selection from manual, keep verified SMS sender+suffix account learning separate; (4) never auto-post, infer income/expense against independent bank evidence, override existing explicit rules, or double-charge; (5) test manual/SMS income, expense, phrase variation, category conflict, unsafe suffixes, duplicate saved operation, no learning before financial confirmation and persistence across relaunch.

**Implementation status:** **Code ready / CI pending**. Added conservative description-keyword extraction and shared post-confirmed write hooks for manual and bank SMS. Added targeted Flutter parity tests; CI, runtime Android check and merge remain unverified. Do not mark Done before exact-current-head tests and device proof.

## 2026-11-06 — Account last-four display/edit follow-up (documentation only)

**User instruction:** Save both additional requirements in PR #402 and the permanent register; **do not start implementing them**. These two are **separate** items, adding to the prior 12 for a total of **14**. These screenshots are private context; do not commit raw images or financial details to the repository.

### WAFFRA-NEW-013 — Show/edit saved suffix while editing account name

**Issue:** [#414](https://github.com/MahmoudMAnwar/waffra-app/issues/414) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**Current screen:** حساباتي → account overflow menu → تعديل اسم الحساب currently edits the name alone.

**Approved behavior:** Add a visible field labeled **آخر 4 أرقام للحساب** under the account name, populated with the previously persisted four digits if present, and editable so the user can correct an incorrect suffix. Accept exactly four digits when provided, display digits LTR in an RTL form, allow an absent/unset suffix without faking digits, and persist the modification on the same SQLCipher-protected financial account.

**Integrity:** Updating the last four cannot change balances, account IDs, historical transaction links, transfers or original SMS. A corrected suffix must invalidate/recheck obsolete verified SMS sender+suffix account matches so future transactions do not silently use the wrong account. Cancel/failure leaves previous values unchanged.

**Future acceptance:** Existing/empty suffix, valid/invalid edits, save/cancel, persistence across restart, verified SMS mapping refresh, UI RTL/keyboard/narrow layout, finance regression checks, Android screenshot validation. **Do not implement until user explicitly requests.**

### WAFFRA-NEW-014 — Show persisted suffix in SMS account confirmation

**Issue:** [#415](https://github.com/MahmoudMAnwar/waffra-app/issues/415) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**Current screen:** عمليات الحسابات → ربط حساب بالرسائل البنكية → تأكيد حساب الرسائل البنكية: account selector currently shows the account name but not its four-digit suffix.

**Approved behavior:** Whenever the user selects the bank/provider's financial child account, display its already-saved suffix visibly beside/below the selection (**آخر 4 أرقام للحساب: ••••1234**, with example digits only). Refresh when another account is selected or when the account's saved digits were corrected under NEW-013. If no suffix was previously supplied, show **غير مضاف**, not invented digits. Display only the selected child account's persisted suffix, never reuse digits from a previous selection or from potentially untrusted SMS text.

**Integrity:** This dialog is for verifying/confirming SMS linkage, not editing saved last-four digits. Preserve trusted suffix comparisons, ambiguity warnings and explicit user confirmation; no automatic money posting or change to bank balances. Avoid reintroducing the redundant account-selection modal tracked as NEW-011.

**Future acceptance:** Saved/absent last-four, same-bank multiple child accounts, switching choices, NEW-013 update reflected, mismatched scanned suffix, persistence, accessibility and actual Android UI. **Do not implement until user explicitly requests.**

## 2026-11-06 — Cascading financial-account selection in transaction editor

### WAFFRA-NEW-015 — Bank/provider first, child account second; add inside dropdowns

**Issue:** [#416](https://github.com/MahmoudMAnwar/waffra-app/issues/416) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**User screenshots:** Current **إضافة عملية** form has two dropdowns (الجهة أو البنك, الحساب المالي التابع) **and** an extra separate **الحساب** button in the lower left beside the date. The provider picker opens a bottom sheet with existing institution and a lower **إضافة حساب** action. Desired design consolidates selection + new account creation into the two dependent dropdowns, including on a second/subsequent transaction.

**Approved behavior:**
1. For new/repeated **manual entry and bank-SMS-reviewed entry**, present **الجهة أو البنك** as the first active selector; **الحساب المالي التابع** stays visibly dimmed **and truly disabled** until a valid top-level institution/provider is chosen or safely confirmed in the current editor. Do not allow child selection without knowing its parent.
2. Provider/bank dropdown itself contains **+ إضافة جهة أو بنك** (create main provider). After successful creation, return to the same entered draft with the new parent selected. Preserve all transaction fields and SMS linkage on successful creation/cancel.
3. Once parent chosen, enable the child-account dropdown and limit the list to that parent. Child list itself contains **+ إضافة حساب تابع** (create the child account under this selected parent). Return to the draft with the new confirmed child chosen after a successful save.
4. When switching the parent, clear an incompatible old child selection and require a valid child under the new parent. If a parent has zero children, keep the child dropdown available with the add-child option, rather than forcing the user to exit the editor.
5. **Remove the standalone bottom-left "الحساب" button** next to the date from the manual/SMS entry UI. **Retain the date button** unchanged and fully functional.
6. Apply to income, expense and internal transfer where the corresponding account selection is relevant. Never bypass mandatory user-approved money account or silently inherit the Home header filter. Prevent a redundant account-selection dialog at submit (#412).
7. Coordinate with existing trusted SMS sender/last-four auto-suggestions (#408): a verified preselected parent/child may be shown only when valid and confirmed according to the trusted flow; otherwise require explicit provider choice and keep the dependent child disabled. Do not assume an SMS sender display name alone is trustworthy or post money automatically.
8. RTL/LTR readability, dimmed disabled styling **plus non-interactive semantics**, no lag or clearing of description, amount, category, subcategory, date, receipt photo or SMS source during nested create/cancel/Back.

**Future acceptance:** first and second/manual and bank SMS transactions, all entry types, no provider selected, changed provider, account creation from each dropdown, created item selected on return, existing children, no children, canceled account creation, corrupted/archived child, validation on Save, no duplicate picker/button, no finance change on account creation, Android screenshots and targeted CI.

**Explicit user instruction:** **Save this requirement alongside the existing PR #402 items without any app code implementation now.** All original 14 requirements are preserved. The scoped PR now tracks **15 distinct requirements**.
