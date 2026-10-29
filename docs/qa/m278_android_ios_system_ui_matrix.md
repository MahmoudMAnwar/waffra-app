# M278 — Android and iOS system UI, safe-area, and screen-compatibility QA

## What is automated
- Flutter widget tests use the **real Waffra five-destination footer** and real reusable error-notice host in a representative Scaffold. Page bodies and AppBar are synthetic. These tests **do not** certify the entire installed app.
- Android matrix: 320dp small, 360dp with 3-button (48dp bottom) or gestures (24dp bottom), 393dp full-screen (zero OS padding) or with status/nav visible, tall, narrow fold, 600dp unfolded, landscape.
- iPhone-style matrix: 375dp Home-button, 390dp notch with 59dp top/34dp Home Indicator, 430dp Dynamic-Island-like top inset, full-screen, and landscape.
- Both Arabic RTL and English LTR; all five footer destinations in each configuration; hit targets at least 48dp; header below status; footer controls above OS bottom; scrollable content; full bleed footer background.
- Validation notice above footer, not over navigation; 200% font on 320dp/3-button; status bar/gesture mode switches without losing tab.
- Android emulator tests actual Android edge-to-edge and immersive system UI modes with taps, reading real engine insets.
- macOS CI generates a temporary Flutter iOS host (ios/Runner not tracked), runs layout matrix and attempts unsigned iOS simulator compilation.

## Not certified by M278 — follow-up QA needed
- Entire signed installed Waffra: Home, Categories, Smart Tools, Goals, Recurring, account/settings, transaction editing, single/bulk SMS, sheets, dialogs, receipts, charts, PDFs, backup/restore, PIN/biometrics, onboarding and login.
- For every screen: 320/360/393/430dp; iPhone compact/standard/large; Android gesture and 3-button; top cutouts; full screen; keyboard opened; rotation; 100%-200% font; Arabic/English; light/dark; accessibility services; physical back gestures.
- Verify header never conflicts with status icons/notches, actions never fall under bottom system navigation, no RenderFlex overflow, keyboard does not block confirmation, sheets and PDFs stay usable, and full-bleed art leaves controls safe.
- Permanent native iOS Runner/assets/entitlements and configuration, Xcode + iPhone simulator screenshots, physical iPhone testing, Apple Sign-In/Firebase build setup and review. A temporary CI iOS build cannot substitute for these.
- Physical Android OEM samples including 3-button/gesture/immersive modes; host simulated insets cannot prove every device is supported.

## Merge policy
- Review-only until exact-HEAD host/UI, Android emulator and iOS native build checks are green.
- M277 notice close-area fix must be combined and re-tested on one integrated SHA before shipping.
- No storage or schema changes, SQLCipher activation, Firebase deployment, or released APK/IPA in this PR.
