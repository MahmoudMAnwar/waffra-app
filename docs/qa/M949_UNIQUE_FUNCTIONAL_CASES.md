# M949 — 43 new nonduplicated functional journeys

**Issue:** https://github.com/MahmoudMAnwar/waffra-app/issues/655
**Baseline:** `main` after PR #654, SHA `b624100a040d2a05c02d9ea9827dd36494c39538`

## Audit method and limitations

The repository had **618 test files and 18 Android integration files** at case selection. Existing targeted M440, M481, M641, M447, M940, M948, and fresh-finance-modules tests were inspected. The cases below test **multi-step user state transitions or intersections**, not standalone actions already present. `scripts/qa/m949_unique_functional_case_audit.py` compares every new exact test title with existing titles, enforces 43 distinct IDs, refuses skipped/disabled and source-inspection-only placeholders, and runs as part of M946 every-PR smoke.

The audit **does not claim to mathematically prove semantic uniqueness against all historical implementations**. Its explicit baseline comparisons and runnable outcomes are the available evidence. All financial data is synthetic and stored in disposable SQLCipher. Real Android OS, physical fingerprint, notifications, and user-private legacy backup need separate device UAT.

### Account, transfers, historic reconciliation (14)

**Previously covered vs new:** Existing M440 one-transfer/replay, M481 rename and M943 groups; NEW scenarios chain independent operations, partial historic assignment and archive failure boundaries.

| New ID | Unique tested journey |
|---|---|
| M949-A01 | renamed bank retains identity after inbound and outbound transfers |
| M949-A02 | chained three-account transfer preserves each halala and total |
| M949-A03 | drain account to exact zero then archive, future source rejected |
| M949-A04 | zero-balance archived destination cannot receive new transfer |
| M949-A05 | duplicate account ID with another kind and opening preserves original |
| M949-A06 | failed whitespace rename does not modify transfer ledger |
| M949-A07 | 81 Unicode runes rejected on rename while saved money survives |
| M949-A08 | invalid account kind does not create partial financial owner |
| M949-A09 | corrupt account timestamp never creates historical owner |
| M949-A10 | transfer replay changing ONLY its note fails without double debit |
| M949-A11 | one-halalah transfer with long valid note then oversized note rollback |
| M949-A12 | separate transfers sharing one timestamp are not deduplicated |
| M949-A13 | partial historical mapping keeps existing bank link and maps only orphan |
| M949-A14 | linking missing transaction fails foreign key, never creates phantom link |

### Goals, recurring due and categories (17)

**Previously covered vs new:** Existing fresh-modules CRUD, M641 goal/due account and M447 paid due; NEW scenarios mutate linked entities sequentially and prove typed SQL/default/other siblings remain consistent on failure.

| New ID | Unique tested journey |
|---|---|
| M949-M01 | renaming parent category keeps existing child parent ID and kind |
| M949-M02 | editing parent budget to one halala does not edit child budget |
| M949-M03 | reclassifying unused category to income updates typed and JSON together |
| M949-M04 | multi-category list is sorted and cannot mutate encrypted saved maps |
| M949-M05 | goal target and due-date edit preserves saved and linked schedule |
| M949-M06 | invalid goal alert threshold rejects edit without changing neighbor |
| M949-M07 | changing saved goal to missing account fails, linked due unchanged |
| M949-M08 | bank rename keeps verified linked-goal due account identity |
| M949-M09 | switching one recurring default leaves another schedule bound |
| M949-M10 | unlink goal first, then change recurring account without spending savings |
| M949-M11 | clearing only one schedule default deletes its stale account link |
| M949-M12 | missing goal refuses new due, existing due and account remain |
| M949-M13 | linked due wrong account edit rolls back typed row and default |
| M949-M14 | invalid changed date cannot partially replace recurring account default |
| M949-M15 | half-halalah recurring edit cannot change old monthly money amount |
| M949-M16 | paused recurring date change persists but posts no transaction |
| M949-M17 | missing ID update in one module preserves all three siblings |

### Home multi-control filters with account scopes (12)

**Previously covered vs new:** Existing M940 pagination and M948 isolated date/10k index tests; NEW scenarios combine date, amount, type, category, search and verified-account choice in the same query.

| New ID | Unique tested journey |
|---|---|
| M949-F01 | all five filters applied together select one legitimate expense |
| M949-F02 | single-halalah amount range is inclusive at both edges |
| M949-F03 | identical title and category never mixes salary with spending |
| M949-F04 | dues filter keeps recurring and goal due, not ordinary expense |
| M949-F05 | unexpected persisted type string rejects records, not broadens all |
| M949-F06 | Arabic diacritics, Alef and Ta Marbuta find title in account slice |
| M949-F07 | equal timestamps still stable when mixed filters narrow account IDs |
| M949-F08 | year rollover date and account scope combine without spilling |
| M949-F09 | zero verified IDs cannot leak matching unassigned receipt card |
| M949-F10 | switching income to expense does not mutate shared verified index |
| M949-F11 | account scoped pagination with simultaneous category/amount constraints |
| M949-F12 | impossible min/max amount intersection shows empty without loss |

## Totals and acceptance

| Functional test area | Distinct new executable test cases |
|---|---:|
| Accounts / transfers / historical association | 14 |
| Goals / Recurring / Category multi-step integrity | 17 |
| Home financial filter intersections | 12 |
| **Total NEW functional tests** | **43** |

Four separate Python audit mutation tests are **not** counted among these 43. New cases are run through existing M946 money/experience shards, without replacing any old test. Do not merge before exact-head passed/failed/skipped evidence and existing full CI gates are green. No production feature code is modified in this PR.


## M950 extended audit: 46 more distinct functional cases (15 Nov 2026)

**At the M950 milestone, the PR had 89 distinct new functional test() cases**: 43 M949 + 46 M950. The additional 46 consist of 28 pure verified source decision cases and 18 disposable encrypted SQLCipher cross-month projection cases; they are not fixture loop input counts.

### M950-P — SMS, recurring due, budget and goal-source decisions (28 new functional cases)

Compared with: Baseline M448 account policy, M86 recurring, M948 amount/dates; new tests combine source/destination bank suffix handling, unicode digits, account header independence, and multi-source goal/recurring decisions.

| New case | Executable scenario |
|---|---|
| M950-P01 | incoming verified Arabic destination digits map to one bank |
| M950-P02 | outgoing Persian source digits map to Arabic verified suffix |
| M950-P03 | incoming ignores matching source and requires verified destination |
| M950-P04 | outgoing ignores matching destination when source mismatches |
| M950-P05 | two accounts with suffixes in different numeral scripts are ambiguous |
| M950-P06 | three-digit suffix cannot select verified financial account |
| M950-P07 | five-digit source is never truncated or guessed |
| M950-P08 | transfer or excluded classification blocks even exact verified SMS |
| M950-P09 | invalid saved suffix on another bank does not poison unique match |
| M950-P10 | unsupported verified suffix mapping never produces fake account |
| M950-P11 | selected account view rejects empty selection without widening to all |
| M950-P12 | unassigned debit and credit remain visible in All but neither bank |
| M950-P13 | matched account cash delta includes credit and expense but not other |
| M950-P14 | budget global spending includes unassigned and other bank not incomes |
| M950-P15 | changing account header cannot alter global budget warning threshold |
| M950-P16 | rejected invalid budget row cannot be dismissed by selected other bank |
| M950-P17 | budget ignores nonmatching invalid row and does not consume unrelated category |
| M950-P18 | fully released source ends at exact zero while unrelated bank savings persist |
| M950-P19 | duplicated goal wallet movement across accounts rejects whole projection |
| M950-P20 | two successive one-time due account overrides leave original future bank intact |
| M950-P21 | first recurring default creation then explicit future switch does not reuse prior owner |
| M950-P22 | one-time recurring selection cleared retains future default |
| M950-P23 | clearing future recurring account never silently uses previous bank |
| M950-P24 | overdue unpaid recurring schedule remains actionable on prior due day |
| M950-P25 | paying overdue recurring after postponement shows next month instead |
| M950-P26 | schedule starting after current due rolls into next month |
| M950-P27 | postponed due keeps original monthly posting identity |
| M950-P28 | future schedule starts after clamped February due and waits March |

### M950-S — Actual SQLCipher cross-month banking, budgets and unassigned queue (18 new functional cases)

Compared with: Baseline M448 encrypted context single-month, M684 month reader, M949 chained accounts; new tests combine cross-year/leap month, selected scopes, real bank-budget ledger attribution and stable historical review pages.

| New case | Executable scenario |
|---|---|
| M950-S01 | December-to-January month boundary does not lose or mix verified bank rows |
| M950-S02 | summaryOnly across leap February retains exact 29th and excludes March |
| M950-S03 | identical event times page deterministically by descending entry ID |
| M950-S04 | selected bank page excludes other bank and unassigned matching month |
| M950-S05 | unknown selected account has empty page without inferring an owner |
| M950-S06 | unassigned summary nets positive incomes and negative expenses across years |
| M950-S07 | unassigned 13-item review pages never skip tie timestamps |
| M950-S08 | explicit zero-opening association updates selected month and unassigned net |
| M950-S09 | two legacy cash movements reattach once and survive encrypted cold reopen |
| M950-S10 | failed reassignment after original bank link cannot steal transaction |
| M950-S11 | rejected historical confirmation leaves review queue and bank untouched |
| M950-S12 | invalid year-month spellings cannot query historical bank data |
| M950-S13 | invalid month paging limits and offsets are rejected before SQL |
| M950-S14 | month-specific budget spending separates cross-year and unassigned rows |
| M950-S15 | switching account header changes budget share but not stored finance |
| M950-S16 | real internal account transfer cannot appear in income expense ID filter |
| M950-S17 | archived account cannot take newly linked historical salary |
| M950-S18 | monthly query result cannot be mutated to fake persisted account association |

### Automated uniqueness audit
`scripts/qa/m950_extended_functional_audit.py` must verify exactly P01–P28 and S01–S18, with meaningful unique titles, zero skipped tests, zero duplicate names from existing cases, and no source-text-only checks. It joins M949 audit in the mandatory M946 feature matrix. Four separate Python audit self-tests are not counted in the 89 Flutter functional cases.

**Explicit limits:** A finite suite cannot prove all bugs eliminated. Actual mobile biometrics, old private backup restore and OS SMS/notification runtime still require physical-device evidence.


## M951: 26 new SMS eligibility and owner-isolated budget alert cases

**Final new functional test count on PR #656: 115** = 43 M949 + 46 M950 + 26 M951. This is the number of executable Dart `test()` cases, not the number of files or the variable data rows inside test loops. There are six NEW Dart test files; separate Python audit unit tests are not counted.

Compared with existing `test/waffra_auto_sms_policy_test.dart` and `test/m444_budget_alert_once_test.dart`: M951 checks independent boundary and combined eligibility conditions and owner/budget/year/time isolation beyond basic allowance, blanket invalid amount, same-owner threshold and same-key concurrency already present.

| New ID | Distinct direct user behavior |
|---|---|
| M951-A01 | untrusted alphabetic sender cannot post valid completed bank purchase |
| M951-A02 | fake BANK label with long phone digits is untrusted despite bank substring |
| M951-A03 | foreign currency flag blocks otherwise valid Saudi purchase |
| M951-A04 | missing verified account link blocks posting even with bank sender |
| M951-A05 | inactive user category rejects valid-looking card expense |
| M951-A06 | source date exactly two days ahead stays within supported window |
| M951-A07 | source date two days plus one second ahead requires manual review |
| M951-A08 | source date exactly 365 days before arrival is still eligible |
| M951-A09 | source date older than 365 days by one second needs review |
| M951-A10 | missing extracted money amount is not a zero-valued posting |
| M951-A11 | parsed fractional halala is rejected without automatic rounding |
| M951-A12 | parsed amount beyond one-million SAR threshold must be reviewed |
| M951-A13 | verified expense cannot silently become income when parser direction conflicts |
| M951-A14 | missing verified bank and paused category are not bypassed together |
| M951-A15 | blank SMS is ignored before sender or money validation |
| M951-A16 | oversized SMS above review allowance is ignored before financial posting |
| M951-B01 | two budgets under same owner do not share a threshold token |
| M951-B02 | interleaved owners crossing different budget stages cannot consume others alerts |
| M951-B03 | changing calendar day inside same month does not repeat warning |
| M951-B04 | same month next year receives a new independent alert threshold |
| M951-B05 | blank owner never persists invalid notification history |
| M951-B06 | blank budget identifier never claims another budget warning |
| M951-B07 | invalid progress stages cannot create owner notification |
| M951-B08 | repeated percentage values in one batch count as a single stage |
| M951-B09 | out-of-order threshold jump marks earlier crossed levels as already used |
| M951-B10 | simultaneous alerts for different budget owners each survive isolation |

The mandatory M946 manifest enforces a separate `scripts/qa/m951_last_functional_gap_audit.py` to reject any missing/duplicate/skipped source-linked case. Host CI cannot certify real Android SMS receipt/notification/biometrics or an owner's private restored backup.
