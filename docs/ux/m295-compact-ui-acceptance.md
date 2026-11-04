# M295 — Subtle selection and compact buttons: QA acceptance

Baseline: main at 877899a6858eba8df0f89e5968e2ef5da9f26c76.
Scope: presentation only; no finance or storage model changes.

## Implemented
- All Material segmented options use a modest selected 1.6dp emerald border + low-alpha green fill, versus 1dp neutral unselected; light and dark styles.
- Global outlined/text buttons use muted default borders so the active state is distinct. Footer selected border is softer; selection chips show a subtle green rim and check.
- Current goals counter displays its label in one line at ordinary text scale; compact widths/labels for the deleted goals control.
- Income and expense home summaries have reduced vertical padding, symbol sizes and amount typography. Existing approved balance graphic untouched.
- Home Quick actions are collapsed initially; expanding animates in the unchanged Export report and Financial calendar callbacks. Collapsing does not affect data.
- New subcategory and transaction date have 12dp independent spacing: side-by-side on wide screens, stacked on narrow or large-text screens.
- Shared minimum 48dp button tap targets preserved; RTL/LTR and accessibility verification required.

## Release validation
- Exact PR HEAD: Flutter analyze for modified sources and M295 tests.
- M295 widget tests for active borders + goals one-line on 320dp, light/dark.
- Existing M260/M274/M277/M283/M285 tests and manual Android screenshots at 320/393dp plus large font.
- PR is review-only until checks pass; no APK, main merge, Firebase deploy or SQLCipher activation from this PR.
