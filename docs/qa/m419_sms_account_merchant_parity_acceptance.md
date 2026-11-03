# M419 — Genie-equivalent SMS financial workflow: product and QA acceptance

**Scope:** PR #352, not main. Based on eight user-supplied reference screenshots, but Waffra must retain its own Saudi/emerald visual identity; reproduce functionality rather than cloning another app's assets or exact UI.

## Critical flow to certify

1. Android displays a prominent first-run, skippable explanation of `READ_SMS` and `RECEIVE_SMS`; runtime permission requires an explicit tap. Separate notification consent is requested on Android 13+.
2. Qualifying bank SMS are detected in the background even when the UI is closed; the user's own previous SMS remain available for bounded import. OTP, ads and personal messages are excluded. Raw bank SMS are not uploaded to a cloud model in the current offline implementation.
3. Parse each financial event into **kind**, **source account**, **target account**, **original amount/currency**, **transaction timestamp**, **merchant or recipient**, **separate fees**, **reference** and **bank status**. A generic sender is never proof of account ownership.
4. The accounting engine does not equate "transfer" with "expense", "incoming own-account transfer" with "income", or "card settlement" with "spending". Only validated income/expense events may be auto-posted. Transfers require a typed, linked pair of accounts, and their fee is a separate cost.
5. Trusted merchant aliases and user corrections control category and budget suggestions; do not silently rewrite past records. A missing/paused budget must never be guessed or linked incorrectly. Show "غير مربوطة بميزانية" for truly unlinked expenses.
6. Save eligible operations through the **existing** Home/Widget cross-engine finance authority and atomic SMS hash journal, never through a second preferences database. After the writer re-reads the committed ID and hash, send a private Android "recorded" notification. Retry safely if process dies, handle permission revocation and avoid duplicate entries.
7. The transaction details page links securely to the encrypted original SMS; highlight the amount and show separate receipt/currency information. Provide a full edit screen and undo. Do not show full bank identifiers on lock-screen notifications.
8. Add distinct bank-account and wallet views (not just the cash ledger), masked last-4 identifiers, card liabilities, matching source/destination of transfers, merchant pages and optional recurring/subscription suggestions. Manually-added transactions cannot pretend they originated from bank SMS.
9. Original transaction currency is retained. Any FX conversion must include its source, timestamp and quoted rate; never apply the app's display currency as the original bank transaction amount or invent an EGP equivalent.
10. Preserve all existing user data, categories, recurring plans, budgets, goals, original manual transactions, currency converter and Saudi-only phone validation through upgrade.

## Screenshot-guided acceptance cases

| Case | Expected outcome | Current M419 status |
| --- | --- | --- |
| Outgoing wallet transfer for SAR 882.00 plus SAR 0.58 fee | Transfer between source and destination accounts, not a generic expense; fee distinct | Transfer + fee/account suffix extraction implemented; typed two-account ledger **pending** |
| Incoming transfer identified as "Credit Transfer" | Track as incoming bank transfer, do not count as new income until owned-account reconciliation | Kind recognition implemented; account reconciliation **pending** |
| Personal recipient name in an outgoing transfer | Show recipient not merchant purchase | Counterparty extraction candidate implemented; final merchant/account UI **pending** |
| Account picker with Cash and multiple bank accounts | Distinct accounts/cards with masked suffixes and own balances | **Pending** |
| Original bank SMS view with emphasized amount | Accurate amount, fee, date, original raw evidence; secure storage | Existing SMS notes vault and new review facts; UI parity **pending** |
| Merchant directory, editable alias and classification | Group by merchant and correct one alias to affect future operations | Existing learned merchant category rules; dedicated merchant directory **pending** |
| Foreign SAR→EGP conversion with bank and FX source | Preserve SAR amount, show verified EGP equivalent and rate date | Foreign SMS safely requires review; verified FX ledger **pending** |
| Purchase/income message while app is closed | Exactly-once posting and private notification after verified commit | Worker + notifications candidate; Android physical-device tests **pending** |
| Manual EGP transaction | Proper user-chosen account, original EGP currency; no false SMS provenance | **Pending** |
| Recurring merchant charge | Suggest recurring/subscription pattern without auto-scheduling without user choice | Existing recurring module; automatic detection **pending** |

## Release-stop checks

- [ ] The SMS background worker actually runs on a locked physical Android phone with genuine permission grant. Prove delivery and process-death/restart behavior, not just an in-process unit test.
- [ ] Kotlin compile + app package build and merged manifest signed; test Android 12–17 permissions and OS power restrictions.
- [ ] Exact-head Flutter analyzer, parsing tests and all existing financial/data-migration QA green.
- [ ] Multiple-account identity mapping and transfer/card posting model validated in an encrypted finance migration, without using guessed bank ownership.
- [ ] Verify source account cannot silently default to `Cash` when a real bank source is known.
- [ ] Real Google Play approval for SMS-based money management, privacy policy and Data Safety reviewed.
- [ ] Permission decline/revoke, sign-out/wipe, duplicate SMS, fees, transfers, FX, conflicting currency, OTP, refund, disputed/failed messages, app reinstall/upgrade all tested.
- [ ] Protected budget, goal wallet, category, merchant rule, widget and backup data unchanged when importing SMS.

### Architecture boundary

M417's native receiver stages encrypted SMS only; M418's background task invokes the authoritative financial writer; M419 adds source facts and refuses unsafe transfer/card/fee/unknown-account postings. **Do not report exact Genie functional parity until account/card-ledger features and signed-device tests have independently passed.**

Google Play authorization and live-device tests are not obtainable from GitHub CI source-only checks.
