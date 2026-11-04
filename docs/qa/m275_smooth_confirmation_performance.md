# M275 — Smooth financial confirmations and production regression tests

## Implemented and why

- The home finance writer now displays one lightweight, repaint-isolated progress
  surface during confirmed manual transaction/category/goal/recurring writes.
  An initial Flutter frame paints before async work begins.
- The indicator is driven by the **actual durable save Future**, never a timer
  that says success before storage. Both successful and failing calls always
  release their state in a `finally`; overlapping independent writes cannot
  hide each other's progress prematurely.
- The Home loading surface has no backdrop blur or costly full-Home animation,
  uses 170ms entry/130ms exit easing, blocks accidental repeated taps,
  and honors the OS Reduce Motion preference.
- Confirmed single and bulk bank SMS writes use the same tracked loading state.
  The 100-SMS review sheet separately displays inline save progress because it
  remains a modal above the Home surface.
- Parsing `20..100` bank SMS messages occurs in a Flutter background isolate.
  The single-message parser remains the source of truth, so the displayed values,
  classifications and deduplication rules must be identical.
- Manual editing cannot claim success after a failed financial commit:
  the screen restores the prior transactions/merchant corrections and displays
  an error. SMS hash errors are reported distinctly rather than pretending that
  the whole financial write failed.
- A synchronous tap latch inside the manual-entry confirmation prevents duplicate
  submissions before a bottom sheet finishes closing.

## Added automated acceptance

P0: loader paints before writer, disappears on success, disappears on rejected
write, preserves pending count across overlapping futures, blocks repeated
confirmation taps, and 100-item isolated SMS parsing equals direct parsing.
P1: Reduce Motion eliminates loading animations.
Source-wiring test: all main confirmation paths use the shared protection.

## Follow-on profile-mode measurement (not falsely certified in this PR)

Capture cold and warm Android profile-mode traces for 1, 20 and 100 messages,
including frame build/raster timings, database commit duration, time-to-first
feedback and input responsiveness. Investigate any recurring frames over the
16.7ms target for 60Hz phones, rather than adding fixed waits or timing tests
that only measure CI runner performance. Validate Android lifecycle, confirmed
save failure and canceled biometric prompts separately.

## Safety / release

All actions remain source-authorized and durable before success messages. No
finance schema changes or migrations; no inflation of displayed balances, app
theme changes or interaction delays. Flutter tests in this PR run in the normal
signed-APK release suite; the PR must pass independent checks before merging.
