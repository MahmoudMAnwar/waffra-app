# M326 — Waffra brand copy and regional Arabic UX

## Approved launch slogan
**Arabic:** وفرة… فلوسك بوضوح

**English:** Your money, made clear

Replaces the old Saudi-only phrase on the animated Flutter launch screen. The launch itself does **not** request location permission.

## One invariant: language, country and display currency are independent
- User-selected app language (Arabic or English) controls the UI language and RTL/LTR layout. A Saudi country selection **never overrides an explicit English choice**.
- The independent UI country preference `waffra_ui_country_iso_v1` selects *Arabic wording only*: Saudi colloquial for SA; Egyptian-friendly for EG; neutral Modern Standard Arabic elsewhere/when location is unavailable.
- The first-run country screen can detect the approximate country on explicit tap, or let the person select a country manually. It persists ISO country only after the user confirms setup, never coordinates, addresses or precise GPS.
- The app's display currency stays a separately editable preference. Changing SAR to EGP, or any other currency, does not change the country, language or the numeric values of existing transactions.
- Country and dialect can also be changed later in My Account independently of location access.

## Updated text surfaces
- Animated launch-screen slogan with bilingual content.
- Double-back-to-exit info notice, localized warning about startup failure, sign-out confirmation.
- Home welcome greeting: Saudi rotating wording restricted to selected SA, Egyptian or neutral for other countries, English if app language is English.
- Basic shared WaffraText warnings and common confirmation/retry actions. Country-specific exact-phrase replacements **do not** touch bank messages, user-entered transaction content, categories, stored finance records or saved backups.

## Coverage and limits
- Unit regression: `test/m326_region_dialect_splash_localization_test.dart`.
- The app currently supports **Arabic and English**. Additional complete UI languages require translations and QA; region selection is not a language pack.
- Existing older screens also contain literal text and independent widget messages. These need ongoing copy audit before calling **every** alert fully localized. This PR covers the shared message layer and main critical exits/notices, not an independently certified full-app string inventory.
- No finance mutation, SQLCipher changes, bank integration, app permissions or release-signing change.
