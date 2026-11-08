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

## Verified PR merge / QA checkpoint — 2026-11-07

- PR [#395](https://github.com/MahmoudMAnwar/waffra-app/pull/395) is **merged into main**. The historical [32-item tracker](qa/WAFFRA_32_NEW_CHANGES_M470_TRACKER.md) has all 32 requirements recorded with code evidence, while #3, #11, #20, #23 and #32 were expressly marked **partial at that checkpoint**. Merging the PR is not proof of physical-Android acceptance; later PRs may improve these items.
- PR [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) is **merged into main**. The 19 requirements indexed below all have source evidence but must NOT be marked Done solely because the PR merged. The historical row descriptions explicitly retain outstanding QA.
- PR [#436](https://github.com/MahmoudMAnwar/waffra-app/pull/436) is **merged into main** with M506 fixes; subsequent real APK reports found further defects and gave rise to #445.
- PR [#445](https://github.com/MahmoudMAnwar/waffra-app/pull/445) remains **Draft**. M514–M518 and M520 have code changes; exact-head Flutter / Android CI and physical-device acceptance are unverified. M519 (#456) is **open / implementation incomplete**, owing to legacy SQLCipher SMS receipt compatibility.
- M520 (#457): the malformed/duplicated Flutter SMS bridge was restored from merged-main baseline with M514, M516 and M517 APIs each inserted exactly once. Source test m520_auto_sms_bridge_integrity_test.dart was added. **Code ready / CI pending, not Done.**

## Requirements index

| ID | Requirement | GitHub Issue | Implementation PR | Status | Code and test evidence |
|---|---|---|---|---|---|
| WAFFRA-NEW-001 | Home balance card: replace top bank/account heading with its account dropdown; remove floating lower dropdown; show full long names without truncation and avoid overlaps | [#401](https://github.com/MahmoudMAnwar/waffra-app/issues/401) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress** | M476 header moved and wraps full account name; M495 narrow-screen 320px Flutter widget test added. CI/Android rotation checks pending |

| WAFFRA-NEW-002 | SMS review → entry: prefill title, amount, type, main/subcategory | [#403](https://github.com/MahmoudMAnwar/waffra-app/issues/403) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M485 + analyzer correction: SAR source/direction/title/category/date prefill and user correction remain; four unnecessary null-safe analyzer warnings corrected. Exact-head Flutter analyzer/Android QA pending |
| WAFFRA-NEW-003 | Preserve SMS source and protected original instead of mislabeling manual | [#404](https://github.com/MahmoudMAnwar/waffra-app/issues/404) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M485/M494: SMS correction preserves original bank source/hash and human-reviewed provenance. Reviewed SMS body is read-only; parsed amount/title/category stay editable. Android/restore QA pending |
| WAFFRA-NEW-004 | Preselect new financial-account institution from the sender | [#405](https://github.com/MahmoudMAnwar/waffra-app/issues/405) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Existing partial code / QA pending** | M494: nested provider/child Add opens a user-confirmed typed account form directly, preselecting verified known bank group. New account is re-read from SQLCipher before linking; sender impersonation/Android QA pending |
| WAFFRA-NEW-005 | Allow adding custom account subtype, not only listed presets | [#406](https://github.com/MahmoudMAnwar/waffra-app/issues/406) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M487/M497: user adds and reuses bank/wallet custom subtype, persists encrypted versioned display metadata and shows it beneath the created account name in My Accounts; canonical kind and balances unchanged. Tests: test/m487_custom_subtype_dialog_test.dart and test/storage/m487_custom_account_subtype_test.dart. Exact-head CI, verified backup/restore and Android QA pending |
| WAFFRA-NEW-006 | Prepopulate verified masked last-four in child account creation | [#407](https://github.com/MahmoudMAnwar/waffra-app/issues/407) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M483 + M496: bank SMS first-account and inline child-account forms propose editable four digits only when recognized reviewed sender matches selected bank and trusted SAR direction picks source for expense/destination for income. Widget+source tests added; Android transfer/nested QA pending |
| WAFFRA-NEW-007 | Reuse trusted sender and last-four to select child account next time | [#408](https://github.com/MahmoudMAnwar/waffra-app/issues/408) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Existing partial code / QA pending** | M493: two-confirmation account learning now rejects active accounts outside sender's verified same-bank group even if suffix matches. Unit tests cover different banks, two same-bank accounts, stale account, conflicting selection. Encrypted restart QA pending |
| WAFFRA-NEW-008 | Keep full readable original SMS accessible while reviewing and editing | [#409](https://github.com/MahmoudMAnwar/waffra-app/issues/409) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M484 original selectable in native review; M494 read-only original SMS expandable inside entry editor, with received source immutable and pending/OTP preview hidden. Test source assertions added; Android/restore QA pending |
| WAFFRA-NEW-009 | Back navigates exactly one step, preserves SMS draft/context | [#410](https://github.com/MahmoudMAnwar/waffra-app/issues/410) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M486 + M492: sender route retained underneath editor and unfinished SMS title/amount/categories/budget/account/date restored by a bounded in-memory hash-keyed draft, purged on confirmed commit. Regression source test added; Android Back/resume QA pending |
| WAFFRA-NEW-010 | Remove successfully posted SMS from pending; dedupe and rollback | [#411](https://github.com/MahmoudMAnwar/waffra-app/issues/411) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M484: native pending item removed only after verified SMS hash and successful native acknowledge, with existing transfer idempotency. M490: manual-correction path now visibly warns on failed native acknowledgement while retaining the pending SMS; test/m486_sms_back_navigation_source_test.dart covers source contract. Retry/rollback Android QA pending |

| WAFFRA-NEW-011 | Reuse the already-confirmed bank + child account selection on submit; no second account modal | [#412](https://github.com/MahmoudMAnwar/waffra-app/issues/412) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress** | M475 explicit account selection bypass with fresh verified witness, plus M495 guard test for selected/newly created account. CI/Android pending |

| WAFFRA-NEW-012 | Learn reusable safe description keywords after confirmed manual **and** SMS income/expense, merge into same review-only rules without assigning bank accounts | [#413](https://github.com/MahmoudMAnwar/waffra-app/issues/413) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M473 manual + SMS keyword learning source and parity test committed; latest CI and Android still pending |

| WAFFRA-NEW-013 | Account rename dialog shows persisted last-four suffix and allows user to correct it, preserving balances and verified SMS account mappings | [#414](https://github.com/MahmoudMAnwar/waffra-app/issues/414) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M481 editable name + saved last-four UI and one witnessed SQLCipher writer, storage QA test m481_saved_bank_suffix_edit_test.dart; Android pending |
| WAFFRA-NEW-014 | SMS bank account confirmation shows selected child's already-saved last-four digits; refreshed when account selection or suffix changes | [#415](https://github.com/MahmoudMAnwar/waffra-app/issues/415) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M481 selected bank loads saved suffix from verified SQLCipher and blocks submit on unverified reads; Android pending |

| WAFFRA-NEW-015 | In manual and SMS-derived transaction entry, provider is selected first; child-account dropdown is dimmed until provider is confirmed; both lists include their own inline add option; remove duplicate bottom Account button and keep date | [#416](https://github.com/MahmoudMAnwar/waffra-app/issues/416) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M477/M482/M488/M494 + M499: manual income/expense, both source and destination of manual transfer, SMS-reviewed transfer and My Accounts composer all have provider-first/child-second in-dropdown creation with verified SQLCipher account reread; cancel preserves draft. CI, Android, RTL and encrypted restore QA pending |

| WAFFRA-NEW-016 | Second SMS exclusion popup must offer **العودة** to reconsider sender exclusion and return to prior selection without finalizing sender block; later unexclude via excluded list | [#417](https://github.com/MahmoudMAnwar/waffra-app/issues/417) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress** | M479/M494 sender Back preserves selection before native acknowledgment, failed partial batch now keeps review sheet mounted with remaining selections; multi-sender/device QA pending |
| WAFFRA-NEW-017 | After removing bottom Account button, date expands full row; when optional budget control is displayed, date and budget split row equally 50/50 | [#418](https://github.com/MahmoudMAnwar/waffra-app/issues/418) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress** | M478 date full width without budget and equal date/budget halves when budget exists; M495 source regression added. Small-device layout QA pending |

| WAFFRA-NEW-018 | App-wide lag/jank: biometric first launch, pull-to-refresh, + sheet, transaction save, footer navigation; trace root causes, optimize, benchmark physical Android without compromising financial/security integrity | [#419](https://github.com/MahmoudMAnwar/waffra-app/issues/419) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **In progress / CI pending** | M474 smooth FAB/refresh/footer and M486 deferred noncritical post-biometric I/O; M495 guard tests added. Real Android frame timing, cold-launch, scroll and loading animation traces still required |

| WAFFRA-NEW-019 | Details → Edit for an existing historical income/expense must show the same provider-first/child-second verified account picker as Add, and allow confirmed retroactive linking without duplicate posting; preserve prior provenance and old-device migration safety | [#420](https://github.com/MahmoudMAnwar/waffra-app/issues/420) | [#402](https://github.com/MahmoudMAnwar/waffra-app/pull/402) — merged into main (Android acceptance pending) | **Code ready / CI pending** | M500: `lib/main.dart` existing edit + consent; `lib/storage/waffra_account_context_repository.dart` bounded association read; `lib/storage/waffra_verified_accounts_api.dart` witnessed reader; `test/storage/m500_historical_entry_edit_account_link_test.dart` and M495 regression. Legacy-to-SQLCipher migration and Android APK acceptance independent and still pending |

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


## 2026-11-07 — M513: One Yes/No logout confirmation, no surprise credential repair

- **Reproduced user screenshots:** after account creation and attempted sign-out/login, a second full-screen modal **إصلاح بيانات الدخول قبل تسجيل الخروج** asks for a new password and biometric recovery. User explicitly requests a single **هل أنت متأكد من تسجيل الخروج؟** with **نعم / لا**, nothing further in normal sign-out. [Issue #444](https://github.com/MahmoudMAnwar/waffra-app/issues/444); implementation PR to follow.
- **Reproduced source cause:** `WaffraApp.logout()` invokes `_repairMissingLocalCredential` when a phone-account secure verifier is missing; the Home entry already confirms, while the mandatory/idle biometric sign-out entry points do not.
- **Approved UX:** Home / mandatory biometric / idle-locked logout all present one visible Yes/No choice, cancel does not mutate authentication, Yes invokes one shared verified sign-out; never ask to create or confirm a password as a consequence of pressing Sign out.
- **Non-negotiable security:** a truly missing/malformed/wrong-owner password verifier cannot be silently replaced or bypassed. In that edge state, fail closed with concise non-sensitive feedback, retaining the active session and financial/SQLCipher data; do not pretend the app safely signed out and then strand the user's account. Separate explicit, biometric-gated account recovery (if needed) is not part of normal logout. Verify existing password can sign in again.
- **Root hardening:** validate that a new phone profile is backed by a same-phone OS-protected verifier before committing its registration/profile; never overwrite credentials or change registered phone silently.
- **Acceptance:** dedicated Yes/No widget tests for Home, pending-OS-biometric and idle-gate; missing-verifier case cannot invoke signOut or a password dialog; already-ready verifier permits safe sign-out and original password login; M385 approved exact files/sections, all latest-head CI, signed Android new registration + in-place-update device tests. No user data deletion. **Status: issue documented, implementation and device verification in progress.**

- **CI update 2026-11-07:** M429 combined test uncovered M424 stale assertion that Sign out instantly runs without the newly required Yes/No choice. Preserve all previous biometric checks; update only the one confirmation test, record its exact M385 boundary and rerun exact-head suite. No production code change authorized by this test-only reconciliation.

## M514 — Android SMS review / rescan / exclusion / attachment regressions (2026-11-07, PR #445)

User approved implementation on **#445**, with six independently numbered Issues. All statuses below are **OPEN / not Android-verified**, regardless of any source-level fixes. Preserve existing M513 sign-out and no data-destructive storage changes. Evidence: eight Android screenshots reported on 2026-11-07.

| ID / issue | Accepted behavior / exact regression to prevent | Code | CI | Device |
| --- | --- | --- | --- | --- |
| M514-01 / #446 | Rescan numbers represent **this button invocation** (checked, new, pending, incomplete/complete), not cumulative 2000 since install; bounded cursor pages resume and never repeatedly claim completion | Source candidate committed | Awaiting latest-head gates | Device unverified |
| M514-02 / #447 | Replace user-facing "غامضة" with "تحتاج مراجعة" / "عملية تحتاج مراجعة" across Home + sender review, without pretending a safe financial classification | Source candidate committed | Awaiting latest-head gates | Device unverified |
| M514-03 / #448 | Single and bulk excluded SMS retain owner-encrypted per-message exclusion identifiers and safe learned rules, re-apply on refresh/rescan and after relaunch, keep explicit sender block separate/reversible; exclusions never poison ledger-committed hashes | Source candidate committed | Awaiting latest-head gates | Device unverified |
| M514-04 / #449 | Incoming transfer credits vs outgoing transfer vs user-confirmed *own account to own account* distinguished with SMS fact fixtures; tapping review offers a working edit flow or actionable reason, not silence or auto posting | Source candidate committed | Awaiting latest-head gates | Device unverified |
| M514-05 / #450 | Creating first account from reviewed SMS prefills exactly the correct masked 4 source/destination digits when unambiguous, editable and user-confirmed, without assuming ownership | Source candidate committed | Awaiting latest-head gates | Device unverified |
| M514-06 / #451 | SMS income/expense with encrypted receipt uses the same verified atomic writer guarantees as working manual with receipt; on failure rollback receipt/finance, no duplicates and no lost existing data | Source candidate committed | Awaiting latest-head gates | Device unverified |

**Required regression evidence:** >2000 historical SMS; two consecutive rescan taps; zero/partial/capacity-limit/error; excluded single + multi-select then rescans and reboot; learned exclusion UI counts; incoming/outgoing AlinmaPay example and no false own-account transfer; CTA click with 0/1/2 accounts and fee-only/missing-amount; correct four-digit masked origin on account form; SMS with/without a receipt and manual with/without a receipt; repeated retries and ledger hashes; clean signup → logout (Yes/No) → login with same password; no destructive migration. No 'Done' until latest-head CI and real signed Android evidence.

**Implementation policy:** Record changed paths and anchored function/file boundaries in `docs/qa/approved_change_scope.json`; preserve M385 enforcement and separate native exclusion from confirmed finance fingerprint. M514 must not broaden permissions, access unconsented messages, or silently auto-import as transactions.

**Source commits, not acceptance:** M514 native excluded fingerprint shards + review ACK separation; per-click count and Arabic labels; parser incoming precedence; existing 0/1-account transfer editor; masked source-suffix creation; first encrypted receipt for existing SMS/manual entry in verified SQLCipher; integration tests `test/m514_sms_review_regressions_test.dart` and `test/storage/m514_sms_receipt_regression_test.dart`. The M452 legacy static guard was updated to test the new per-tap counter. As of documentation, latest exact-HEAD Flutter/Android CI and physical device reproduction have NOT established acceptance. Preserve a backed-up copy of the spouse's installation.

## M515 — Budget linked to account shows false financial save failure (2026-11-07, Issue #452, PR #445)

Android screenshot: owner creates a SAR 1,000 standalone monthly budget and links a selected verified account. Home immediately renders the 1,000 budget but snackbar says «لم يتم تأكيد الحفظ. أعدنا تحميل بياناتك المالية بشكل آمن.» The user must not retry blindly or lose/duplicate linked budgets.

**Reproduced code fault:** `chooseBudgetCategory()` adds `WaffraNamedBudget` into `namedBudgets` before verified commit and calls `_persistModuleOrReload(challengeAndBudgetUpdate)`. `persist()` captures `waffra_named_budgets_v1`, but `WaffraVerifiedFinanceAuthority.saveCaptured()` excludes that key from the encrypted scalar-budget route allowlist. A verified new budget therefore fails closed despite optimistic UI. `WaffraHomeTransactionCapture.narrowVerifiedModuleEdit()` also lacks a budget route, allowing missing optional Home defaults to enter the capture. Scope only the budget key and existing budget route keys; check witness consistency for unrelated modules and reject all unrelated mutations. Follow the same verified SQLCipher save and read-back, no legacy finance bypass or fake success. Verify unchanged old budgets, account ownership/assignment, cold reopen, duplicate retry and failure rollback. Ensure a zero-budgets fresh encrypted vault can write one budget without unrelated optional defaults. All verification pending until exact-head CI and real APK.

## M516 — Confirmed SMS internal transfer returns after rescans (2026-11-07, Issue #455, PR #445)

**Audit finding (source-confirmed):** `_reviewSmsAccountTransfer` in `lib/main.dart` currently acknowledges the native queue using `WaffraAutoSms.acknowledge([id])` only after `api.transfer(...)`. This ACK is transient, but `WaffraAutoSmsStore.offer()` on historical rescan only consults durable SQL-finance commit fingerprints and excluded-message fingerprints. The exact **completed transfer** therefore becomes pending again. Its `requestId` is currently derived from `bankSmsHash(body)`, so two different SMS with the same body and different native timestamps/senders collide unnecessarily.

**Acceptance:** Derive idempotent transfer request ID from the immutable 64-character native per-SMS fingerprint (which includes sender, body and receivedAt), never a body-only hash. After `api.transfer` succeeds, atomically remove the queued SMS and store its fingerprint in a **dedicated AES-GCM owner-scoped completed-transfer marker**. `offer()` must skip completed transfers after rescan, while explicit user-excluded items remain distinguishable and finance hashes retain their existing meaning. A native ACK failure must remain retryable without duplicate debit because of the stable transfer ID. Owner switch clears all completed-transfer markers; never clear SQLCipher financial records. Add source and targeted regression checks, run latest-head CI, Android rescan and two-account device tests; status is **In progress / CI and Android QA pending**.


## M517 — Individual excluded SMS missing in Excluded UI (2026-11-07, Issue #448, PR #445)

**Verified source mismatch:** `native/WaffraAutoSmsStore.excludeMessages` saves encrypted per-message fingerprints separately from sender exclusions. `lib/main.dart::_openExcludedSenders` fetches *only* whole excluded senders and therefore can show an empty excluded list even after a successful bulk/single message exclusion. This is misleading and prevents reviewing/restoring specific excluded items.

**Approved in the ongoing full audit:** Add a native AES-GCM, current-owner-bound list of excluded message identities (fingerprint, sender name, received timestamp only; no full body or bank digits). Existing excluded SHA-256 records are retained, listed by masked ID if pre-upgrade metadata is absent. Show separate senders and individual messages and their counts; give explicit per-message Restore (removes only that exclusion, rescan required to review again), without touching financial-commit markers or transfer markers. Use one synchronous encrypted preferences commit for marker + bounded metadata on exclusion and restoration; verify accurate totals, absence on owner switch, malformed native data, and Android user flows before Done.

**Status:** In progress, exact-head Flutter/Android CI and physical-device acceptance pending.


## M518 — Live SMS and historical scan must agree on one fingerprint (2026-11-07, Issue #455)

**Audit source:** `WaffraAutoSmsReceiver` sends network `SmsMessage.timestampMillis` into SHA-256 message IDs, but `WaffraAutoSmsStore.importConsentMonth` uses inbox provider `date` (received time). Android provides `date_sent` separately; historical rescans may give the same SMS a different identity and defeat completion/exclusion markers. **Scope:** use positive inbox `date_sent` as the fingerprint timestamp where trustworthy; retain inbox `date` for chronology/UI/cursor. When sender timestamp is unavailable, fall back to received date without conflating unrelated same-body messages. Do not change financial ledger hashing or remove old markers. Regression checks plus Android device/OTP edge verification required. **Status:** source patch committed in #445 (M518), exact-head Flutter/Android CI and device QA pending.


## M519 — Body-only financial SMS hashes can suppress distinct legitimate messages (2026-11-07, Issue #456)

**Confirmed source-only risk, OPEN:** `bankSmsHash(raw)` in `lib/main.dart` hashes normalized body only. A distinct incoming SMS with identical text but different sender/timestamp is nonetheless deemed already committed by `_runAutoSmsRefresh()` and `_reviewAutoSmsCandidates()` and can be ACKed without owner review. The native queue has an independent full sender/body/timestamp fingerprint, now used for internal transfers after M516/M518. New financial-message hash contracts must distinguish distinct native messages while preserving old SQLCipher body-hash history, idempotent retries and manual SMS-paste behavior. **No finance hash/ledger mutation in this change** until safe migration and canonical receipt reconciliation are tested; do not mistake existing M516/M518 repairs for a complete fix. Include distinct messages/same body, same SMS rescan, source legacy, receipt and owner-isolation tests. Android QA and CI required.


## M520 — SMS bridge Dart syntax corruption blocks build (2026-11-07, Issue #457, PR #445)

**Audit-confirmed P0:** `lib/waffra_auto_sms.dart` on #445 has unterminated `RegExp(r'^[a-f0-9]{64}` strings, duplicated native bridge methods, and stray closing braces/`.hasMatch(...)` outside class scope after M516 and M517 edits. Merged `main` has a healthy baseline; preserve that baseline and add only the new M514/M516/M517 methods in canonical sequence. Each API must exist exactly once. Native exclusions and completed transfer ACK remain independent; reject malformed 64-hex IDs and native metadata, fail closed on absent Android bridge. Source-level test should prevent this exact regression. Do not touch any SQLCipher entries. **Status: Code ready / exact-head CI and APK pending** (M520 bridge reconstructed from merged main; Dart test added).


### Quality audit initiative — Issue #454 (2026-11-07)
- **Requested:** whole-app audit for duplicated functions, inconsistent implementations, divergent manual/SMS/recurring/transfer finance writes, login/logout/biometric paths, SMS rules, budgets, backup/restore, UI error handling, and CI guard overlap.
- **Tracking:** https://github.com/MahmoudMAnwar/waffra-app/issues/454
- **State:** documented / pending audit. No code refactor or regression-test success claimed.
- **Execution:** inventory and root-cause matrix first, targeted scoped PRs with regression tests next; protect existing SQLCipher data and upgrade paths; require CI and device acceptance before merge.


## M521 — Restore non-overlapping M385 exact-head edit scopes (2026-11-07, Issue #458, PR #445)

**Source/CI-confirmed:** latest PR #445 has Flutter CI failures in M174 `pinned-no-go-preflight` and combined Flutter at the unchanged source-authorization gate `scripts/qa/m385_approved_change_guard.py` reporting `Overlapping or reordered sections in lib/main.dart`. Existing approved scope JSON has duplicate/overlapping intervals for SMS processing functions in `lib/main.dart`, nested `acknowledge` bounds in `lib/waffra_auto_sms.dart`, duplicate blocks and an absent-on-main `excludeMessages` start in `native/WaffraAutoSmsStore.kt`, and an absent-on-main `excludeAutoBankSms` start in `native/WaffraMainActivity.kt`. **Allowed remediation:** adjust bounded scope metadata only, retain all strict comparison checks, cover changed sections with unique nonoverlapping valid anchors in both the current base and head. Do not weaken the authorization guard, financial writes, runtime source, or tests. Verify the normalized manifest against exact base/HEAD, then require CI and Android before acceptance. **Status:** Recorded, repair in progress; not yet CI passed.


## M522 — Update obsolete M417 queue-only ACK assertion (2026-11-07, Issue #459, PR #445)

**Exact-head CI regression confirmed:** the protected Python `test/qa/m417_sms_permission_acceptance_test.py::test_writes_only_from_existing_verified_sms_review` still expects legacy `await WaffraAutoSms.acknowledge([id])` in Home. M516 intentionally uses durable `acknowledgeCompletedTransfer([id])` after the verified SQLCipher two-sided transfer; finance income/expense uses `acknowledgeCommitted([id])` after a committed hash. The old ACK would permit requeued transfers after rescan. **Authorized narrow remediation:** update only the stale test assertion in this one test function, enforce distinct durable ACK paths and correct commit-before-ACK ordering, preserve all other permission/OTP/privacy/finance assertions, and add the exact test-function scope in the M385 manifest. No production code change, finance cutover, or weakening of negative guards. **Status:** recorded / source fix pending exact-head CI and Android QA.


## M523 — Fix four disposable SQLCipher budget QA fixture errors (2026-11-07, Issue #460, PR #445)

**Reproduced CI errors:** storage regression logged four failures on PR #445. Three M515 budget storage scenarios use `WaffraAccountsRepository.createAccount` before `WaffraAccountsSchema.install` in a disposable fresh-vault test, so they fail with `Accounts database has not been initialized` before testing account-linked budgets. One M461 positive-case budget capture presents a nonempty goal and due-record while the provided encrypted witness contains neither; the strict nonempty-unwitnessed guard correctly rejects it. **Remediation authorized:** modify test fixture only: initialize account schema after fresh-vault bootstrap and before account creation, and make the fresh-vault positive budget case explicitly have empty optional goals/recurring. Retain negative tests for changing unrelated finance, and do not weaken the production `narrowVerifiedModuleEdit` guard. Declare exact test-function bounded scopes in M385, run targeted and full exact-head CI. **Status:** recorded, implementation/CI pending.


## M524 — Reconcile 11 post-M516 Flutter regression failures (2026-11-07, Issue #462, PR #445)

**Evidence:** exact-head 9aa78f6 comprehensive Flutter CI runs report **2470 passing and 15 failing tests**; four failures have been investigated as isolated disposable M515/M461 storage fixture bugs in Issue #460/M523. The remaining eleven involve stale source assertions for queue-only `acknowledge` and body-only SMS transfer IDs, sender-only exclusion view, login/logout/locale presentation and verified account callbacks, plus one M514 incoming-credit sample. **Required behavior:** inspect each assertion against actual reviewed Kotlin/Dart financial behavior; correct obsolete test contracts with narrow scoped edits and stronger assertions protecting durable completed-transfer and finance hash anti-replay, SMS exclusions, owner verification and verification-before-post. Investigate any real parser/UI failure instead of editing its test to conceal it. Preserve full test-suite execution and fail-closed M385 guard. **Status:** 11 failures inventoried, root-cause/source review in progress; code/test fixes and exact-head CI pending.


## M521 — Resolve repeated PR #445 exact-head CI regressions (2026-11-07, Issue #461)

- **Confirmed common cause:** seven workflow checks share failing Flutter tests (15 cases in the complete test suite); do not count every workflow as a distinct product defect. The eighth reported failure requires fresh exact-head verification; Android encrypted database integration was running during initial triage.
- **Source regressions to fix:** outgoing bank transfer SMS `إيبان: **9288` must extract destination suffix without changing source/fee/kind; M515/M461 fresh SQLCipher budget fixture setup separately tracked under M523/#460.
- **Outdated assertions to reconcile without making tests vacuous:** source tests for `excludeMessages`, `acknowledgeCommitted`, `acknowledgeCompletedTransfer`, native encrypted owner-scoped fingerprint shards, unified excluded SMS list, explicit Yes/No logout and manual account creation must assert the actual protected flows rather than obsolete queue-only ACK or legacy dialog text. Never change financial commits, credential integrity, unconfirmed SMS handling or owner scope just to satisfy assertions.
- **Acceptance and status:** fix real parsing defects; keep negative and idempotency guards; require new PR head SHA, complete Dart/Flutter tests, Android compile, two-device signed APK QA, and ensure the PR remains Draft until verified. **OPEN — code/CI not yet accepted.**


## M525 — Budget sheet spending precomputation (2026-11-07; Issue #463 / parent #454)

- **Owner request:** begin implementing source-audited app-wide tap, dropdown and animation smoothness improvements; preserve finance and encrypted device data.
- **First scoped slice F-454-P02:** opening / filtering / sorting the budget directory repeatedly calls `waffraNamedBudgetSpent(entries,categories,b,now)` within the sort comparator and once per row, potentially traversing the full ledger multiple times per rebuild.
- **Approved work candidate:** read-only local `spentByBudgetId` calculated once per saved budget during a panel rebuild; reuse the same value in comparator and tile, without changing budget calculation, dates, user search, status, account scope, finance writes, sources, SQLCipher or UI text. Regression covers one calculation per budget in source and deterministic sorting with substantial data.
- **Implementation:** isolated Draft PR from main, linked to #463. Declare exact file/anchor authorization in M385 before coding. Run targeted Flutter tests and latest SHA CI and profile on physical Android before claiming smoothness measured or Done.
- **Status:** Code + three source regressions committed in M525 branch; exact-head CI and real-device latency profiles pending, no measured FPS/latency improvement claimed.
- **Implementation:** [Draft PR #464](https://github.com/MahmoudMAnwar/waffra-app/pull/464), source `lib/waffra_budget_directory.part.dart`, regression `test/m525_budget_sheet_spend_cache_test.dart`; M385 bounded anchor corrected after first exact-head gate found a whitespace mismatch. All latest-head CI/device checks remain pending.
- **Follow-ups:** F-454-P01 and P03–P08 remain tracked in #454; do not mark all eight resolved by this slice.


## M526 — Instant display of already-computed financial analysis (2026-11-07; Issue #465 / audit #454)

- **Owner requirement:** improve all buttons/dropdowns smoothness and remove avoidable tap-to-next-screen wait. First safe slice M525 covers budget-spend cache; M526 covers analysis result navigation.
- **Existing source behavior F-454-P05:** `showAiAnalysis()` computes local 90-day values, then presents an additional blurred progress dialog for `waffraMotion(1500)` before opening the already-built results route. The delay does not represent an ongoing asynchronous calculation.
- **Expected:** show verified local insights immediately after computation; preserve empty-state message, route dismiss/Back, data aggregation, charts, exports, all SQLCipher/finance authority and loading gates for unrelated operations. Remove only that artificial intermediate wait; test that the final results dialog still exists.
- **Implementation:** [Draft PR #466](https://github.com/MahmoudMAnwar/waffra-app/pull/466), exact M385 scoped function `showAiAnalysis`, regression `test/m526_instant_insights_route_test.dart`, and M449 reviewed notes after code edit. Android first-result-frame profile and exact-head CI required before acceptance. No blanket animation removal.
- **Status:** Code and two source regressions committed. Latest-head Flutter/Android CI and physical-device frame profiling still pending. No release or merge asserted. Remaining audit findings tracked by #454.


## M527 — Home account dropdown cold-open feedback (2026-11-07; #467, audit #454 F-454-P04)

- **Owner requirement:** further improve all button/dropdown tap smoothness, beyond M525 budget re-use and M526 instant precomputed insights.
- **Source defect candidate:** the Home account picker waits for a verified SQLCipher balance/context read before displaying any sheet on a cold cache, so the first tap can look unresponsive.
- **Proposed behavior:** present a lightweight modal immediately on cold cache, retain verified SQLCipher read before any account is selectable, replace loader with existing verified account sheet only after verification, otherwise show non-destructive retry guidance. Hot-cache opens the existing sheet directly. Selection and save/source guards unchanged.
- **Tracking:** [Issue #467](https://github.com/MahmoudMAnwar/waffra-app/issues/467), [Draft PR #468](https://github.com/MahmoudMAnwar/waffra-app/pull/468); code committed in lib/main.dart and 3 regressions in test/m527_home_account_picker_latency_test.dart, M385 bounded; latest-head CI and physical Android profiling pending.
- **Status:** requirement recorded first; code/CI/device not verified. Require Android profile timings and existing encrypted-data smoke test.


## M528 — Stable asynchronous settings snapshots (2026-11-07; Issue #469 / audit #454 F-454-P06)

- **Owner-approved improvement:** stop repeated storage/permission future creation caused by every unrelated My Account repaint while preserving correct switches and permission consent.
- **Identified:** profilePage builds three new futures to read Android SMS status, bank SMS cloud consent, and downloaded AI model status on every rebuild.
- **Expected:** per Home session read futures are reused through unrelated renders; explicit user toggles, reopening account/settings after another screen, and lifecycle re-entry invalidate status; model download/removal changes invalidate using existing revision counter. Never show stale permission/consent as authorized money or network access, skip biometric confirmation, or broaden SMS permissions.
- **Scope:** [Issue #469](https://github.com/MahmoudMAnwar/waffra-app/issues/469), [Draft PR #470](https://github.com/MahmoudMAnwar/waffra-app/pull/470), M385 bounded Home fields/profile plus entry/resume/AI removal, three tests in test/m528_settings_async_cache_regression_test.dart; exact-head CI and Android profile pending.
- **Status:** recorded before code; no acceptance or device timings claimed.


## M529 — Lightweight shared centered dropdown (2026-11-07; Issue #471, audit #454 F-454-P07)

- **Owner intent:** improve all buttons, dropdown openings and after-click animation smoothness while retaining approved blurred centered selectors and RTL/LTR.
- **Source candidate:** centered picker uses a full-screen sigma-6 blur and allocates a list of selected options each rebuild; neither is necessary for correctness.
- **Allowed narrow optimization:** preserve visible light blur in normal mode, remove expensive blur when device reduced animations is enabled, use one index search for selected value instead of where().toList(); preserve dialog geometry, list laziness, no-onChange-on-dismiss/back, selected item and account/finance checks.
- **Tracking:** [#471](https://github.com/MahmoudMAnwar/waffra-app/issues/471), [Draft PR #472](https://github.com/MahmoudMAnwar/waffra-app/pull/472), M385 bounded dropdown class, five Flutter source/widget tests for RTL/LTR selection and cancellation, M449 notes. Exact-head CI and Android performance profile pending.
- **Status:** requirement recorded before coding; no measured device smoothness or CI approval claimed.


## M530 — Immutable finance ledger snapshot off UI isolate (2026-11-07; issue #473, audit #454 P01 partial)

- **User request:** improve smoothness immediately after save/add/tap without sacrificing SQLCipher or immutable transaction data on existing devices.
- **Current code:** `persist()` freezes a full map of all immutable MoneyEntry rows by calling `toJson()` on the UI isolate before the save progress overlay draws; subsequent large jsonEncode is already offloaded.
- **Bounded behavior:** retain a List.unmodifiable snapshot of immutable final MoneyEntry references before the first await. Convert/encode large snapshots (existing 240-row boundary) off the UI isolate via compute, preserving byte-for-byte JSON, exact source/witness, save order, pending/failed finance no-double-write guarantees. Small histories retain original encodeRecords path.
- **Tests:** 5000 actual MoneyEntry objects for JSON bytes/order and optionals, source-level freeze-before-await and worker-before-verified-write, exact M468 regression update, M385 and M449. Require both clean and upgrade-over-existing data plus actual Android frame timelines; no blanket modification of financial routes.
- **Tracking:** [Issue #473](https://github.com/MahmoudMAnwar/waffra-app/issues/473), [Draft PR #474](https://github.com/MahmoudMAnwar/waffra-app/pull/474), M385 bounded money-entry serializer and persist method, updated original M468 source guard and 3 new 5000-row/immutable snapshot tests. Exact-head CI, Android FPS/first-frame metrics and existing-data acceptance pending.
- **Status:** code committed for P01's large-ledger segment only; not a measured complete fix.

## M531 — Unified seven-PR release candidate (2026-11-07; Issue #475)

Owner approved consolidating exact green source heads from PRs #445, #464, #466, #468, #470, #472, and #474 into one integration PR targeting `main`. Preserve all protected login, SMS, owner-bound SQLCipher finance, budget, and transfer behavior while combining six non-destructive responsiveness improvements. Shared `lib/main.dart`, requirements, change-scope manifest, and release notes must merge *additively* and cannot overwrite each other.

Acceptance: verify full changed-file union and immutable-outside-approved-section M385 guard; run complete Flutter, Android, QA, combined financial integrity and release-note checks on exact integrated head SHA; fix failures and merge only consolidated PR after green CI. Actual two-device fresh/upgrade encrypted-data acceptance and measured FPS profiling remain separate, unverified stages. Source Issue: https://github.com/MahmoudMAnwar/waffra-app/issues/475. Status: code assembly and combined CI in progress.

## M532 — Stable Android M274 emulator real UI QA (2026-11-07; Issue #477 / integrated PR #476)

- **Owner request:** fix the sole failure on integration PR #476 and merge to main only after comprehensive exact-head success.
- **Repeated evidence:** M274 Android real emulator test passes rapid footer taps, then Flutter Driver loses its VM service while checking balance-eye privacy. ADB emulator-5554 goes offline and emulator TCP port refuses connections, twice on source SHA `db96146c325d030129ae95d9c0c779d71a98c5a1`. No failed Flutter `Expected`/`Actual` assertions; host has ample free memory and disk.
- **Root-cause candidate:** runner uses deprecated graphics mode `-gpu swiftshader_indirect` on Android Emulator 37.2.13. Upstream Android emulator documentation supports the newer `-gpu software` automatic software renderer selector and deprecates `swiftshader_indirect` since 36.4.9; environment/graphics stability, not unverified application defects, is the first narrow fix candidate.
- **Approved scoped change:** ONLY `.github/workflows/m274-production-ui-golden.yml` Android emulator GPU option: use `-gpu software` while retaining API 35, 2-core/disposable emulator, actual Flutter engine tap test, full visual/golden widget tests and fail-closed behavior. Extend M385 strict protected workflow anchors, do not change or skip tests, SDK installation, authenticated finance code, biometric/SQLCipher data, or release conditions.
- **Acceptance:** exact integrated new SHA runs ALL 55 workflows; M274 Android emulator real tap suite actually passes and no skipped required real tests. If the emulator continues to die, root-cause another renderer/system issue instead of rerun forever. New release notes M449 must follow source changes. External physical-device profiling/old-data upgrade validation remains separate.
- **Tracking:** https://github.com/MahmoudMAnwar/waffra-app/issues/477. **Status:** recorded before code; new CI pending.

## M478 / M479 — Reliable local login/logout and minimal sign-in screen (2026-11-07)

- **M478 / Issue #478:** An authenticated Android session in the released APK cannot sign out: `main.dart logout()` rejects missing OS phone-verifier and no legacy hash. Existing session is not proof the original password exists. Never clear SQLCipher, account profile backups, native SMS owner binding, or invent a valid password. Ordinary login/logout uses verified local phone credentials and a single Yes/No sign-out. A genuinely absent verifier requires explicit device biometric authentication and protected credential read-back BEFORE sign-out; malformed, different-phone, and storage-error cases fail closed. In a missing-verifier recovery, the supplied password is a NEW locally verified password, not a claim to have recovered the original. Physical-device login again with the exact newly confirmed password is required; the existing password must remain unchanged when a valid verifier exists.
- **M479 / Issue #479:** Remove the lengthy no-local-account/restore-backup paragraph under the login heading. Replace the bottom "إنشاء حساب" button on the login form with "عودة" / "Back" to the two-choice `IntroScreen`. This Back action must work both on clean-first-run and existing signed-out devices. Retain separate Create Account and Sign In choice actions, but do not allow registration over an existing verified financial owner; show a clear notice instead. No reset, overwrite, silent signup or finance mutation from UI navigation.
- **Status:** screenshot confirmed; implementation on branch `fix/m478-logout-verifier-recovery`, QA pending. Require exact-head Flutter test/analysis, existing-login and new-first-choice tests, both home/locked logout paths, original/recovered password re-login and signed-APK device proof before marking Done.

## M533 — Recurrent M274 Android emulator death on every finance/UI PR (2026-11-07; Issue #481 / PR #480)

- **Evidence, not an app assertion failure:** Exact-head M274 run 42379593762 / job 128424273986 built APK and booted Android API35 Google APIs with emulator **37.2.13.0**, but immediately after actual rapid footer UI test passed, VM Service vanished at balance-eye case (`(112) Service has disappeared`), ADB went offline and port 5554 refused connections. Host RAM 14GiB available and disk 78GB free. Android emulator process was gone; no `Expected:` or `Actual:` failure found. Prior M532 #477 changed `-gpu swiftshader_indirect` to `-gpu software`; still reproduces in #480.
- **Approved remediation scope:** Freeze ReactiveCircus emulator to stable **36.4.10 build 15004761**, use supported `-gpu swiftshader -feature -Vulkan` per Android developer troubleshooting, keep API35 + 2 cores, native Android Flutter Driver real UI tests, exact prebuilt app, actual footer/eye assertions, golden tests, KVM, SDK and no shims to green. Check/report exact pinned version before executing; collect relevant host/QEMU crash evidence on failure, upload bounded diagnostics artifact without actual private user data. New stability assertions in `test/qa/m533_android_emulator_runner_contract_test.py` must protect against reverting to floating emulator/GPU flags or bypassing tests. Scoped changes: **ONLY** `.github/workflows/m274-production-ui-golden.yml`, `.github/scripts/run-m274-android-tap-smoke.sh`, new M533 regression test, and bounded requirements/manifest/release notes. No runtime financial, auth or SMS behavior modified.
- **Acceptance:** exact new SHA Flutter/widget/Android CI; real M274 Android tests actually complete with zero failures (and ideally repeat once on separate runner); failure/crash remains red and diagnostic artifact is attached. Verify no other unrelated CI regressions, preserve M385 and M449. **Current status: change underway; not proven fixed.** Related original investigation [#477](https://github.com/MahmoudMAnwar/waffra-app/issues/477), ongoing issue [#481](https://github.com/MahmoudMAnwar/waffra-app/issues/481).

### M533 additional discovered release-blocker — M412 false green on docs-only final commit

Run **42380971071** was reported green while its actual Android and widget/golden jobs were **skipped**, because M412 looked only at the *latest commit delta* (M449 release note) rather than the whole PR's previously changed M274 config. Thus a successful workflow summary could wrongly certify **zero device tests**. Owner-approved M533 correction: for this M274 workflow specifically, keep M412 impact analysis visible, but make its required `run` job output **unconditionally true** on the triggered workflow, so both actual Android-engine and golden jobs run even if last commit was documentation-only. If M412 itself fails, the dependent tests cannot masquerade as passed. Add an explicit regression assertion against reverting to `run: ${{ steps.impact.outputs.run }}`. No GitHub job is permitted to be considered a real green unless the Android test job has `conclusion=success` (not `skipped`). Status: change in implementation, real test pending. Evidence and issue: https://github.com/MahmoudMAnwar/waffra-app/issues/481.

### M533 mandatory post-job certification — prevent future false-green if Android job skipped
In addition to forcing actual M274 jobs to execute on triggered workflows, add a separate **always-running** final certification job that `needs` both `android-emulator-ui-taps` and `widget-ui-and-golden-candidates` plus `m412-impact`. It must **fail** whenever any required job's GitHub `needs.*.result` is not exactly `success`, including `skipped` and `cancelled`. This blocks release even if someone later reintroduces an M412 `run=false` condition or edits one real job's `if`; source-only tests are insufficient. CI release remains blocked pending actual real-device Android result. #481 / PR #480.

### M533 M174 source-contract correction, not a test bypass (2026-11-07)
The M174 post-merge Python QA gate failed 1 of 145 tests on exact PR #480 SHA 3a033ba. The obsolete `m412_workflow_wiring_test.py` assumes EVERY M274 job is an incremental `needs: m412-impact` consumer; new M533 fail-closed *terminal* M274 certification intentionally requires all real UI, golden and impact jobs and `if: always()`. The only approved QA correction is a narrow special case in the existing test for that exact M274 certification job, asserting its three dependencies and fail-closed always gate. Preserve the test's existing requirements for every other workflow and actual Android/golden jobs. Require all 145+ Python QA tests green and actual M274 Android execution, not just source-script success. Issue #481 / PR #480.

### M534 — Second emulator executable probe aborts M274 with 127 before running real test (2026-11-07, Issue #481)

- **Evidence:** Exact-head M274 run 42382146234; job 128432096992. Android emulator 36.4.10 (pinned) boots successfully, ADB responds. `bash .github/scripts/run-m274-android-tap-smoke.sh` exits 127 before printing `M274_ANDROID_UI_ATTEMPT`. The runner starts with `version_output="$("$emulator_bin" -version 2>&1)"` under `set -e`, hiding its failure output. This extra binary launch is not needed since the action pre-emulator launch already verifies the full exact build.
- **Scoped fix:** Keep workflow's exact upstream build ID challenge; verify installed emulator revision via read-only `$ANDROID_SDK_ROOT/emulator/source.properties` `Pkg.Revision=36.4.10` before `flutter drive`, never spawn the emulator executable a second time. Reject unreadable/unexpected metadata; no test bypass or false-green. Guard against duplicate/partial runner script text and ensure one actual `flutter drive` path.
- **Acceptance:** `bash -n` passes, mandatory Android job actually launches Flutter Driver and completes six-footer/balance-eye real assertions, golden job passes, final M274 certification gate succeeds (no skipped), all exact-head other CI passes. Until then status is **not fixed**. Tracking: https://github.com/MahmoudMAnwar/waffra-app/issues/481.

### M534 exact-head acceptance for release-note-last commits

M274 must also trigger on `docs/release/WAFFRA_APPROVED_CHANGES.txt` changes because M449 deliberately requires release notes to be committed after app/workflow changes. Without this path, final documentation-only PR head cannot receive fresh exact-SHA mandatory Android evidence. M274 already always runs actual emulator and golden jobs when triggered and has a hard certification gate: both must finish `success` and may never be counted green if skipped. Scope the trigger-only change to the workflow `on: pull_request.paths` block. No global M412 behavior change.

### M535 — API35 Android emulator VM Service handshake timeout, not assertion fail (2026-11-07, Issue #482)

- Latest exact-head PR #480 source SHA `f9211d7`, run 42383368057, Android job 128435628343. Emulator 36.4.10 boots, SDK pinned-verifier passes, actual debug APK installs; FlutterDriver prints `Connecting to Flutter application at http://127.0.0.1:37419/...` then cannot establish VM WebSocket, repeats `It is taking an unusually long time to connect to the VM...` 866 times, killed after 900s with code 124; no actual Flutter test starts. Emulator/ADB still online at timeout, widget/golden suite passes. Existing Google APIs system image shows background GMS errors in logcat; this is suspicious, not yet a proven root cause.
- **Scope:** Try streamlined official Android Test Device system image `aosp_atd` for the same Android API35 x86_64 / pinned emulator 36.4.10 / prebuilt debug Flutter APK, which avoids expensive GMS initialization irrelevant to M274 UI widgets. Keep Android test mandatory, same tap/balance privacy test, original frontend/finance/auth source untouched. Instrument VM connection failure to distinguish ADB forward, application crash and emulator death without extending 15-minute hangs; preserve actual failures and diagnostic artifact. Add a narrow test contract that asserts lightweight test device and mandatory UI. No test skipped or artificial green.
- **Acceptance:** fresh exact-head M274 emulator job executes and passes both actual footer and eye test, golden job passes and mandatory M533 certification succeeds, then all other CI; if it still hangs inspect new ADB/Flutter startup logs rather than repeatedly running unchanged config. **Status: awaiting real evidence.** https://github.com/MahmoudMAnwar/waffra-app/issues/482.

### M537 — pre-APK executable local phone credential lifecycle (2026-11-07)

- **Owner request:** run a real code-level registration → repeated sign-in/sign-out credential preservation regression before asking for another Android APK test. Track under PR #480 / issue #478.
- **Implemented:** `test/m537_phone_credential_lifecycle_test.dart` executes the production PBKDF2 verifier with isolated mocked Flutter secure storage: registration/read-back, three repeated login challenges, wrong password, foreign phone, overwrite refusal, missing and malformed verifier, salted hash without plaintext. No user finance or real Android storage touched.
- **Limitation:** this focused test does not yet execute the full `main.dart` widget logout-to-login session or prove SQLCipher financial preservation; those still need separate integration/Android acceptance.
- **Status:** committed, awaiting CI execution/results on the exact latest PR HEAD; do not mark passed until confirmed. Do not merge before full required CI and Android acceptance.

### M538 — Android emulator process dies during real footer UI test (2026-11-07)

- Run 42389972623: actual API35 AOSP ATD boots and Flutter Driver connects; first footer test begins, then VM Service disappears and ADB reports device offline. Separate widget/golden job passed; mandatory Android gate correctly failed. Host after crash had 15Gi total RAM, 14Gi available and 81G disk free, so the precise emulator termination cause is not yet established.
- **Scoped stability attempt:** increase virtual emulator resources from 2 to 4 cores, 2048M to 3072M RAM and 256M to 384M heap. Keep pinned emulator 36.4.10, AOSP ATD API35, actual footer/balance test and hard fail gate; update M386 resource regression accordingly. No production finance/auth code changed.
- **Acceptance:** real Android test must complete and mandatory certification succeed on final exact SHA; if crash persists, inspect host kernel/emulator crash diagnostics rather than declaring fixed. PR #480, issue #482. **Status: awaiting CI evidence.**


### M540 — Strict M533 Android runner contract aligned with M538 emulator resources (2026-11-07)
- Exact-head M174 run 42391379538 failed in `test_preserves_exact_flutter_driver_and_real_android_ui` because the old source contract required `cores: 2` while the approved M538 real Android experiment intentionally sets `cores: 4`.
- Update only that exact assertion to `cores: 4`, explicitly bound its function in `docs/qa/approved_change_scope.json`. Preserve actual API35 AOSP ATD, `flutter drive`, emulator version pin, hard failure on offline devices and independent golden/Android certification.
- No auth/finance source changes. Verification: new exact-head M174 and M274 must pass before merge; until then this is a code fix, not a confirmed Android success.


### M541 — Real Android emulator repeated host crash after UI assertions (2026-11-07)
- M274 run 42391593765: actual API35 AOSP ATD Flutter driver passed rapid footer taps, reached balance eye test, then Flutter VM extension disappeared and `adb` went offline; QEMU emulator process vanished. Independent widget/golden job passed. Host still had ~14 GiB available RAM and 80 GiB free disk. This is an emulator-host disconnect, not a proven login/logout defect.
- Emulator startup also logged malformed Pixel 6 SystemUI overlay shell commands. Replace only M274 emulator AVD `profile: pixel_6` with lean `profile: pixel_2` as a bounded stability hypothesis; preserve real API35 AOSP ATD, Flutter driver, strict M274 certification and no skip-on-failure. Assert this exact profile in M533 source contract.
- This is an experiment, NOT a proven permanent fix. Require a successful full actual M274 Android run plus M174 and all exact-head gates before merge. If it fails again, inspect runner crash artifacts and use an independently stable Android runner/device rather than claiming success.


### M542 — Keep M386 fail-closed Android profile contract synchronized (2026-11-07)
- Exact-head M174 `42392425428` failed: `test_real_android_engine_is_still_required` in `test/qa/m386_m274_emulator_disk_safety_test.py` still asserted `profile: pixel_6` although approved M541 real AOSP ATD workflow now uses `profile: pixel_2`.
- Change that one existing bounded test assertion to require `profile: pixel_2`, preserving API35/AOSP ATD, live Flutter driver, required Android certification, and no skips. This is a test/config consistency repair, NOT proof that emulator crash was fixed. Re-run all exact-head gates, especially M174 and M274, before merge. PR #480.


### M543 — Fix reproducible Linux x86_64 emulator-host crash without modifying production (2026-11-07)
- M274 exact-head run 42392784190 (PR #480) proves repeatable emulator QEMU/ADB loss during real Flutter Android UI tests: first footer test passes, eye/balance test starts and VM service disappears. 32 other workflows succeeded, and independent golden passed. Switching Pixel 6/2 did not solve it. Host resources were available.
- Upstream Flutter engine incident https://github.com/flutter/flutter/issues/192736 documents Flutter 3.44+ Impeller GLES killing software-rendered Linux x86_64 QEMU, resolved for disposable emulator testing by disabling Impeller in its *test-only* Android manifest. This is an evidence-based mitigation, pending exact-head verification; does not claim production rendering tested.
- M274 creates a disposable Android project on the CI runner. Immediately after `flutter create`, inject `io.flutter.embedding.android.EnableImpeller=false` into only that generated `android/app/src/main/AndroidManifest.xml` before debug APK build. Production app source/SQLCipher/data/sign-in code and production Android build are unchanged; real API35 engine, widget/golden checks, real Flutter UI driver, fail-closed gate remain required.
- Remove the obsolete `pre-emulator-launch-script` which fails with exit 127 in the runner (observed repeatedly). Keep exact emulator pin and its installed SDK `source.properties` check before real driver runs. Regression guard must verify this and reject skipped Android/golden jobs. Gate on M174 and M274 exact-head success before merge.


### M544 — Full PBKDF2 login/logout lifecycle regression requires focused realistic CI timeout (2026-11-07)
- On PR #480 exact SHA `84fd367e`, three independent full-Flutter workflows (Full Offline Finance and UI, M282, M340) failed with the SAME `test/m537_phone_credential_lifecycle_test.dart` case `register, close session, login repeatedly with same phone/password` timing out after the test runner default 30 seconds; logs show `TimeoutException`, not a failed password assertion. All other 2510 widget/unit tests passed in those full-suite jobs.
- Preserve production PBKDF2-HMAC-SHA256 at 600,000 iterations; preserve repeated correct and incorrect password assertions and registration-resume checks, secure verifier integrity and storage isolation. Extend ONLY this heavy PBKDF2 regression's per-test timeout to 3 minutes; never reduce real iterations, delete the test, mark flaky/skipped, or widen all tests' timeout.
- Verify targeted M537 and all exact-head Flutter suites, M174 and real M274 Android plus mandatory quality gate before merge. This is a CI test-time budget correction, not proof a real end-to-end Android logout/login UI journey has passed. No changes to auth or finance production source.


### M545 — Sign out confirmation only; silent secured return path for old accounts (2026-11-07)
- **Issue #483, user screenshot:** currently Account Settings logout opens `استعادة بيانات الدخول مرة واحدة` and asks for a password after yes. User explicitly requires only `هل أنت متأكد من تسجيل الخروج؟` → `نعم` / `لا`; tapping yes signs out without password, biometrics, or any further popup. Tapping no keeps existing session. Apply to all logout entry points.
- Existing accounts may lack the `FlutterSecureStorage` PBKDF2 verifier, so simply deleting the modal would trap encrypted finance. On sign-out stage a silent, OS-secure, phone-hash-bound, random one-time missing-verifier recovery grant, verify its persistence, and do not alter SQLCipher, profile identity, or password. Reject malformed/different-owner storage; if safe sign-out cannot be assured, retain session and give a non-password error. The grant does not authenticate alone.
- Only on *future sign-in* with same registered phone and real device biometrics, accept the password typed on the ordinary login screen, register/read-back the new PBKDF2 verifier and consume the grant. Do not permit identity reassignment or password overwrite. No recovery UI on logout. Maintain 600,000 production PBKDF2 rounds, no finance deletes.
- Add regression for no recovery dialog from logout; old missing verifier stage → secure fresh login; unrelated phone, corrupt/replayed grant, password mismatch and ordinary ready-verifier login. CI must pass including full Flutter suite + real Android M274 before main. APK only on green main. PR branch `fix/m545-confirm-only-logout-recovery-at-login`.


### M546 — Main signed-Android login locked out after apparently successful logout (2026-11-07)
- **Critical user screenshot / Issue #485:** after merged PR #484 Yes-only logout, re-login with the originally generated password displays a missing/invalid secure login verifier *before password comparison*. No credentials or phone numbers from the screenshot belong in GitHub. Do not clear app data, reinstall, change owner, delete SQLCipher, or treat missing as incorrect password.
- Source finding: the phone verifier currently reads the default FlutterSecureStorage backend while the app's other financial/SMS secure stores select Android EncryptedSharedPreferences. First inspect any **already-existing** saved verifier in a supported alternate Android backend **read-only**, only if the primary backend has no record. Authenticate only by verifying the same phone plus exact original password/PBKDF2 record; primary malformed/foreign must never be overridden, a missing record in both backends remains an unresolved safe lockout.
- Preserve original verifier, 600000-iteration PBKDF2, read-back after registration, account authority, encrypted finance, SMS pause, biometric gate, original Yes/No signout. No silent password reset, no migration/deletion and no OS biometrics alone as proof of original password.
- Tests must cover preferred vs alternate precedence, malformed/foreign records, wrong password, no record in either store, registration/repeated logout→cold login, real supported Android backends on both fresh and updated APK, and readable failure when neither verifier survives. Real Android device/Keystore evidence remains required for root-cause and customer recovery; Flutter mocks alone cannot certify the incident.
- PR branch: `fix/m546-login-verifier-backend-compat`. CI: full Flutter/QA/M385/M449 plus real M274 Android on latest exact SHA, no skips, no main merge until green and device flow accepted.

### M547 — Whole-app jank following SMS activation; review capacity and truthful incremental scanning (2026-11-08)
- **Issue [#487](https://github.com/MahmoudMAnwar/waffra-app/issues/487)**; existing performance requirement [#419](https://github.com/MahmoudMAnwar/waffra-app/issues/419). User reports splash animation, sign-in → permissions (~3s), biometric → Home spinner, navigation, and manual/SMS save UI jank after installing SMS history scanning; Add Rule dialog remains immediately responsive. Login and Yes/No sign-out have been successfully device tested by user and must not be changed.
- **SMS-01:** Raise encrypted pending review capacity from 500 to 1000 without clearing earlier reviews, exclusions, owner binding, dedupe, transfer/finance ledger or scans.
- **SMS-02:** Make the first installation-month scan report real inspected and added counts; incomplete historical scans must say **continuing initial history**, not newly received.
- **SMS-03:** Subsequent explicit rescans must inspect only new Android SMS since persisted verified cursor, show per-run real deltas and never reset to reread the month. Do not lose partial cursor on capacity exhaustion or crash.
- **PERF-01/02/03:** Profile physical Android in release/profile (UI and raster frame p95; startup, auth, navigation, manual/SMS save), remove per-message full encrypted queue rewrites in batch history import; stop full-history scans and repeated classification on unrelated finance saves and resume. Preserve security, KDF, SQLCipher authority and accurate review state.
- **Gate:** Source change / successful CI is not device proof; verify signed APK clean install + in-place upgrade on two Android phones and preserve all prior finance records. Exact-head CI evidence required. No merge to main until checks and mobile QA.
- **Status:** Recorded; implementation **in progress** on `fix/m547-incremental-sms-review-performance-20261108`. Do not mark Done before real-device acceptance.

#### M547/PERF-04 — Login button stalls for ~3 seconds before verified permissions / biometric / Home (owner follow-up 2026-11-08)
- The owner first reported this in the original performance request and again supplied an Android login screenshot. After tapping `تسجيل الدخول`, the outlined login button briefly looks empty and entrance animations / loading stop responding before the verified next page.
- Current login verifies the existing 600,000-iteration PBKDF2-HMAC-SHA256 password via `lib/waffra_local_phone_credentials.dart::_derive`, including extra checks on new registration and sign-in. This cryptographic CPU task MUST NOT occupy Flutter's frame-rendering isolate. Offload only CPU derivation to a short-lived Dart isolate, preserve byte-for-byte verifier format, same original phone/password behavior, exact 600000 rounds, existing legacy and recovery conditions, original secure storage backend and biometric behavior, and avoid retaining/logging passwords.
- UI must display immediate stable `جارٍ تسجيل الدخول` feedback, prevent duplicate taps/commits while busy, and keep transitions responsive while verification is pending. Confirm CPU contention by frame profiling on physical Android, rather than assuming wall time is reduced.
- Exact-head login/logout lifecycle, invalid-password, missing/malformed/alternate verifier and one-time secure recovery tests; Android release/profile frame traces before/after. No merge until acceptance, no change to already user-verified Yes/No logout.
- **Tracking:** Issue #487, PR #488; status: code candidate, **device performance not yet proven**.
- **Additional confirmed native source hotspot (PERF-04):** Android MethodChannel's `resumeAutoSmsAfterSignIn` and `setAutoSmsEnabled` presently call `WaffraAutoSmsStore.resumeForSameSignedInOwner` / `enable` synchronously on the Android main/UI thread. Both take the same mutex as the expensive historical SMS queue/import path and may call blocking SharedPreferences commits, so they can freeze the native Flutter surface during login or post-permission onboarding. Move those calls to the existing serialized SMS I/O executor; return results/errors on the main thread. Do not modify the working sign-out confirmation/authority. Verify consent/owner binding and first-time Android permission after change.

#### M547 CI regression follow-up — shared three source-contract failures (2026-11-08)
- PR #488 exact HEAD `6cae5d4d02fdcc29ee79fbccf5146cd732030987`: 33 successful / 6 failed GitHub workflows, all failed full-Flutter jobs share three source-level tests; the 7th user-visible failure may be a separate check and must not be assumed until its log is identified.
- M506 expected the obsolete local `queued` capacity expression; verify instead that the native queue reaches no more than 1000 entries and that a full queue blocks cursors from skipping unreviewed history.
- M507 expected a native history rescan immediately after a reviewed SMS save; this contradicts the user-requested nonblocking navigation. Preserve `prepare()` re-reading fresh owner-bound rules for **each next** SMS; verify no full inbox/history scan runs on finance-save transition.
- M518 expected old historical `offer(..., historical = true)` and `lastAt/lastId` names, replaced by an atomic batched queue+cursor commit. Verify `date_sent` selection, receiver `sms.timestampMillis`, receivedAt vs sender identityAt, canonical fingerprint `id(sender, body, identityAt)`, `nextAt/nextId` based on the examined Android provider row, and atomic persisted queue/cursor. Retain account-scoped exclusion/confirmed-transfer dedup and do not weaken security.
- Update **only the three source-regression tests** and M385 exact bounded-scope manifest, then release notes as final commit; rerun full exact-head CI without skipping tests. Never merge on a red gate; profile/physical handset remains mandatory.

### M548 — Full-app latency recurrence after M547 merge (2026-11-08)
- **Issue [#489](https://github.com/MahmoudMAnwar/waffra-app/issues/489)**; related previous issues #419 and #487. **Branch:** `fix/m548-review-signup-and-navigation-jank-20261108`. User's Android screenshots: Home has 1000 SMS needing review (3 classified, 997 pending), review sheet opens extremely slowly and message list is nearly unresponsive; new phone signup sits about 3 seconds at `إكمال التسجيل / جارٍ الحفظ`; navigation, loading animations and app-wide tabs still stutter.
- **PERF-05 — Review access:** Once Home has a verified, owner-bound and consent-checked in-memory SMS queue, opening review must not re-read/decrypt/classify all 1000. Cold/missing/error snapshots must still execute a verified refresh and never show a stale list after owner/security failure. Sender grouping must be linear-time with case-insensitive canonical labels, stable newest-first ordering, 1000 distinct or shared senders, preserved body/date, selections, exclusions, anti-replay, finance authority and Back behavior.
- **PERF-06 — Background parser:** Yield between bounded local parse batches during native pending refresh so 1000 messages cannot monopolize the Flutter frame isolate. Never skip or auto-confirm reviews, nor erase a failed ACK. Existing native serialized SMS I/O and explicit historical-rescan cursor remain unchanged.
- **PERF-07 — Registration:** Keep 600000 PBKDF2 iterations and secure-storage encrypted verifier. Fresh registration derives once, verifies byte-for-byte **complete secure-store read-back** of the generated version/phoneHash/salt/hash/iterations record instead of performing a second identical PBKDF2. Interrupted or existing registrations must still validate same phone + original password via full cryptographic challenge. Paint a stable busy spinner before the secure I/O and block repeat taps. Do not modify user-accepted Yes/No logout, biometric, backups or SQLCipher account money.
- **PERF-08 — Device evidence required:** 0/100/1000 SMS, 1000 distinct senders, first registration, logout→login, permissions, both Samsung/second Android phone fresh install and data-preserving upgrade; release/profile frame p95, time-to-first-visible sheet, signup wall time. **Code candidate; CI and Android QA pending. Do not mark Done or merge solely from a source test.**

#### M548 CI follow-up — M429 sender-grouping assertion
- PR #490 first HEAD `b8abff4e`: M429 combined phone/SMS test failed because it asserted the removed *inline map implementation* even though the same case-insensitive sender behavior moved to the pure O(N) grouping helper. The existing M429 test is updated only inside the original sender-group test to validate the new helper, sender evidence, route IDs, original body/provenance, selection and retained review flow; new M548 pure tests check 1000 senders and chronological order. No login/logout/finance behavior changed for this test repair. New exact-head CI and signed device validation still pending.

#### M548 CI repeated failures — root-cause confirmation (2026-11-08)
- PR #490 exact head `fd216d0488a56907a257bb91b7b202ea55c1b6e0`: **33 successful / 6 failed GitHub workflows**. All six failed full-Flutter jobs ran 2526 passing tests and the **same one failing test**: `test/m547_sms_incremental_jank_regression_test.dart`, case `M547 only an explicit rescan fetches historical pages during UI interactions`. The M340 verdict also fails because its required full-Flutter job fails; that is downstream, not another code defect.
- **Source-contract root cause:** the old test used `.split('// Every bank sender gets one group.')[0]` as a function boundary. M548 replaced that temporary comment with an O(N) helper, so the selector silently read from `_openAutoSmsInbox` to the end of `lib/main.dart` and found unrelated explicit rescans. This can create six repeated red workflows out of one stale assertion. A reusable fail-closed source-section helper now requires unique, stable method-declaration start/end anchors; it throws if missing/duplicated/reordered. A dedicated meta-test verifies that unrelated explicit rescans elsewhere cannot be mistaken for history paging inside Review.
- **Real runtime follow-up:** inspection also found hidden `importMonth:true` after bulk exclusion inside the Review sheet and after saving local SMS rules. These can cause expensive background scanning while the user interacts, contradicting the adopted M547 explicit-Rescan/low-jank contract. Both paths now re-read and classify the existing authenticated pending queue only; the persistent month cursor and explicit Rescan are unchanged, and no messages/financial entries are silently removed. Updated original positive M461 exclusion test checks the real behavior and explicit history continuation instead of requiring the removed hidden scan.
- **No test skip/bypass:** existing M547 and M461 test cases are strengthened; new M548 meta-test and fail-closed source helper added. M385 scope declares every touched existing test and protected source section. **Status: code candidate; latest exact-head CI and real-device frame performance still need verification.** No new PR; fixes remain in #490.

#### M548 CI second-pass correction — durable exclusion test formatting (2026-11-08)
- Exact head `55e3d5d40120e3c43487d52fa059024d2661daaa`: whole-Flutter jobs reported **2530 passing tests / 1 failing**. The **original repeated M547 test now passes**. Only `test/m461_sms_exclusion_and_history_scan_test.dart`, case `review refresh serializes work and batches durable exclusions`, failed because our new source assertion expected `setState(()=>_autoSmsPending.removeWhere` on one literal line while the verified existing code correctly wraps the setState callback and removal across two lines.
- Corrected the test to assert **within the bounded Review method** both `if(mounted)setState(()=>` and `_autoSmsPending.removeWhere((row)=>done.contains(row['id']))` as independent positive requirements, as well as the non-historical owner-queue refresh and explicit rescan path. Checked these exact strings against the actual PR-head production source. No production code, finance source, exclusion behavior or security gate is weakened for this test correction. This extra source assertion is now whitespace/layout resilient. Original M547 and new M548 source-boundary tests remain untouched and passing in the prior whole-Flutter run.
- The six CI workflows are duplicated whole-suite runners, **not six unrelated functional regressions**. New exact-head CI still required; do not consider green until all 39 relevant runs finish. Keep PR #490 in Draft.

#### M548 seven critical CI groups — SHA-scoped concurrency (2026-11-08)
- PR #490 exact-head `b10db93017b68f6d24e3149954f295bd49f4c1ba` had M274/M340 red dependent verdicts after required jobs were cancelled; M147 was cancelled before any job and GitHub refused retry (403). These were not failing app tests. The common workflow `concurrency.group` was keyed only by PR number, so a late older synchronize event could cancel a new commit's checks.
- The seven observed full-suite/merge-critical workflows now append `${{ github.event.pull_request.head.sha || github.sha }}` to the concurrency group. This isolates different source SHAs while preserving same-head deduplication and the trusted M453 cleanup of truly superseded PR runs.
- New `test/qa/m548_ci_exact_sha_concurrency_test.py` and retained M453 positive QA enforce this grouping and owner/SHA-safe cleanup. Workflow trigger paths, source checkout, gate semantics, Android tests, no-cutover protections, authentication and financial authority are unchanged. A single atomic PR commit is used to prevent another interleaved update burst.
- This is a scoped fix for seven priority workflows, not an unverified claim that every GitHub workflow uses SHA separation; all actual same-SHA CI and Android device acceptance must still be run.


## M549 — 1000 SMS review / sender-only exclusion / smart Rescan / all senders (2026-11-08)
- **GitHub issue [#491](https://github.com/MahmoudMAnwar/waffra-app/issues/491)**; **implementation PR [#490](https://github.com/MahmoudMAnwar/waffra-app/pull/490)**. Status: **Code candidate / exact-head CI and physical Android device validation pending**.
- 1000/1000 selectable: bulk exclude all review messages from **Waffra encrypted review queue** without deleting Android SMS or any committed finance data; prevent 1000 sequential sender confirmation dialogs; durable idempotent removal, explicit failures, and bounded CPU/IO.
- When excluding **sender**, keep only its encrypted normalized sender name; purge all of that sender's pending Waffra SMS and previously stored per-message exclusion hashes/labels. Future live/history messages from that sender are ignored before persistence. Existing finance receipts untouched.
- Rescan must neither re-add the 1000 already pending/previously confirmed/excluded nor restart a completed historical cursor. Dim when initial scan complete and no newly arrived SMS is known, re-enable on fresh SMS or when unfinished history with available capacity can progress. If 1 of 1000 gets confirmed, 999 remain; at most genuinely unseen SMS may fill the freed slot.
- Remove bank-heuristic gating from native **review-only intake** and include all nonempty inbox SMS from **all senders** since installation-month start, respecting opt-in and blocked senders. Never auto-post or infer financial account from nonfinancial messages; do not retain plaintext OTP digits. Current native `qualifies` wrongly filters personal and nonfinancial messages.
- Evidence: source/native+Flutter regressions for 0/999/1000 queues, blocked-sender storage purge/restart, historical cursor and dedup, 1000-item bulk selection, Rescan enabled state, all-sender eligibility and masked OTPs; full exact-head CI and physical Android smoothness tests still mandatory. Do not mark Done on code commit alone.

#### M549 bulk-delete confirmation latency — user clarification (2026-11-08)
- The owner explicitly rejected any synchronous 1000-SMS parsing just to show the exclude-confirmation dialog: the selected IDs alone authorize review-only exclusion after confirmation. Keep the generic financial-caution text without scanning any bodies, preserving the two separate explicit choices (messages-only vs also block senders). Source regression added; real-device timing pending.

## M550 — Every-PR behavior-to-CI contract alignment (2026-11-08, Issue #492)

**Source:** [Issue #492](https://github.com/MahmoudMAnwar/waffra-app/issues/492); extend existing [PR #490](https://github.com/MahmoudMAnwar/waffra-app/pull/490), not a new PR.

**Approved requirement:** Audit all registered GitHub Actions workflows and Python/Dart tests for every behavior-changing PR against the **current approved behavior and proposed implementation before raising or updating the PR**; detect stale positive source assertions proactively. Record explicit before/after behavioral contract, impacted source, affected tests and jobs; make a fail-closed, exact-HEAD preflight with meaningful coverage; maintain full real tests (Flutter, Python, Android, finance, privacy, SQLCipher) and never fake green by skipping/deleting checks. Detect both obsolete expectations and actual code compilation failures. Update obsolete assertions only when user-approved behavior warrants it. Include source-based negative regressions proving old assertions are caught. Current M417 Android Kotlin compile error at `native/WaffraAutoSmsStore.kt:570` missing closing `)` must be fixed separately.

**Status:** Candidate guard code and Kotlin syntax patch prepared for PR #490; full exact-head CI and device acceptance still pending. The automated preflight is a *guard*, not proof of semantic equivalence or physical device quality.

**Permanent PR protocol:** (1) Write each proposed behavior change and its Issue in `docs/WAFFRA_REQUIREMENTS.md`; (2) update `docs/qa/approved_change_scope.json` and `docs/qa/behavior_contract_review.json` with old/new behavior, safety invariants, impacted tests and all production files; (3) run `python3 -m unittest discover -s test/qa -p 'm550_behavior_contract_preflight_test.py'` and `python3 scripts/qa/m550_behavior_contract_preflight.py --base <main-base-SHA> --head <actual-HEAD-SHA>` against exact committed HEAD; (4) correct legitimate stale expectations **only after** reviewing the actual approved implementation and never delete tests to force success; (5) full Flutter/Python/Kotlin/Android jobs and signed handset evidence remain required before main merge. Every workflow and QA test file is dynamically included in M550 inventory. The scanner specifically catches provably disappeared **positive literal source assertions**, not all semantic bugs; human QA review remains mandatory.


### M552 — 2026-11-08 — Mandatory verified SQLite3MC artifact handling in CI
- Issue #492 and PR #490: every Flutter-enabled GitHub Actions job must prefetch the same upstream immutable sqlite3 3.7.0 SQLite3MC binaries via the official GitHub Release API, validate per-platform SHA256, seed only the native-hook verified cache, then run every original Flutter/Android/finance/security test unchanged. Never weaken the SQLCipher native hook, enable system plaintext SQLite or accept a third-party mirror. Add whole-repo CI coverage so new workflows cannot skip this preflight.
- First M174 isolated exact-head job has passed; do not merge or promise APK until all current-head workflows and physical-device upgrade tests pass.


### M554 — Android CI Gradle download integrity — 2026-11-08
- In all Android compilation/emulator jobs affected by the intermittent GitHub 504, preseed the **original** Gradle 9.3.1-all ZIP via the official GitHub Release API, with official SHA256 pin; fail closed if any source is unavailable or the digest differs. Never change Gradle/SQLCipher app versions or skip Android security tests to make CI pass. Linked to PR #490.


### M555 — Exact Kotlin compiler artifact recovery in Android CI — 2026-11-08
- For HTTP 504 on `org.jetbrains.kotlin:kotlin-compiler-embeddable:2.2.21`, cache only JetBrains' official SHA256-pinned JAR plus validated original POM in an exact-module, CI-only Gradle local Maven source. Do not substitute Kotlin versions, modify project Gradle files, disable security, or skip emulator tests. Review real compile output and preserve source provenance. PR #490.


## M564 — Issue #495 verified SMS transaction-date integrity (2026-11-08)
**Owner instruction:** implement immediately in PR #497. **Status:** Code ready, exact-head CI/device QA pending; remaining one-tap yes/no and editable review in progress.
- Both bank-SMS financial save routes must use the date actually parsed from the original message. Missing or ambiguous original date blocks automatic posting; never substitute the phone's DateTime.now.
- Keep source pending, mandatory verified account linking, budget optional, confirmed SQLCipher commit / dedup unchanged.
- Regression: test/qa/m564_sms_exact_date_guard_test.py; M174/M429/Android required.


## M565 — #495 bank SMS Yes/No and verified commit (2026-11-08)
**PR:** #497. **Status:** Code and regression committed, exact-head CI and Android owner acceptance pending.
- Display original SAR amount/date and suggested active leaf category next to “هل العملية صحيحة؟” Yes/No. No opens editable SMS review preserving source. Yes enabled only with verified source amount, direction, original transaction date and category.
- Yes performs verified account selection (create if required), optional budget, then source-authorized atomic SQLCipher ledger+SMS hash write, accounts learning after actual successful commit and Android ACK. Duplicate hash is never posted twice. Unknown facts fail closed.
- Test: test/qa/m565_sms_yes_no_test.py. M564 exact dates enforced independently for legacy single and bulk paths. Full flutter and native Android CI pending.


## M566 — #495 explicit date for edited SMS (2026-11-08)
**PR:** #497. **Status:** committed / exact-head CI and device acceptance pending.
- If original bank SMS has no parsed timestamp, the editable review must explicitly confirm a date using the calendar before save. The edit's date confirmation persists in the same per-SMS Back draft. Defaults must never become a verified historical date without choice.
- Test test/qa/m566_sms_manual_date_confirmation_test.py; date from M564 batch and single writers remains authoritative.


## M568 — #495 exact bank SMS identity reuse (2026-11-08)
**PR #497. Status: code/test committed; current-head full CI and physical Android acceptance pending.**
- First verified owner-account choice following a successful SMS journal commit records sender + last four. Same sender+last four may reuse that specific active same-bank account, after re-reading fresh SQLCipher authority; no repeated account-link dialog. The finance action itself still needs Yes confirmation and atomic hash dedup.
- Sender-only, absent suffix, changed suffix, archived account or wrong bank never auto-link and require new explicit selection. Update M464/M493 tests accordingly.


## M573 — #495 Account learning after edited SMS (2026-11-08)
**PR:** #497. **Status:** Code and regression written, latest exact-SHA CI and real device acceptance pending.
- No → edit pathway now submits known bank SMS sender for verified account review and records confirmed sender+suffix association only after actual successful encrypted ledger+hash write. No guesses, no repeat debit and no learning from canceled SMS reviews.
- Test: test/qa/m573_sms_edited_account_learning_test.py.


## M574 — #495 full transaction details in bank-SMS Yes/No (2026-11-08)
**PR:** #497. **Status:** Committed / full CI and device QA pending.
- Before Yes/No, preview shows income/expense, bank amount/currency, parsed description, valid main/subcategory, sender, masked original account suffix or missing-identity notice, and bank message's original YYYY-MM-DD HH:mm timestamp. The account is still owner-selected/verified before SQLCipher saving, never guessed from Home's active filter.
- Test: test/qa/m574_sms_confirmation_full_fields_test.py.


## M576 — #495 distinct last-four identities under one bank (2026-11-08)
**PR:** #497. **Status:** Source and regression code ready; full exact-head CI / Android device acceptance pending.
- First reviewed SMS for a new sender+four-digit bank identity offers choose existing or create new even if a separate account at the same institution already exists. Previously confirmed identical sender+four suppresses repeat prompt, account still verified under SQLCipher witness; never guess a mismatched four.
- Test: test/qa/m576_first_distinct_bank_identity_test.py.


## M578 — #495 correction of SMS original date and time (2026-11-08)
**PR:** #497. **Status:** Code + regressions committed, exact-head CI & Android owner QA pending.
- No/edit SMS when transaction timestamp missing: user chooses calendar date then exact hour/minute via clock picker. Cancelling either cannot satisfy confirmation; future timestamp refused. Display both before save, preserve existing historical transaction date during edit. No silent today/midnight financial posting.
- Tests: test/qa/m566_sms_manual_date_confirmation_test.py and test/qa/m578_sms_time_confirmation_test.py.


## M580 — stale M177 encrypted storage smoke writer count (2026-11-08)
**PR:** #497. **Status:** QA code repaired; exact-head encrypted storage smoke + M174/M340 rerun pending.
- The M177 storage regression previously required exactly 3 atomic bank SMS finance writer call sites, obsolete after approved M565 added fourth verified Yes-confirm path. Preserve all four legitimate source-authorized writers. Require M565 itself to include verified account selection + generation, atomic SMS+fingerprint journal, no duplicates and only post-commit native ACK. Change only the bounded M177 positive test, not any money source or security gate.


## WAFFRA-NEW-021 — Sign-in submit responsiveness, disappearing button and ~3s first-time delay (2026-11-08)

**Issue:** [#498](https://github.com/MahmoudMAnwar/waffra-app/issues/498) · **Related:** [#419](https://github.com/MahmoudMAnwar/waffra-app/issues/419), #485 · **Implementation PR:** Not assigned · **Status:** **Recorded / Not implemented — owner explicitly deferred coding until all observations are collected.**

**Owner APK feedback:** Overall app performance has improved substantially, but (a) after Yes-confirmed logout, logging back in with the valid account causes the «تسجيل الدخول» primary button to disappear before the app eventually opens; (b) at first-time account-creation/user-details submission, advancing takes approximately **3 seconds** by user estimate. Screenshot privately provided in conversation; do not copy any visible phone number or password to GitHub.

**Expected UX:** Immediate tap acknowledgement and stable visible submit/loading state, disabling duplicate attempts instead of hiding the button or appearing frozen; smooth transition with no unnecessary stall. Preserve approved sign-in layout, first-run choice, normal Yes/No logout, valid-password sign-in and secure account owner verification. Optimize only after release/profile Android trace identifies actual synchronous work, duplicate queries/initialization, routing/rebuilds, or other measured causes; do **not** downgrade PBKDF2, biometrics, SQLCipher, data/backup integrity or consent to fake speed.

**Acceptance:** Record before/after tap-to-feedback and tap-to-interactive timings, UI/raster frames and auth/storage/route spans; separately cover fresh install → registration completion, logout → login-again, repeated sign-in, warm/cold start, both physical Android devices and upgrade with preserved records. No transient blank CTA, no blocked UI, no duplicate login, correct failures for invalid credentials. Add targeted Flutter widget/integration regressions and pass full exact-head CI + owner Android QA. Do not claim Done until device evidence and owner acceptance.

**Sequence:** First item of the new owner-reported performance/suggestion batch. **Record now; begin all implementations only when owner confirms the complete batch and asks to start in order.**
