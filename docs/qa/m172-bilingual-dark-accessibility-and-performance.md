# M172 — Arabic/English RTL/LTR, dark theme, accessibility and performance

## Isolated regressions added
- Flutter WaffraText renderer tested at **175% text scaling**, with Arabic RTL and English LTR, light/dark, Tajawal font, no thrown widget exceptions.
- Language switch must not mutate the Arabic stored finance key.
- Read-only source review ensures system/light/dark theme, near-black `#080A09` dark scaffold, accessible primary text contrast, system reduced-motion and explicit animation-off mode.
- Python contrast audit calculates **WCAG relative-luminance** contrast for currently identified primary foreground/background pairs; it is NOT a complete visual audit.

## Theme-transition test reliability
The 175% widget regression now waits for `MaterialApp`'s animated
`themeMode` transition to settle before checking inherited brightness.
A single-frame assertion could incorrectly report a light theme while the
light-to-dark animation was still in progress. This does not replace real
phone dark-mode, contrast, TalkBack, or 200% scaling evidence.

## Known usability issues and unverified paths
- Base theme icon buttons currently specify a **36dp minimum size**. Verify actual effective 48dp touch target and TalkBack hit box before rollout; do not silently redesign approved navigation in this branch.
- 200%/large font across the complex Home, categories, savings, recurring, forms and PDF needs real device screenshots/semantics verification.
- Screen-reader semantics labels, focus order, text contrast on income/expense cards, PIN keypad and modal dialogs require explicit accessibility testing.
- Benchmark long lists (76 category roots / ~690 children), PDF export, paste 100 SMS, app startup and Widget refresh under low-memory conditions and compare against last signed APK; do not set an arbitrary performance success threshold based on CI host timings.
- Support Arabic/English status strings throughout live app, not just dictionary lookups. Test offline mode, OS dark/system mode and animation-disabled accessibility setting.

Run `python3 scripts/qa/m172_accessibility_review.py`; `flutter test test/m172_accessibility_rtl_dark_textscale_test.dart test/m148_english_categories_legacy_backup_uat_test.dart`.

**Not release approval:** no physical Android screenshots/TalkBack/performance trace captured and no UI or finance source activation changed.
