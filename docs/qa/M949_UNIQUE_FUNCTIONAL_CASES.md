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
