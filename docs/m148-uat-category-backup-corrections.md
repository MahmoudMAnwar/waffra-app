# M148 — UAT corrections (categories, backup recovery and clipboard performance)

Source: the user's M147 on-device acceptance run reported **12 passed, 2 failed, 1 untested**. The failures were (3) English main/child category labels in category page/manual/SMS entry and (14) archive password recovery plus a slow unresponsive large backup textbox. The duplicate/cancel scenario (8) remains untested.

## Changes

1. All **76** built-in category roots and **690** built-in children have reviewed English display labels in `waffra_category_english.dart`. Existing stored Arabic labels/IDs, category links, budgets and transactions **are not rewritten**. English searches can match localized names in categories, manual entry and recurring entry. Custom user-created names remain exactly as entered: the app cannot safely guess an English translation for arbitrary user labels.
2. New backups still require **exactly 8 alphanumeric characters, at least one letter and one digit**. The restore box is separate, accepts the **exact original password**, including the longer passphrases that previously valid encrypted backup archives used. Restore does not re-encrypt or change the stored password and supports the existing `waffra-secure-backup` v1 and plaintext `waffra-backup` format.
3. The restore flow uses **Paste backup from clipboard** to stage JSON in memory, shows a status rather than the full sensitive archive, and runs PBKDF2/decryption/JSON parsing in a Flutter isolate. It no longer loads large archives into a scrolling editable `TextField`, avoiding heavy cursor layout and dialog-wide `onChanged` rebuilds. Clipboard import rejects empty or over-8-MB payloads before parsing.
4. The existing biometric gate, confirmation **before** replacing data, fail-closed validation, and backup integrity checks remain in place. No bank connectivity, Firebase config, native app icon, database migration or production SQLCipher change.

## Device acceptance steps

- Set EN. Open main categories and expanded child cards; use English terms to search in the category page, Add Income/Expense category selector, bank SMS review, recurring payment selector; return AR and ensure correct Arabic labels and transactions remain linked.
- Export a test backup using exactly `Abcd1234` (use a different secret for any actual personal data). Paste its JSON via clipboard using the new restore button, enter the **original** password in **Restore existing backup** field, verify that the confirmation screen shows, then cancel once to ensure nothing is overwritten.
- On a disposable test dataset, confirm actual restore and compare category IDs, transactions, goals, recurring and balances. Try an intentionally wrong password and corrupted archive; neither should replace existing data.
- If there is an earlier encrypted Waffra backup with a password longer than eight characters, enter it exactly in the restore password field; no legacy switch is necessary. Never share live encrypted backup contents or passwords in bug reports.
- Paste a large disposable backup; the dialog must remain responsive without a huge editable JSON field. Observe responsiveness on the actual phone, not just CI.
- Complete the previously untested duplicate/cancel scenario (UAT step 8).

## Release restrictions

This is a **Draft PR** against `main`, not a production deployment or authorization to merge. Gate on full Flutter regression, Android build and actual signed-device confirmation. Existing physical-device signing, Firebase, SQLCipher and user-data migrations are out of scope. No existing user data is accessed or changed by this PR.
