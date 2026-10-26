# M230 — consolidated SQLCipher Stage 1 and Android #705 refresh QA

This integration candidate combines the independently reviewed **M228 24-route
source preflight** and **M228 guarded-legacy refresh fix** on the same verified
post-M227 main SHA. It does not enable SQLCipher finance source cutover.

Review protections:
- Full cumulative diff allowlist and *each* commit checked against the exact
  main ancestry; merged/unreviewed changes fail.
- Full Flutter suite, ARM64 compile and the existing Android/SQLCipher
  regression workflows run against the proposed head.
- A missing route, OS key, SQL source or immutable cutover witness refuses
  encrypted route binding rather than silently falling back to legacy.
- Android #705 refresh treats *truly absent* guarded-legacy ledger/category
  keys as normal startup does; missing encrypted finance keys remain errors.
- No new signed user APK, production activation or source-marker mutation.

Independent blockers still required:
1. Prove actual 24/24 financial and Widget operations against a verified,
   activated encrypted source; source selection contract tests alone are not enough.
2. Safely migrate/export/restore original bank-SMS side-vault text, receipt
   bytes, protected profile data, and all finance modules with parity checks.
3. Verify OS-keystore re-open, crash rollback, widget concurrency, authenticated
   restore onto **two distinct physical signed Android devices** using synthetic data.
4. Human security/privacy approval of non-auto-activation cutover.

Do not merge into main until release workflow/APK freeze decision is honored,
all exact-head CI checks are green, and outstanding SQLCipher gaps are resolved.
