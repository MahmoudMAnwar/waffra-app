# M283 — App-wide compact borders, intelligent tools positioning, Saudi greetings and back navigation

Based on **M282 combined PR #282** HEAD `d8661452b1751d023bcc1b07bcb2fd68c93ea4d5`; this PR targets M282, not main. All prior M274–M282 work remains in ancestry.

## Changes applied
- Shared `WaffraActionLayout` horizontal padding reduces 18→10 logical pixels and vertical padding 12→10, while maintaining 52dp minimum tap targets (retained for backward compatibility). Borders remain centered on AR/EN labels; no forced full-width buttons. Existing forms and dialogs can grow vertically with accessibility text.
- Monthly budget **"تحديد الميزانية"** has a compact `TextButton.icon` and `LayoutBuilder` that switches to two lines when narrow or text-scaled, preventing collision with the monthly title.
- Smart Tools hero no longer explains how accordion sections behave. A short AR/EN user-facing description replaces it; hero and accordion padding are tightened.
- On tapping an accordion, `Scrollable.ensureVisible` moves the active section toward the **top** after the expansion animation, with stable GlobalKeys, cancellation on new selection, and reduced-motion support.
- Back from account avatar/settings or another footer tab returns to **Home**, not exit dialog. The app exits on **two system-back presses within 2.5 seconds** while on Home; one back shows the existing footer notice. Explicit header back also returns Home. No finance, widget or SQLCipher routing altered.
- Arabic greetings rotate each cold app start across five Saudi alternatives. Gender-specific grammatical inflections are used for explicitly female/male profiles, neutral when unknown. English has separate natural rotating greetings. Small independent SharedPreferences **UI-only counter** runs only after source guards pass; no bank/financial values involved.

## Acceptance
- M283 widget tests cover real accordion scroll to top, reduced-motion, AR/EN, greetings, compact sizing and double-back policy.
- Full Flutter suite and existing M268/M277/M278 regressions run on PR exact SHA.
- Manual visual/physical Android checks still needed: 320/360/393/430dp, text scaling 100/200%, keyboard shown/hidden, fullscreen/gesture and three-button navigation, Arabic RTL/English LTR, light/dark, account navigation, two back presses and app cold starts.
- **NO production SQLCipher cutover, no main merge, no signed APK claimed before combined M282 CI and physical-device checks.**
