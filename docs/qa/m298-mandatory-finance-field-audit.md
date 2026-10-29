# M298: Mandatory-field validation audit and remediation

This PR is isolated from M295–M297 UI/OCR and contains only validation and regression coverage. Base: exact current `main`, after PR #287.

## Validated defects in source

| Workflow | Gap in pre-M298 source | Remediation |
| --- | --- | --- |
| Bank SMS multi-message individual review | Message category selection had neither mandatory marker nor error, and commit validated only title + amount | Require a category present in the current direction's category list; inline "هذا الحقل مطلوب" / English equivalent and block commit |
| Single bank SMS entry | The category was visually displayed using a fallback first option, but commit persisted the stale `category` variable; no mandatory error | Validate the *displayed* chosen category against current valid choices and persist exactly that selection |
| Recurring transaction | `forType(false).first` and income switch `.first` could throw when that direction has no available category. Empty category lacked inline validation | Empty-safe selection; inline required error; block save until a valid category exists; persist the selected category |
| Recurring day of month | Arabic/Persian numerals were parsed at commit but rejected by the validation function | Normalize these digits before checking 1–31, then preserve same conversion on save |

## UI required-field indicators
- Login phone/password, profile gender, and attachment rename must visibly show `*` in Arabic and English; all already had non-empty validation at commit, but were missing the required indicator.
- The required bank-SMS category now also has an asterisk and an inline error; recurring category retains its asterisk and gains the inline gate.

## Existing protections checked; intentionally unchanged

- Manual transaction: required title, positive valid amount, mandatory parent and leaf selection.
- Monthly budget: required positive amount independent of enabled toggle (M296).
- Savings goals: required unique name and positive target.
- Recurring title/amount/day: existing required checks remain.
- Profile onboarding: name, phone, password confirmation and gender required; backup password validated.
- Optional notes and category budget remain optional.
- OCR source: suggestions only; finance entry cannot auto-save without confirmation.

## QA gate

- Unit tests: whitespace/unknown/deleted/category-from-opposite-direction; empty category collections; ASCII/Arabic/Persian days; existing required name and money limits.
- Source-level assertions for inline errors, save gates, visible category persistence, no `.first` crash.
- Regression: existing inline form validation, M297 OCR bridge, M287 OCR, M280 SMS fuzz and bank SMS.
- All independent checks must complete on *exact latest HEAD*. Only then ready/merge.
