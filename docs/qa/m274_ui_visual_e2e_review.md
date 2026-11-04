# M274 — User-facing UI E2E and Golden visual regression

## Scope of this PR

- Nine deterministic Flutter widget UI journeys: five functional footer destinations
  at widths 320, 393 and 600, in both Arabic and English; balance privacy in light
  and dark; and a footer-level error that can be dismissed without hiding navigation.
- Two Android-emulator Flutter-engine integration cases: actual rapid footer taps
  and real hide/reveal interactions with the approved balance card. Synthetic values
  only; this is **not** full logged-in app navigation nor signed production device QA.
- Six real Flutter PNG golden **candidates**, at the stable 393px viewport:
  4 footer snapshots (Arabic/English × light/dark) and 2 balance snapshots
  (Arabic × light/dark). Load the shipped Tajawal font in the screenshot harness.
- GitHub Action builds and runs these tests on PR changes. It records dimensions
  and SHA-256 for each captured PNG and exposes the images for visual design review.
- An approved baseline is NOT auto-replaced. When reviewers commit the 6 approved
  images at `tool/goldens/baselines/`, reruns switch to strict pixel comparison
  (without `--update-goldens`) and block regressions.

## Must not claim yet

First-run green output only proves candidate images were rendered, not visual
correctness against a previous approved build. Until the approved PNG baselines
are checked in, the pixel-comparison gate is **NOT enabled**. Likewise, emulator
UI harnesses do not prove Firebase sign-in, real finance persistence, complete
SMS save, PDF round-trip, or physical-device cold-start durability.

## Follow-on E2E scenario backlog for production freeze

1. Signed exact-main Android fresh install → onboarding → local account →
   add expense → validate category/amount → confirm → Home balance.
2. Edit saved transaction notes while original encrypted bank SMS and receipts
   remain immutable; kill and reopen app, verify both sections.
3. Paste 100 bank SMS, double-tap confirm, force-save failure and retry:
   no duplicates and exact count/balance.
4. Recycle/undo for goals, categories, recurring and attachments with deletion
   timers and a simulated interrupted restore.
5. Export both reports, open viewer, swipe and zoom PDF; Arabic shows approved
   Saudi Riyal artwork, English shows SAR, and values are unchanged.
6. Compare 320px, 393px, tablet and text scaling 100%/175%/200% in both
   languages and themes, then add approved screenshot baselines.
7. Navigate quickly while refresh spinner is visible, resume app, and verify
   scroll settles without manual dragging.

## Release rule

The project's main signed APK workflow already gates on all `flutter test`
failures. The new `test/m274_responsive_ui_journeys_test.dart` joins it
automatically. The separate M274 workflow must also pass before a PR is merged.
The pixel gate becomes strict only after design approval of the frozen PNGs.
