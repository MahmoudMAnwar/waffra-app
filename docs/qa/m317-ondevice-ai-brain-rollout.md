# M317–M319 Local AI brain: staged acceptance

## Approved five features
1. Bank SMS: same local model suggests amount, source currency, direction and merchant for each independent completed transaction.
2. Receipt/screenshot OCR: run Arabic+English Tesseract first, then model on recognized text. A screenshot with five independent bank actions can produce five *review* items. A store receipt with five products but one payment remains one transaction.
3. Ask Waffra: answer questions based on aggregate verified finance facts.
4. Financial analysis: describe income/expense trends based on aggregate source data.
5. Savings suggestions: suggest actions based on available recorded facts; never fabricate savings or investment returns.

## Implementation in this draft
- Core: lib/waffra_ai_finance_brain.dart
- Financial coach: lib/waffra_ai_finance_coach.dart
- GGUF adapter: lib/waffra_ondevice_qwen.dart
- Tests: test/m317_ai_finance_brain_test.dart
- Native dependency pinned: llamadart 0.8.24 with llama.cpp-only hook.

The source AI text inference is injected. These service classes do not contain any database, write, Firebase inference or credential dependency. Opt-in AI buttons are now wired into Tools / Ask Waffra / financial analysis / saving suggestions, the SMS review sheet and the OCR image path. User-facing AI is disabled until an explicit model download and verified local load. Existing deterministic SMS/OCR behavior remains the fallback until accepted.

## User opt-in and model integrity
The approximately 484 MB Qwen3-0.6B-Q4_K_M.gguf file is not shipped in the APK, downloaded at login or fetched silently. A user-facing opt-in is required. The public model is downloaded from the pinned smarttasks Hugging Face URL only when explicitly requested and SHA-256 checked before loading. The sha256 pin is 3479875d3e4c726f7a20b2181f5e1536aefe9925f284f9ae9997a39a7e0d8dc9. All bank messages, OCR text, source records and prompts remain on-device.

## Finance safety rules
The model may suggest but can NEVER commit a financial transaction. Every proposed action must quote a literal span of the original OCR/SMS input. Its amount and currency must be anchored in that span; unsupported, foreign, ambiguous or mixed currency always requires review. Balances, cards, references, tax and receipt product lines are not independent payments. Broken JSON or duplicated evidence is rejected as a batch, not partially saved.

The financial coach sees only verified, scoped **integer minor units** aggregated by expense category. It cannot access raw private SMS, receipts, GPS, account identifiers, the database vault, writer or cloud function.

## Blocking acceptance gates
- Exact latest HEAD: Dart analyze, M317 core tests and all finance/SQLCipher/legacy tests.
- Confirm llamadart native runtime compatibility with Android build, iOS target and physical device memory/CPU use.
- Model checksum failure, interrupted download, low storage, offline reboot and logout/A-B account isolation tests.
- Complete on-device UI acceptance tests, progress/cancel/retry flows and visual QA for the opt-in UI now implemented in bank SMS, OCR multiple-action review, Ask Waffra, analysis and savings sections.
- Every transaction is explicitly confirmed by user and independently committed through existing encrypted authoritative writer.
- Physical Android and iOS proof, then merged-main smoke tests; NO production cutover or APK release before those gates.
