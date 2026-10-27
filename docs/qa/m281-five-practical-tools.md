# M281 — five practical Waffra tools: delivery and release boundaries

All five tools live under the existing **Smart Tools footer tab** (a new "Additional finance tools" entry). Their input is a frozen in-memory copy of the verified Home read-only finance view. They never mutate ledger, SQLCipher, SharedPreferences or Firestore.

| Feature | Implemented today | Outstanding before full release |
| --- | --- | --- |
| Data Health Center | Duplicate ID, suspected duplicate transactions within 48h, missing category, malformed amount; no automatic edits | Link warning to actual transaction details; category correction with confirmed writer and undo; receipt & cloud integrity indicators |
| Advanced transaction search | Local keyword on title/category, amount string, income vs expense, inclusive date range, reusable pure amount/attachment/notes filters in engine | Home must pass notes and attachment flags from the verified encrypted projection before claiming these are live user-visible filter fields; saved preferences require encrypted writer |
| Receipt review assistant | Image picker camera/gallery plus explicit merchant/amount/date validation, no auto-save | Real on-device OCR plugin and on-device performance/privacy testing; attachment must be committed to verified encrypted vault with explicit confirm; no fake OCR claims |
| Monthly financial close | Halala-accurate monthly income/expenses/count, user-supplied opening balance, actual-vs-expected difference, months navigation | Persist user-approved close history only in verified SQLCipher, validate imported legacy balances and controlled reopening/reconciliation |
| Safe diagnostics | Show/copy code-only allowlist, no logs with bank SMS, monetary data, paths or PII | Opt-in crash diagnostics and secure support transport only after validated consent and encrypted/privacy review |

## Quality requirements
- Arabic/English, system dark/light and RTL/LTR, scalable text and touch targets.
- No extra Home cards; the Tools tab contains one navigation tile.
- All calculations immutable and read-only; a preview is not a transaction.
- No bank integration, SMS inbox permission, implicit cloud upload or destructive operations.
- Feature-engine and widget tests + complete Flutter regression run on PR exact HEAD.
- Avoid claiming signed APK/iOS launch, real receipt OCR or persistent month-close history until actually implemented and tested.

## Integration with M274–M280
Existing PRs #274–#280 have independent commits; none is the combined candidate.
Before any main merge, reproduce all changes on one combined branch, resolve overlapping footer/tool/OS/inset/haptic/finance changes, rerun the entire regression and M279 security jobs on one SHA, and verify a signed Android artifact + two real phones. iPhone requires tracked native Runner and physical certification.

**Status: feature panels implemented for review; full OCR, encrypted close history, notes and attachment source binding still open.**
