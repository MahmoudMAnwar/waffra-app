# M437 — Bank SMS Settings: history scan and unrecognized financial notices

Owner screenshot reference: Genie settings contains “فحص رسائل SMS السابقة” and
“رسائل SMS غير معروفة”. The second reference includes Etimad messages
announcing issuance of debt that is due for payment, without proof of any
completed payment or a legitimate transaction amount.

## Implemented for Waffra (Android only)
- In My Account, a distinct expandable **رسائل SMS البنكية** / Bank SMS
  section has two options. It is discoverable by account-settings search.
- **فحص رسائل SMS السابقة** / Scan previous SMS calls the existing
  consent-month, resumable encrypted bank-SMS importer and refreshes Home's
  review queue. It does not request SMS permission again and does not post
  to the finance ledger. It shows added bank candidates and count of up to
  100 unrecognized notices within the bounded on-demand scan.
- **رسائل SMS غير معروفة** / Unrecognized SMS queries the local Android SMS
  inbox on demand using the same one-time permission and month-start cutoff.
  Only financial-looking notices from institution senders and debt/invoice
  notifications are shown. OTP/password messages and personal senders are
  excluded. Scans at most 500 messages and displays at most 100 results.
  Unrecognized message bodies are not stored in a new database or uploaded.
- Etimad debt-issuance text is labeled **إشعار مديونية — لا يثبت حدوث عملية دفع**.
  IDs, dates, organization names and URLs never become an amount or automatic
  expense, regardless of the number of digits in the reference.
- Selecting a notice opens an original-text review sheet. “إنشاء معاملة يدويًا”
  opens a blank existing manual transaction form, with the user's own amount,
  category and budget confirmation. The notice itself is not imported as a
  transaction, edited or deleted from Android SMS.
- No history beyond the activation month, no bank permission re-prompt per SMS,
  no cloud analysis of the unknown notices, and no change to existing finance,
  goals, backups or secure wallets.

## Before main release
- Run exact-head Flutter checks + Android Kotlin/WorkManager compile.
- Test both categories with synthetic sender SMS and month boundaries on
  signed physical Android. Check Etimad debt sample is **not** recognized
  as payment and does **not** create money data.
- Verify a legitimate purchase/credit still routes to the normal encrypted
  review queue and never duplicates into unknown SMS.
- Validate absence of OTP/private SMS, no network calls on opening the unknown
  screen, up-to-100 list and full detail sheet, Android system-back behaviour.
- Do not update a family phone with existing financial records without
  backup/restore and signed-device migration parity acceptance.
