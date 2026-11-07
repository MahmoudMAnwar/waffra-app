# M508 — Saudi-first bilingual offline bank SMS seed catalog

Tracking: Issue #439, draft PR #436. Last reviewed: 2026-11-06.

## What is actually bundled
- 177 **new original** immutable, offline-only rule objects: **53 income, 102 expense, 8 transfer, 14 excluded**.
- **793 curated Arabic/English keyword variants** in `lib/waffra_sms_saudi_seed_rules.part.dart` (53+102 financial category rules, 22 special review-only candidates).
- Previously installed built-in hints remain; seeds are compiled into `WaffraSmsLocalRules.allDefaultRules` and grouped in the Settings UI as دخل / مصروف / تحويل / مستثناة.
- 100% local text matching; no external network, downloaded bank SMS corpus, data export, personal SMS training at install, or cloud API bill.
- Seeds are **templates and high-level distinctive names**, not assertions of verified messages from each bank. Merchant aliases are intentionally conservative; some may be used by unrelated merchants or in advertisements.

## Research provenance (information, not code or message copying)
1. Saudi Central Bank [Unified Notification Elements for Financial Institution Customers](https://rulebook.sama.gov.sa/ar/%D8%AA%D9%88%D8%AD%D9%8A%D8%AF-%D8%B9%D9%86%D8%A7%D8%B5%D8%B1-%D8%A7%D9%84%D8%A7%D8%B4%D8%B9%D8%A7%D8%B1%D8%A7%D8%AA-%D8%A7%D9%84%D9%85%D8%B1%D8%B3%D9%84%D8%A9-%D9%84%D8%B9%D9%85%D9%84%D8%A7%D8%A1-%D8%A7%D9%84%D9%85%D8%A7%D9%84%D9%8A%D8%A9) (29 Nov 2020). Describes purchase, e-commerce, transfers, withdrawals, deposits, bills, financing installments, fees, reversals and wallet transaction notifications, plus Arabic/English banking descriptions and minimum fields.
2. [NBK KSA SMS Service](https://www.nbk.com/ksa/services-and-support/sms-service.html), describing POS, internet purchases, withdrawals/deposits, salary/allowance/transfer and Arabic/English alerts.
3. [Saudi Communications, Space & Technology Commission SMS Fraud Guidance](https://www.cst.gov.sa/knowledge-center/user-awareness/SMS-fraud), supporting cautious handling of suspicious senders and phishing links.
4. [Saudi SAMA fraud warning](https://www.sama.gov.sa/ar-sa/MediaCenter/News/Pages/news-622.aspx), warning about fraudulent messages that impersonate financial institutions.
5. Public OSS design examples (e.g. https://github.com/wa1939/athar) informed high-level review-vs-learning safety requirements only; NO private-corpus text, code, merchant tables or rule lists were copied.
6. Existing `waffraCategoryCatalog` from this Waffra repository is the only category authority. All 155 financial seeds map to its named existing children.

## Security and financial control
- Text hints cannot move money. `autoPost:false`, `accountId:''`, `accountSuffix:''`, empty sender and `builtIn:true` on every new rule.
- Bank sender, bank direction and money/ISO currency are **separate** parser checks: keywords do not confirm posted money or source financial account. Forex, fees, transfers between a user's own accounts, pending/declined/OTP and payment pre-authorization require review or rejection.
- Every new seed exclusion is a **non-destructive suggestion**: only the owner's existing explicitly configured exclusion may auto-ack a queued message. Even a financial message containing an OTP/promotion keyword is retained.
- Saved user-specific encrypted rules remain separate from immutable seeds and take priority when independently direction-valid. A conflict between two specific built-in categories resolves to manual review rather than selecting an arbitrary category.
- Raw SMS, sender numbers, card tails, IBANs, OTP values, dates and amounts are NOT in the new seed dictionary.
- Inactive/deleted leaf categories must not be assigned automatically. Review UI checks available category before preselecting.

## Acceptance tests
- `test/m508_saudi_default_sms_rules_test.dart`: count, rule IDs, locale variants, category validity, no sensitive digits, salary/groceries/subscription classification, transfers, exclusion without auto-ACK, failed/declined/OTP and custom rule precedence.
- `test/m507_sms_amount_and_continuous_review_test.dart`: bank amount + category prefill, retained review queue, learned rule application to next message.
- Existing `test/m462_smart_sms_rule_review_test.dart`, `test/waffra_sms_rule_reuse_test.dart` and financial safety regressions must stay green.

## Manual Android smoke matrix (REQUIRED before Done)
- Fresh install, existing update, Arabic+English languages, initial SMS permission; verified SQLCipher snapshots and secure rules retained.
- Income: salary, allowances, government benefits, refunds, dividend/interest and ambiguous promotional salary ads.
- Expense: POS, mobile top-up, grocery, restaurant, utility, gas station, transfer fees, credit-card settlement and reused merchant variants.
- Transfer: incoming, outgoing, international and **own account-to-account** two-sided transaction; no budget debit.
- Excluded: OTP, authorization, login notification, unsuccessful/declined, marketing and fraud-awareness copy — never accidentally drop a valid financial SMS.
- SMS repeated/deduplicated, review list refresh and a manually corrected future message.
- Measure release-mode UI frames/startup/refresh and rule-settings scrolling; no assumption that green Flutter unit tests certify handset performance.

**Acceptance status:** source changes and unit fixtures committed on PR #436; exact-HEAD CI and physical Android validation pending. No main merge or released APK claimed.
