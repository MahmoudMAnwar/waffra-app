# M354 — Android transaction bottom-sheet navigation overlap

**Issue:** On Android phones using the three-button system navigation bar, the manual expense/income editor's **Confirm and Save** control was positioned beneath the system buttons. The same editor is reused for SMS and OCR review.

## Cause and patch

Previously the editor used `viewInsets.bottom + 20` as a fixed scrolling bottom padding. `viewInsets.bottom` measures the **keyboard**, not the Android navigation-bar safe region when the keyboard is hidden. The entire form and confirmation button also belonged to one tall `SingleChildScrollView`, making the action hard to reach on small displays.

- The shared `WaffraEntrySheetSafeLayout` combines `SafeArea(top:false)` with an explicit `viewInsets.bottom` keyboard offset. The safe area reserves space for either three-button navigation or the gesture bar. The keyboard offset is applied separately; neither value is replaced with guessed device-specific pixels.
- Confirm/Save is in a **pinned footer** above the system region. Only the form fields scroll under it, including when the on-screen keyboard is open or accessibility font scaling is enabled.
- Applied to `entrySheet`, the shared editing path for manual income/expenses, pasted SMS and OCR screenshot/receipt review. All financial validation and save callbacks stay unchanged.
- The route uses `useSafeArea:true` to preserve the remaining display safe areas too.
- Dedicated regression `test/m354_android_transaction_sheet_nav_insets_test.dart` verifies four representative viewport configurations, including 48dp three-button, 24dp gestures, keyboard 300dp, and large text; checks button position and that scrolling the form never moves the pinned confirmation.

## Release check

In an Android signed QA APK, test both gesture mode and three-button mode, including Samsung navigation settings, display size/font scale, portrait, keyboard open, tall forms, SMS and OCR entry, validation errors and successful confirmation. Check that there are no `RenderFlex` overflows or buttons overlapped by Android system navigation. Confirm that the previously installed app's local finance data is still present after an **in-place** update.

This source patch and regression are **not** physical-device certification or a confirmed passing CI result. Do not merge to `main` or distribute a data-bearing upgrade solely on source review.
