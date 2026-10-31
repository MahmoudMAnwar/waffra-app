# M335: AI/SMS/OCR/Ask Waffra deep QA audit (DRAFT)

## Production status
- **No SQLCipher production cutover**, no change to migration flags or production finance authority.
- **Not production certified**: Android physical device accuracy, latency and crash/ANR telemetry still need direct evidence.
- Work is isolated in PR #324; merge is blocked until every relevant exact-HEAD workflow has succeeded (except the explicitly skipped M268) and manual device acceptance is documented.

## Observed user failures
1. Three Al Rajhi POS messages were previously returned as an incorrect count or amount; exact expected values: SAR 4.50, SAR 10.00, SAR 4.00, total SAR 18.50.
2. Emirati AED debit of 136.00 misinterpreted or presented without amount and incorrect currency semantics; 1001 is the account suffix and 4857.96 AED is the balance.
3. A slow native GGUF warm-up blocked SMS/gallery, with a modal progress indicator and poor Qwen extraction.
4. A flat category dropdown listed unrelated main and subcategories and overflowed the review UI.
5. A screenshot timestamp could become a generated transaction title.
6. Ask Waffra could forward irrelevant questions to Qwen without consistent localized scope handling.

## Root causes / static code review
- The app relied on Qwen3-0.6B inference before opening SMS/OCR, although deterministic parsers were already available and more reliable for known bank templates.
- The AI read-only result verifier correctly fails closed on unsupported currencies and uncertain amounts; this is a security requirement, not permission to silently save only the title.
- OCR uses local Tesseract (ara+eng) and may mix adjacent chat bubbles; no CI proof guarantees pixel/word layout on a physical phone.
- The foreign currency lexer originally required ISO token adjacent to digits, missing code-before-debit-verb bank messages.
- The SMS review form mixed parent headings and leaves in one dropdown rather than enforcing a parent-child selection.
- Ask Waffra's directly recorded numeric answers were verified, but open-ended question scope was not checked before model inference.

## Remediations in this PR
- Analyze confidently parsed SAR SMS without Qwen; all results enter explicit finance review. On ambiguous messages, optional local Qwen may add suggestions but can never authorize a ledger write.
- Extract image text using OCR before optional model inference; known bank image actions and receipts use deterministic review immediately. OCR never silently commits a transaction.
- Recognize foreign code-before-debit-verb format, extract only constrained source amount for review, exclude balance/account suffix; reject foreign-as-SAR ledger writes.
- Main then child searchable category selectors in both bulk SMS review and single-entry/manual/OCR flow; check child assignment on save.
- Reject unrelated Ask Waffra prompts in Arabic/English before accessing summaries or Qwen, and recheck in the finance-coach helper.
- Treat chat timestamps as screenshot metadata, never as merchant.
- Preserve cancel/timeouts; don't advertise physical performance that has not been measured.

## Acceptance matrix (automatic + device QA)
| Scenario | Expected result | Evidence |
| --- | --- | --- |
| Al Rajhi three bubbles | Exactly 3 expense suggestions, amounts 4.50/10.00/4.00 SAR, sum 18.50 | M335 regression test (OCR text fixture) |
| Emirati debit | AED 136.00 source units; account 1001 and balance 4857.96 not booked | M335 regression test |
| Unrelated Arabic/English questions | Single localized explanation of Ask Waffra's financial scope; no Qwen call | M335 scope test |
| Valid finance question | Verified recorded-answer or constrained finance model; no fabricated cash | M333 + M335 |
| Parent category changed | Child selection resets; child list belongs only to selected parent | Code + M335 source test; physical UI check pending |
| Qwen missing or deleted | SMS text and local OCR review available; finance writes still verified and user-confirmed | M324 + M335 |
| SMS paste latency on physical Android | No GGUF startup for straightforward SMS; no ANR while typing/pasting | **Device QA pending** |
| Tesseract image recognition on physical Android | No accidental chat timestamp merchant, no 6-for-3 split; measure recognition latency | **Device QA pending** |
| Security | No SQLCipher cutover, no cloud image upload, no guessed FX or silent ledger write | Exact SHA CI + code review |

## Follow-up / excluded
- End-to-end physical Android evidence (real gallery image pixel recognition, warm start and cold start latency, cancellation, low-memory tests) cannot be inferred from Flutter unit tests.
- Native GGUF loading can still be slow when a user explicitly chooses AI advice. The correct next step is device profiling and testing a model-quality benchmark before swapping model binaries.
- Foreign currency persistence requires explicit per-transaction currency provenance and a separate reviewed ledger schema change; this PR will not relabel AED as SAR.
