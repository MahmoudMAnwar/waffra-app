# M258 – Finance pull-refresh scroll settle (QA-only)

Observed on Android build #706 (M257): a successful pull refresh can leave
Savings Goals visually displaced far below the app bar until the user manually
scrolls back up. The verified finance read itself succeeds.

## Scope
- Existing verified read / single-flight / bounded recheck is unchanged.
- Dashboard, Categories, Goals and Recurring lists use stable tab-specific
  ScrollControllers and clamped-but-always-scrollable physics.
- Only after the authoritative read completes and the rebuilt frame has
  finished, reset the original, still-mounted list to its minimum scroll extent.
- Never reset a tab the user left, a disposed list or a fail-closed recovery UI.
- No database migration, source activation, SMS persistence or schema change.

## Evidence required before main / release
1. Flutter widget test for restored offset, abandoned tab, and failed read.
2. M258 source wiring regression for all four finance tabs.
3. Same-SHA full Flutter / financial / native Android CI checks.
4. Physical-phone visual retest of empty and populated lists in AR and EN,
   including rapid repeated refresh, tab navigation during loading, small
   scrolls, and network-disabled conditions.
5. SQLCipher hardware/source certification separately remains NO-GO; green
   UI checks are never SQLCipher cutover authority.

This change is layered on M257 QA branch. Do not merge the full SQLCipher
stack to main or declare production readiness solely because M258 is green.
