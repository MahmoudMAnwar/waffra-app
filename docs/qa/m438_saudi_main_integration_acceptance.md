# M438 — owner-requested Saudi edition and + overlay integration into main

Source: cherry-picked, reconciled *functional diffs* of PR #350 (M415) and PR #351 (M416) on main SHA `9c68bf1e1ba1eb73bf8ec240b5c790f58421215e` after the merged SMS PR #356.

## UI acceptance
- Home, Goals, Recurring, Categories + menus: full-screen translucent Blur covers app bar/body/footer, menu remains accessible, outside/back closes without finance writes, RTL/LTR, Android three buttons safe.
- Saudi first start: **no location permission or prompt**, and no country/location onboarding; keep existing stored country preference intact, do not remove old finance.
- OCR / receipt image-to-transaction import: entry points disabled; previously attached images retain their viewer.
- Ask Waffra: preselected offline questions on verified finance (income, expense, categories and named budgets), clear resets selection; no free-text Qwen network/chat. Preserve foreign bank SMS parsing locally and independently opted-in redacted cloud suggestions from merged #355.
- National Saudi 05 mobile field (10 digits) and app SAR presentation, no country flags/prefix picker. Legacy Google migration path unchanged; currency converter in Tools remains enabled.

## Before merge and owner APK
- Exact-head Flutter analyze/full Dart+Python tests and independent GitHub Actions gates must pass.
- Signed main APK must be built from the merge SHA, with release notes/receipt. Not proof of device safety.
- Owner physical Android test: existing local finance/Google data, SMS first-consent and installation-month history, no location prompt, no OCR action, Ask Waffra presets, full blur/Back, Tools converter, budget/goal wallet balances.
