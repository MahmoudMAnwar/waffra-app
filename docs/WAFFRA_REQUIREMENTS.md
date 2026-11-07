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
| WAFFRA-NEW-001 | Home balance card: replace top bank/account heading with its account dropdown; remove floating lower dropdown; show full long names without truncation and avoid overlaps | [#401](https://github.com/MahmoudMAnwar/waffra-app/issues/401) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress** | M476 header moved and wraps full account name; M495 narrow-screen 320px Flutter widget test added. CI/Android rotation checks pending |

| WAFFRA-NEW-002 | SMS review → entry: prefill title, amount, type, main/subcategory | [#403](https://github.com/MahmoudMAnwar/waffra-app/issues/403) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M485 + analyzer correction: SAR source/direction/title/category/date prefill and user correction remain; four unnecessary null-safe analyzer warnings corrected. Exact-head Flutter analyzer/Android QA pending |
| WAFFRA-NEW-003 | Preserve SMS source and protected original instead of mislabeling manual | [#404](https://github.com/MahmoudMAnwar/waffra-app/issues/404) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M485/M494: SMS correction preserves original bank source/hash and human-reviewed provenance. Reviewed SMS body is read-only; parsed amount/title/category stay editable. Android/restore QA pending |
| WAFFRA-NEW-004 | Preselect new financial-account institution from the sender | [#405](https://github.com/MahmoudMAnwar/waffra-app/issues/405) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Existing partial code / QA pending** | M494: nested provider/child Add opens a user-confirmed typed account form directly, preselecting verified known bank group. New account is re-read from SQLCipher before linking; sender impersonation/Android QA pending |
| WAFFRA-NEW-005 | Allow adding custom account subtype, not only listed presets | [#406](https://github.com/MahmoudMAnwar/waffra-app/issues/406) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M487/M497: user adds and reuses bank/wallet custom subtype, persists encrypted versioned display metadata and shows it beneath the created account name in My Accounts; canonical kind and balances unchanged. Tests: test/m487_custom_subtype_dialog_test.dart and test/storage/m487_custom_account_subtype_test.dart. Exact-head CI, verified backup/restore and Android QA pending |
| WAFFRA-NEW-006 | Prepopulate verified masked last-four in child account creation | [#407](https://github.com/MahmoudMAnwar/waffra-app/issues/407) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M483 + M496: bank SMS first-account and inline child-account forms propose editable four digits only when recognized reviewed sender matches selected bank and trusted SAR direction picks source for expense/destination for income. Widget+source tests added; Android transfer/nested QA pending |
| WAFFRA-NEW-007 | Reuse trusted sender and last-four to select child account next time | [#408](https://github.com/MahmoudMAnwar/waffra-app/issues/408) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Existing partial code / QA pending** | M493: two-confirmation account learning now rejects active accounts outside sender's verified same-bank group even if suffix matches. Unit tests cover different banks, two same-bank accounts, stale account, conflicting selection. Encrypted restart QA pending |
| WAFFRA-NEW-008 | Keep full readable original SMS accessible while reviewing and editing | [#409](https://github.com/MahmoudMAnwar/waffra-app/issues/409) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M484 original selectable in native review; M494 read-only original SMS expandable inside entry editor, with received source immutable and pending/OTP preview hidden. Test source assertions added; Android/restore QA pending |
| WAFFRA-NEW-009 | Back navigates exactly one step, preserves SMS draft/context | [#410](https://github.com/MahmoudMAnwar/waffra-app/issues/410) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M486 + M492: sender route retained underneath editor and unfinished SMS title/amount/categories/budget/account/date restored by a bounded in-memory hash-keyed draft, purged on confirmed commit. Regression source test added; Android Back/resume QA pending |
| WAFFRA-NEW-010 | Remove successfully posted SMS from pending; dedupe and rollback | [#411](https://github.com/MahmoudMAnwar/waffra-app/issues/411) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M484: native pending item removed only after verified SMS hash and successful native acknowledge, with existing transfer idempotency. M490: manual-correction path now visibly warns on failed native acknowledgement while retaining the pending SMS; test/m486_sms_back_navigation_source_test.dart covers source contract. Retry/rollback Android QA pending |

| WAFFRA-NEW-011 | Reuse the already-confirmed bank + child account selection on submit; no second account modal | [#412](https://github.com/MahmoudMAnwar/waffra-app/issues/412) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress** | M475 explicit account selection bypass with fresh verified witness, plus M495 guard test for selected/newly created account. CI/Android pending |

| WAFFRA-NEW-012 | Learn reusable safe description keywords after confirmed manual **and** SMS income/expense, merge into same review-only rules without assigning bank accounts | [#413](https://github.com/MahmoudMAnwar/waffra-app/issues/413) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M473 manual + SMS keyword learning source and parity test committed; latest CI and Android still pending |

| WAFFRA-NEW-013 | Account rename dialog shows persisted last-four suffix and allows user to correct it, preserving balances and verified SMS account mappings | [#414](https://github.com/MahmoudMAnwar/waffra-app/issues/414) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M481 editable name + saved last-four UI and one witnessed SQLCipher writer, storage QA test m481_saved_bank_suffix_edit_test.dart; Android pending |
| WAFFRA-NEW-014 | SMS bank account confirmation shows selected child's already-saved last-four digits; refreshed when account selection or suffix changes | [#415](https://github.com/MahmoudMAnwar/waffra-app/issues/415) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M481 selected bank loads saved suffix from verified SQLCipher and blocks submit on unverified reads; Android pending |

| WAFFRA-NEW-015 | In manual and SMS-derived transaction entry, provider is selected first; child-account dropdown is dimmed until provider is confirmed; both lists include their own inline add option; remove duplicate bottom Account button and keep date | [#416](https://github.com/MahmoudMAnwar/waffra-app/issues/416) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M477/M482/M488/M494 + M499: manual income/expense, both source and destination of manual transfer, SMS-reviewed transfer and My Accounts composer all have provider-first/child-second in-dropdown creation with verified SQLCipher account reread; cancel preserves draft. CI, Android, RTL and encrypted restore QA pending |

| WAFFRA-NEW-016 | Second SMS exclusion popup must offer **العودة** to reconsider sender exclusion and return to prior selection without finalizing sender block; later unexclude via excluded list | [#417](https://github.com/MahmoudMAnwar/waffra-app/issues/417) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress** | M479/M494 sender Back preserves selection before native acknowledgment, failed partial batch now keeps review sheet mounted with remaining selections; multi-sender/device QA pending |
| WAFFRA-NEW-017 | After removing bottom Account button, date expands full row; when optional budget control is displayed, date and budget split row equally 50/50 | [#418](https://github.com/MahmoudMAnwar/waffra-app/issues/418) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress** | M478 date full width without budget and equal date/budget halves when budget exists; M495 source regression added. Small-device layout QA pending |

| WAFFRA-NEW-018 | App-wide lag/jank: biometric first launch, pull-to-refresh, + sheet, transaction save, footer navigation; trace root causes, optimize, benchmark physical Android without compromising financial/security integrity | [#419](https://github.com/MahmoudMAnwar/waffra-app/issues/419) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **In progress / CI pending** | M474 smooth FAB/refresh/footer and M486 deferred noncritical post-biometric I/O; M495 guard tests added. Real Android frame timing, cold-launch, scroll and loading animation traces still required |

| WAFFRA-NEW-019 | Details → Edit for an existing historical income/expense must show the same provider-first/child-second verified account picker as Add, and allow confirmed retroactive linking without duplicate posting; preserve prior provenance and old-device migration safety | [#420](https://github.com/MahmoudMAnwar/waffra-app/issues/420) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — Draft | **Code ready / CI pending** | M500: `lib/main.dart` existing edit + consent; `lib/storage/waffra_account_context_repository.dart` bounded association read; `lib/storage/waffra_verified_accounts_api.dart` witnessed reader; `test/storage/m500_historical_entry_edit_account_link_test.dart` and M495 regression. Legacy-to-SQLCipher migration and Android APK acceptance independent and still pending |

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

**Current implementation (M487):** bank/wallet subtype dropdown offers «إضافة نوع حساب», validates and stores the user-approved label in a separate versioned encrypted table while preserving the existing subtype enum and account balances. Saved custom labels can be reused in subsequent account creation. Pending exact-head CI, real Android UI, migration/backup verification. **Status: Code ready / CI pending.**

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

**Current implementation (M486):** sender inbox route remains mounted under message detail and nested entry/account flows, so a single Back returns to the same sender list and selected IDs. Source regression test added; unsaved draft retention after exiting the editor and physical Android navigation tests are still outstanding. **Status: In progress / CI pending.**

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

## 2026-11-06 — Follow-up SMS exclusion reconsideration and date/budget row

### WAFFRA-NEW-016 — Add a genuine Back/reconsider option to sender exclusion prompt

**Issue:** [#417](https://github.com/MahmoudMAnwar/waffra-app/issues/417) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**Screenshot scenario:** In Waffra SMS review, selecting messages and pressing **تأكيد الاستبعاد** first shows **استبعاد الرسائل المحددة؟**. On confirmation, the second dialog **هل تريد استبعاد المرسل نفسه أيضًا؟** offers **استبعاد المرسل** or **لا** only. The user asks for an **العودة** action in this second decision so someone who changes their mind can step back rather than committing sender exclusion.

**Approved behavior:**
1. Add **العودة** to the second **sender exclusion** dialog, distinct from **لا**. Return one step to the first exclusion confirmation or selected-message review while preserving sender, selected SMS and review context. No sender blocklist change on Back.
2. **لا** confirms *message-only* exclusion while leaving the sender eligible for future SMS processing. **استبعاد المرسل** blocks that sender's future SMS analysis/review as approved. On Back, **do not silently finalize either decision**; if message exclusion has already committed, safely allow undo of those just-excluded messages before reentering review.
3. Excluded sender remains recoverable via **المستبعدون** with unexclude/reactivation. Where appropriate, allow an immediate explicit **تراجع** after sender exclusion as well. Undo must target only the intended sender/messages, never delete device SMS or verified financial postings.
4. Clear button labels, correct dialog/Android Back stack, no duplicate excluded records, preserve account data, finance balances, already-saved transactions and SMS provenance.

**Future tests:** confirm messages→second dialog→Back→review with selection; “لا” vs sender exclusion; undo/re-enable sender and proper future scan behavior; partial failures/restart; small-screen RTL popup layout. **No code changes until explicitly requested.**

### WAFFRA-NEW-017 — Date row width depends on budget control

**Issue:** [#418](https://github.com/MahmoudMAnwar/waffra-app/issues/418) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**Screenshot scenario:** The **إضافة عملية** sheet currently shows a bottom **الحساب** button to the left of the date picker. Per NEW-015/#416 that separate account button will be removed, leaving its space available.

**Approved behavior:**
1. When no **ميزانية** control is displayed, **التاريخ** occupies **100% of the row**. Keep the existing calendar icon, date chooser, date value and tap area; no blank placeholder on the left.
2. When an **optional ميزانية / إضافة ميزانية selector** is present on that row, show **التاريخ** and **الميزانية** side by side, **50% width each** with proper spacing and center division. This is a responsive visual requirement, not a rule forcing budgets on transactions.
3. Preserve the date and rest of the draft when choosing/adding budget. Budget remains optional, independent of required financial account; internal transfers must remain outside spending-budget calculations.
4. Apply consistently in manual and SMS-reviewed entry forms wherever that budget is applicable. Do not reintroduce a standalone Account button below the form and do not change the two required provider/child dropdowns above.
5. Test narrow devices, Arabic/English RTL/LTR date, long budget names, text scaling and overflow, all transaction types, saved/unsaved budget, no-budget full width.

**User instruction/context:** Save both alongside PR #402 and prior requirements; **documentation-only; no app source updates or feature implementation**. Total now **17 distinct numbered requirements**, including one earlier source-implemented keyword-learning item awaiting verification.

## 2026-11-06 — App-wide performance and responsiveness

### WAFFRA-NEW-018 — Systemic fix for recurring UI lag and jank

**Issue:** [#419](https://github.com/MahmoudMAnwar/waffra-app/issues/419) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402). **Status: Recorded / Not implemented.**

**User report:** Lag remains in *many* parts of Waffra despite previous fixes. Specifically (1) first app opening immediately after enabling biometrics; (2) pull-to-refresh everywhere; (3) tapping floating + to open Add Transaction; (4) adding/saving finance operations (manual or reviewed SMS, transfer, goal/recurring where affected); (5) switching between footer navigation tabs. User requests a root-cause, app-wide performance optimization effort, not a cosmetic loading animation tweak.

**Approved scope and implementation contract (future work only):**
1. Profile exact reproducible journeys in **Flutter profile/release on Android devices**, identify UI/raster thread stalls, synchronous decode/encryption/database work, large data recomputation, widget rebuild storms, repeated requests, overly costly animation effects, memory churn, overlays/navigation and resume/biometric lifecycle timing before choosing any fix.
2. Collect reproducible **baseline and after** traces for first launch after biometric activation, cold/warm launch, unlock, every page's pull refresh, + menu open, manual/SMS income/expense and transfers save, footer switching and rapid repeat taps, using both clean-install and update-over-data scenarios. Include at least one high-transaction/high-SMS volume scenario.
3. Preserve verified SQLCipher money storage and encrypted backups, authorization/lifecycle privacy shields, source-account requirements, SMS provenance/consent, budgets/goals/recurring correctness, duplicate write prevention and accurate dashboard/widget balances. Do not bypass security or fake responsiveness by ignoring updates.
4. Apply targeted code optimizations based on measured bottlenecks (e.g. moving CPU-bound jobs away from UI isolate, canceling redundant stale refreshes, minimizing unnecessary page rebuilds, incremental recomputations, image/layout optimization), while preserving every required visible feature and actual account correctness.
5. **Acceptance criteria:** no routine visually frozen or unresponsive UI in listed flows; measured build/raster frame timings and jank frequency, tap-to-UI feedback, startup-to-interactive time, refresh latency, memory and database operations compared to baseline. Target smooth frames appropriate to device refresh (at 60 Hz 16.7ms budget, at 120Hz 8.3ms); formal thresholds must be set after profiling. Validate on real Android hardware, latest PR commit CI and no-finance-regression functional tests. 'Zero lag everywhere forever' cannot be guaranteed, so only mark Done after measurements and user/device confirmation.
6. Track as **one app-wide requirement** with explicit test matrix, not a pile of uncorrelated spinner tweaks. Cross-reference older performance and pull-refresh issues where appropriate, while retaining a single acceptance status for this new tracked request.

**User instruction:** Register this requirement with existing PR #402 scope. **Do not start code implementation now.** Prior 17 requirements remain intact; total becomes **18 numbered items**.

## 2026-11-06 — Implementation evidence refresh on draft PR #402

The owner approved beginning implementation of the tracked 18 requests. The table above is the *code status only*: no item is marked Done without exact-head CI and physical Android acceptance. Current implementations include M474 (partial app-wide performance), M475 (duplicate account picker), M476 (balance heading), M477 (partial linked-account dropdown creation), M478 (optional date/budget row), M479 (sender exclusion Back), and M480/M481 (verified last-four reads/editing and tests). Existing M473 keyword learning remains on the branch. Other numbered requirements remain open.

- New source and test for saved bank suffix: `lib/storage/waffra_account_context_repository.dart`, `lib/storage/waffra_verified_accounts_api.dart`, `lib/waffra_accounts_manager_page.dart`, `lib/waffra_account_context_settings.dart`, `test/storage/m481_saved_bank_suffix_edit_test.dart`.
- The M385 approved section manifest names each edited function boundary; M449 release notes will follow the latest application-code commit.
- Remaining high-risk paths include SMS context/prefill/provenance #403–#411, SMS and internal-transfer parity under #416, first-run biometric startup and save performance profiling, repeated loading animations, exact-head CI and two-phone APK validation.
- No database reset, destructive migration, security bypass, or automatic posting is approved by these UI changes.


## 2026-11-06 — M499 / Issue #416 transfer parity follow-up
- Source and destination dropdowns in the manual transfer form each now provide **+ إضافة جهة أو بنك** and **+ إضافة حساب تابع**. The child list cannot be used until a provider has been chosen; changing the provider clears an incompatible child. Creating an account uses only the verified SQLCipher typed-account writer, and does not post any transaction.
- The bank-SMS-reviewed transfer form and the My Accounts financial transaction composer now receive a user-triggered verified account-creation callback. The same dependent dropdown behavior is available there too; cancellation returns without losing the transfer amount, date or memo.
- An explicitly created child is associated with its verified real provider group; a linked child for a known bank cannot be accepted from another bank. The transfer still requires two distinct live accounts and an independently confirmed money write. Sender display text does not authorize source or destination.
- **Code ready / CI pending, not Done**. Tests in `test/m495_pr402_ui_performance_regression_test.dart` cover dependent menus and cancellation. CI exact HEAD, Android runtime, narrow RTL layout, first/second operation and restore migration acceptance still required.

## 2026-11-06 — WAFFRA-NEW-019: Link a historical entry from its own Edit sheet

**Issue:** [#420](https://github.com/MahmoudMAnwar/waffra-app/issues/420) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) · **Status: Code ready / CI pending.**

The owner explicitly requests transaction Details → Edit to offer the same provider-first, dependent child-account selection and inline Add behavior as new income/expense. For a prior *unassigned* entry imported/recorded in the verified finance ledger, user confirmation binds its historical `entry_id` to one active account through the existing atomic, idempotent verified SQLCipher account-link route. No duplicate income/expense, no changed transaction IDs, no implicit Home/SMS-derived account, no loss of original SMS or receipt, and a canceled/failed edit has no effect. Prelinked entries cannot be reassigned implicitly by editing metadata. Preserve amount/date/category edits using their existing authority path; do not treat a metadata edit as permission to repost or rewrite ledger account links. Add regression tests for edit, cancel, inline account creation, repeated commit and balance integrity. Update-over-old-data migration and encrypted backup/restore require **separate** Android acceptance; existence of the linking UI is not proof of successful legacy cutover.

**Source targets:** `lib/main.dart` entry editor; `lib/storage/waffra_verified_accounts_api.dart` existing `linkUnassignedEntry`; `test/...` regression and `docs/qa/approved_change_scope.json` gate. **CI and Android:** pending. Total tracked **19** requirements (#001–#019).

### WAFFRA-NEW-019 — M500 code evidence update
- In Details → Edit, verified existing ledger entries receive the same dependent provider/child selectors and inline typed account creation; confirmed entries are read under an encrypted witness. An already-linked entry is shown read-only, not moved implicitly.
- Unassigned entries have an explicit balance-impact confirmation before saving. The association commit uses `linkUnassignedEntry` with a fresh witnessed generation, existing entry ID, and no new income/expense. Successful account association suppresses misleading metadata-only Undo; failure advises verification before retry.
- `test/storage/m500_historical_entry_edit_account_link_test.dart` covers missing legacy-only entry, idempotency, zero duplicate rows, original provenance/amount, refusal to move existing link and cancellation. M495 source regression checks Edit UI route and confirmation.
- **Independent blocker:** no verified proof that an update of an actual legacy pre-accounts Android installation has fully migrated transactions, budgets, goals, recurring items and receipt bytes into the encrypted ledger. Do not claim acceptance on wife's phone before a backed-up update-over-data device rehearsal.


## 2026-11-06 — WAFFRA-NEW-020: Critical sign-out failure on account and biometric pages

**Issue:** [#424](https://github.com/MahmoudMAnwar/waffra-app/issues/424) · **PR:** [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) · **Status:** Code candidate; latest-head CI, real Android and login-again verification pending.

The user reproduced an unresponsive **تأكيد** button in the sign-out confirmation on My Account and the unresponsive **تسجيل الخروج** escape on mandatory biometric lock. The M470 source-only test had not validated a real in-progress OS biometric callback or root-level error UI. Investigated branches: mandatory gate disables sign-out while biometric is busy; WaffraApp is above MaterialApp's ScaffoldMessenger so a failed credential/Android SMS/source-lock preflight could give no visible error. Preserve original profile verifier, signed-out suspension, standing owner-bound SMS consent, SQLCipher ledger and backups; never bypass error conditions or claim safe logout if storage failed. Use a root messenger key with visible progress and failure, ensure biometric signout cancels the pending OS prompt and rejects stale unlock result, keep ordered native SMS pause before authority signout, bounded timeouts and retry. No password re-registration or local ledger deletion.

**Acceptance:** Confirm and Cancel behave correctly; both entry points invoke one safe logout path, show progress and errors, reject double taps, do not leave authenticated finance visible; re-login with same generated password; SMS consent persists only for the same owner, encrypted update-over-old-data, cold/warm foreground biometric and Android tests. Device acceptance **not yet verified**. Source regression in `test/m502_logout_paths_test.dart` is not a substitute for signed APK phone tests. Total now **20 tracked requirements**.


### 2026-11-06 — M503 corrective CI follow-up, Issue #424 / PR #402

Full Flutter QA on M502 exact head failed in three workflows (`Waffra Full Offline Finance and UI Regression`, `M160 Main Reconciliation and Backup Regression`, `M103 Same-SHA Whole-App Release Certification`), but with **two distinct source regressions**: `test/waffra_footer_notice_test.dart` and `test/waffra_directional_fab_receipt_corner_test.dart`, each finding **two SnackBar presenters where exactly one is allowed**. Root cause was a newly inserted root-only `ScaffoldMessenger.showSnackBar` in M502, duplicating Waffra's footer-aware presenter. M503 removes the extra UI presenter and routes sign-out progress/failure via the existing `snack` function using the Navigator context below MaterialApp; while Home/footer is mounted use its reserved footer notice, and while on a biometric/login page use the existing single `ScaffoldMessenger` fallback. Preserve session preflight, credential integrity, native SMS disable/suspend, all finance and SQLCipher protections. Clear the existing footer notice after successful sign-out, preventing a stale progress message on login. Regression in `test/m502_logout_paths_test.dart` now asserts the single presenter and both routes. **Await full exact-head CI and physical Android proof before marking Done; do not weaken/remove existing tests.**


## 2026-11-06 — M504: Weekly safe GitHub failed-run retention (separate CI operations request)

**Issue:** [#425](https://github.com/MahmoudMAnwar/waffra-app/issues/425). **Owner-approved behavior:** run weekly Sunday 02:19 UTC, delete at most 20 FAILED PR workflow runs older than 7 full days only when the PR is merged, same-repo/main-target, the same workflow has a newer SUCCESS on that same PR and branch, and the failed run has zero artifacts. Never delete main runs (including failures), successful/active runs, security/release/SQLCipher/migration/backup evidence, open/unmerged PR runs or candidates with missing metadata. Manual dispatch defaults to dry-run; only trusted main schedule/dispatch has actions:write. Independent of M453 cancellation. Docs: `docs/ci/M504_FAILED_RUN_RETENTION.md`. Implementation in dedicated CI PR; Node safety tests run offline. Actual scheduled deletion becomes active only after merge to main. No claims of backdated log recovery.


## 2026-11-06 — M506: Nine confirmed APK regressions following merged PR #402

**Tracking source:** User's Android screenshot set and reproduction report 2026-11-06; **fix branch:** `fix/m506-nine-apk-regressions`; **implementation PR:** pending creation (do not claim fixed until code + CI + device proof).

| ID | Issue | Confirmed symptom | Acceptance target | Status |
|---|---|---|---|---|
| M506-01 | [#427](https://github.com/MahmoudMAnwar/waffra-app/issues/427) | App-wide ~2s latency / jank (cold start, refresh, save, footer, +) | Performance profiling; smooth UX; Android validation | Reported / not verified fixed |
| M506-02 | [#428](https://github.com/MahmoudMAnwar/waffra-app/issues/428) | SMS review + receipt save fails; financial write rollback | Atomic receipt+transaction, error tracing, no duplicate charge | Reported / not verified fixed |
| M506-03 | [#429](https://github.com/MahmoudMAnwar/waffra-app/issues/429) | Confirmed SMS expense does not update learned keyword rules | Post-commit idempotent, safe income/expense learner | Reported / not verified fixed |
| M506-04 | [#430](https://github.com/MahmoudMAnwar/waffra-app/issues/430) | First SMS sender not preselected; original SMS shown twice | Sender-to-bank prefill; SMS once; notes not prefilled | Reported / not verified fixed |
| M506-05 | [#431](https://github.com/MahmoudMAnwar/waffra-app/issues/431) | SMS text in transaction notes and confusing encrypted source warning | Separate user notes/source protected SMS; clean details UI | Reported / not verified fixed |
| M506-06 | [#432](https://github.com/MahmoudMAnwar/waffra-app/issues/432) | Missing recent SMS senders and stale scanned count | Scan since install-month 1st; incremental rescans; true refreshed counts | Reported / not verified fixed |
| M506-07 | [#433](https://github.com/MahmoudMAnwar/waffra-app/issues/433) | Destination bank selection missing and no transfer date | Independent bank/account selectors and historical date | Reported / not verified fixed |
| M506-08 | [#434](https://github.com/MahmoudMAnwar/waffra-app/issues/434) | Two-leg transfer rejects valid accounts as changed | Reconcile current accounts and atomic cross-account transfer | Reported / not verified fixed |
| M506-09 | [#435](https://github.com/MahmoudMAnwar/waffra-app/issues/435) | Logout broken in account page and fingerprint lock | Unified safe logout preserving credentials/encrypted data | Reported / not verified fixed |

### Approved message ownership and privacy contract
- Imported/read bank SMS is shown **once** during review in a read-only original-message section. The freeform **Notes** field is for **user-entered notes only** and begins empty; do not copy raw SMS into Notes. The original may be retained in the existing encrypted, separately typed SMS provenance store subject to existing consent; never weaken encryption or discard source evidence just to hide a UI message.
- After saving, transaction details show notes only if provided. An optional read-only original-message expander appears when source is accessible. Never surface implementation text such as “encrypted source not available”; do not falsely claim original source is present. Safely handle old transactions with legacy SMS-in-notes without deleting genuine notes.
- First-selection sender-to-provider matching uses trusted normalized aliases, not fuzzy guesses. User still selects/creates associated financial account; financial account IDs never inferred solely from provider/sender.
- Avoid regressions in money accounting: two-sided transfer only, zero budget effect, real snapshot validation; no forced retry bypass and no orphan receipts/duplicate SMS writes.

### Gate
Each issue requires linked source changes, exact-head CI, tests and real Android confirmation (new installation + update over existing data when applicable). No issue can be marked Done solely from PR creation or green unit tests; no deployment to the wife's existing-data device before backed-up upgrade QA.

### M506 current code checkpoint — 2026-11-06
- Candidate implemented in #436: verified reviewed-SMS receipt transaction, post-commit keyword learning, trusted first sender bank preselect, single SMS original and optional personal notes, scanned count and Arabic sender recognition, bank/provider choices and historical transfer date, fresh verified account witness, and guarded sign-out recovery for MISSING local credential with explicit new password + device fingerprint.
- **Not accepted:** no user device APK verification yet. Performance jank (#427) needs release-mode tracing and tuning. Logout (#435) must also be tested for missing, corrupted and different-owner verifier states; corrupted/mismatched values must never be overwritten or silently signed out. Source/schema integration tests and all CI still required.
- GitHub exact-head test results and Android fresh-install/update acceptance determine whether any of these can be marked Done. Preserve user data and encrypted SMS/receipt vault.


### M506-01 splash partial improvement (2026-11-06)
- In draft PR #436, the unconditional 3000ms intro minimum was reduced to 1750ms and the splash animation to 1650ms. Added a Flutter widget test to catch an accidental return to a three-second animation; bounded code scope and release note have been recorded.
- **Status: Partial code change / latest-head CI and device verification pending.** The startup loading/biometric critical path and all remaining footer, +, refresh, save and animation jank require Android profile traces, root cause correction, and physical test before issue #427 can be closed.


## 2026-11-06 — M507: SMS analyzed prefill + continuous review-only learning (same draft PR #436)

| ID | Issue | Requirement | State |
|---|---|---|---|
| M507-01 | [#437](https://github.com/MahmoudMAnwar/waffra-app/issues/437) | Screenshot-proven SMS "شحن الجوال / مبلغ:276 ريال / إلى:**8308 / المنتج:سوا فليكس 240 / في:05-11-2026 19:07" must detect **276 SAR** as the transaction amount, correctly recognize outgoing mobile top-up, prefill title and matching active main/subcategory; never confuse card suffix, product plan, or date with money | **Code ready / exact-head CI and Android QA pending** |
| M507-02 | [#438](https://github.com/MahmoudMAnwar/waffra-app/issues/438) | After a **successfully verified** SMS/manual income/expense save, update reusable non-posting keywords and immediately reclassify still-pending/new incoming SMS. Next reviewed message prefilled with supported amount, income/expense, title and category/subcategory. Never auto-record money; user confirms real money account and can edit all suggested values | **Code ready / exact-head CI and Android QA pending** |

**Acceptance:** isolate money parser from unrelated numbers and foreign currency, preserve protected original and user notes, use active saved child category or require explicit selection, do not learn on failed/duplicate save, do not discard pending SMS or user drafts, no sensitive keyword training, idempotent review refresh on a successful classification update. Unit/widget coverage for exact screenshot fixture and next SMS reclassification. Phone QA and exact-head CI mandatory before Done.

### M507 committed code checkpoint
- Source: `lib/main.dart`, `lib/waffra_bank_sms_facts.dart`, and `lib/waffra_sms_local_rules.dart`. Bank operation parser now recognizes a mobile top-up, reads verified explicit SAR and picks active mobile category; native SMS review and direct reviewed-SMS editor use latest local rule suggestions.
- After a confirmed bank SMS or manual finance save, the encrypted review queue is re-read and reclassified with owner-scoped local rules; follow-on review sheets also re-read rules before each message. No posting is allowed from classification alone.
- Test: `test/m507_sms_amount_and_continuous_review_test.dart` with exact screenshot, Arabic-Indic amount, card/product mismatch negatives and later similar SMS; source-level acceptance checks added. 
- CI and physical Android QA remain OPEN; the code candidate must not be represented as production-complete until real-device confirmation.


## 2026-11-06 — M508: Large Saudi bilingual default rules for bank SMS

- **Issue [#439](https://github.com/MahmoudMAnwar/waffra-app/issues/439)**, target **Draft PR [#436](https://github.com/MahmoudMAnwar/waffra-app/pull/436)**. User explicitly requested the broadest practical Arabic+English built-in library across *دخل / مصروف / تحويل / مستبعدة*, researched on public web and bundled on fresh + existing installations.
- **Research baseline:** SAMA bank notification fields, Saudi banks' alerts descriptions, CST anti-fraud guidance; public apps are taxonomy references only. Every template/keyword must be independently curated, not a copy of private banking messages, account details or third-party licensed catalogs.
- **Built-in rule safety:** no finance posting, no account inference, immutable bundled seeds, user-specific learned rules retained independently, active existing category/leaf only. Direction must be independently verified; transfer is NOT routine income or expense; excluded candidates must NOT auto-ack confirmed money. OTP/fraud/failed notices and marketing are no-finance candidates. Ambiguous signals require review.
- **Done criteria:** bounded code changes, locale-specific tests for all four buckets, conflicting merchants & financial notifications, release notes, source-reference methodology, exact-head CI and Android profile/new+update tests. **Status: Recorded; not accepted.**


## 2026-11-06 — M509: All-sender Saudi financial SMS discovery + lifetime committed-message exclusion

- **Issue [#440](https://github.com/MahmoudMAnwar/waffra-app/issues/440)**, same **Draft PR [#436](https://github.com/MahmoudMAnwar/waffra-app/pull/436)**.
- **Requested:** Scan incoming Android SMS from **all senders** (not only bank-branded) from the original installation month's first day and suggest financial income/expense from M508 Arabic/English seed catalog. Existing SMS still need independent debit/credit amount/direction evidence; don't mistake ordinary personal, OTP, ads, declines, credit settlement or transfer as confirmed money.
- **Rescan:** explicit user "إعادة الفحص" must revisit earlier skipped inbox rows when bundled classification expands; native scanning remains paged, background off Android UI thread and queue-limited.
- **Permanent one-time confirmed SMS:** when user saves reviewed SMS to encrypted verified ledger successfully, remember a privacy-safe sender/body/timestamp fingerprint, bound to the verified owner. Later historical rescans never present it again; keep existing dedupe of ledger SMS hashes as defense in depth. Failure/abort must not consume SMS.
- **No regression:** finance/account bindings, biometric/SQLCipher, owner lifecycle, merchant corrections, transfer review and user learned rules retained; no default autoPost, no raw SMS copied to new stores.
- **Done criterion:** precise discovery/committed replay and restore tests, CI exact HEAD, real Android new install + in-place upgrade checks. **Status: tracked; not yet verified.**


## 2026-11-06 — M510 CRITICAL: Restore first-install authentication choice

- **Issue [#441](https://github.com/MahmoudMAnwar/waffra-app/issues/441)**, same **Draft PR [#436](https://github.com/MahmoudMAnwar/waffra-app/pull/436)**. User explicitly objected to unapproved removal of initial **إنشاء حساب / تسجيل الدخول** choice page.
- **Current regression found in code:** `LoginScreen._freshSignup` bypasses the choice and directly instantiates `ProfileForm`; pre-existing branded `IntroScreen` is no longer reached. No user permission to remove it. This fix restores the explicit choice and preserves subsequent one-page registration.
- **Flow:** truly fresh install → approved branded choice → **إنشاء حساب** gives single registration form; Back returns to choice. **تسجيل الدخول** gives existing login form; Back returns to choice. Returning users and existing data/update-over-old should continue without a newly forced chooser; biometrics, account persistence, SQLCipher remain unchanged.
- **CI/test acceptance:** widget test proves both CTA labels/click/navigation and no premature form; tests ensure existing login and avatar/password registration regression stays green. Real Android fresh install + existing-device upgrade confirmation required. **Status: Recorded, implementation pending.**


## 2026-11-07 — M511: Restore M177 encrypted SMS atomic-write CI witness

- **Issue [#442](https://github.com/MahmoudMAnwar/waffra-app/issues/442)**, implementation in **Draft PR [#436](https://github.com/MahmoudMAnwar/waffra-app/pull/436)**. Failure witnessed on exact SHA `af95b958e5201414f0b5c51f5dd2193284e5e57c`, [encrypted storage smoke run 42293249031](https://github.com/MahmoudMAnwar/waffra-app/actions/runs/42293249031).
- **Root cause:** M177 source witness still requires inline `records:[Map<String,Object?>.from(result.toJson())]`; M506's verified SMS receipt writer now deliberately stores the sanitized `smsRecord` variable (`receiptPath=null`), stages receipt bytes, and submits records + hash atomically to verified finance authority. Retaining the former exact formatting would regress correct receipt handling.
- **Acceptance:** update only the stale M177 test assertions to recognize the authoritative atomic path; verify sanitization, receipt-byte handoff, same-source SHA dedupe and absence of legacy bypass. Targeted test and latest-HEAD full CI must pass; do not bypass SQLCipher, change application money behavior, or mark Android device testing complete.
- **Status:** Issue recorded; CI test correction in progress, exact-head gates pending.


## 2026-11-07 — M512: Full Flutter suite regression reconciliation (#443)

- **Source:** [Issue #443](https://github.com/MahmoudMAnwar/waffra-app/issues/443), [Draft PR #436](https://github.com/MahmoudMAnwar/waffra-app/pull/436), baseline exact SHA `4da8f49d2ca82268267e8d6af71550c7077efa80`. Four failed workflow jobs (M282, Full Offline, M160, M103) share **nine** individual failing Flutter tests.
- **Guardrails:** no financial/data/auth behavior change to coerce tests. Reconcile stale source assertions against verified M506/M507/M508/M510 implementation while preserving secure atomic SMS+receipts, first-launch two-choice screen, one-page registration, verified account selection, no ledger auto-post, never-guess account IDs, independently biometric-gated logout recovery, safe keyword library.
- **Nine failures:** M473 first SMS learning mistaken for manual learning; M507 empty optional accountId sentinel; M402 reviewed transfer provider catalog selector; M463 old direct-signup expectation conflicts with M510 chooser; M510 first welcome choice has duplicated decorative text and conditional gender-chip key; M506 authority forwards receipt bytes via `manualReceiptImages` and logout preflights an already-ready verifier before new recovery; M508 regex accidentally matches every keyword using quantified backslash. This is a **test-contract correction**, not blanket test bypass.
- **Acceptance:** exact M385 bounded manifest, regression assertions for current secure behavior, targeted nine Dart tests, all latest-SHA full CI workflows (including M282/Full Offline/M160/M103), Android fresh/install-over-existing-device validation prior to release. **Status: recorded; code and latest-head CI pending.**


### Quality audit initiative — Issue #454 (2026-11-07)
- **Requested:** whole-app audit for duplicated functions, inconsistent implementations, divergent manual/SMS/recurring/transfer finance writes, login/logout/biometric paths, SMS rules, budgets, backup/restore, UI error handling, and CI guard overlap.
- **Tracking:** https://github.com/MahmoudMAnwar/waffra-app/issues/454
- **State:** documented / pending audit. No code refactor or regression-test success claimed.
- **Execution:** inventory and root-cause matrix first, targeted scoped PRs with regression tests next; protect existing SQLCipher data and upgrade paths; require CI and device acceptance before merge.


## M525 — Budget sheet spending precomputation (2026-11-07; Issue #463 / parent #454)

- **Owner request:** begin implementing source-audited app-wide tap, dropdown and animation smoothness improvements; preserve finance and encrypted device data.
- **First scoped slice F-454-P02:** opening / filtering / sorting the budget directory repeatedly calls `waffraNamedBudgetSpent(entries,categories,b,now)` within the sort comparator and once per row, potentially traversing the full ledger multiple times per rebuild.
- **Approved work candidate:** read-only local `spentByBudgetId` calculated once per saved budget during a panel rebuild; reuse the same value in comparator and tile, without changing budget calculation, dates, user search, status, account scope, finance writes, sources, SQLCipher or UI text. Regression covers one calculation per budget in source and deterministic sorting with substantial data.
- **Implementation:** isolated Draft PR from main, linked to #463. Declare exact file/anchor authorization in M385 before coding. Run targeted Flutter tests and latest SHA CI and profile on physical Android before claiming smoothness measured or Done.
- **Status:** Code + three source regressions committed in M525 branch; exact-head CI and real-device latency profiles pending, no measured FPS/latency improvement claimed.
- **Implementation files:** `lib/waffra_budget_directory.part.dart`, `test/m525_budget_sheet_spend_cache_test.dart`; PR link to be attached after opening.
- **Follow-ups:** F-454-P01 and P03–P08 remain tracked in #454; do not mark all eight resolved by this slice.
