# M303–M306 Twelve-route production hardening register

STACKED DRAFT based on M302 PR #294. Not merged into main; not a production APK or SQLCipher approval.

| Path | Evidence / implementation | State |
| --- | --- | --- |
| 01 Double confirmation | Existing submitTapped latch, locked SMS SHA save, M280 concurrency tests | Regression, device gate |
| 02 Atomic writes and crash recovery | Verified source writer with experimental SQL transaction; real cutover is pending | Release blocker |
| 03 Legacy backup | Authenticated encrypted V1 and V2 restore; migration of older backups/attachments needs device proof | Existing, device gate |
| 04 Account A/B isolation | Sign-out preserves local finance to prevent data loss; proper identity fencing A-to-B not certified | Release blocker, NOT fixed |
| 05 Currency and widget precision | FIX widget now rejects silent sub-halalah rounding; M302 tools improve 0/2/3 decimal formatting | Implemented, tests pending |
| 06 OCR/SMS/manual duplicates | Existing manual duplicate prompt/SMS fingerprint; OCR cross-source matching remains open | Release blocker, NOT fixed |
| 07 Recurring payments | FIX failed paid/postpone commits reload authority and require explicit confirmation | Implemented, tests pending |
| 08 Receipts | Existing private staging and label validation; shared-file/orphan retention needs physical fault testing | Existing, device gate |
| 09 Home/Widget/PDF balance | FIX widget rejects invalid precision. Cross-view same-revision reconciliation remains open | Partial |
| 10 UI performance/save | FIX deletion, edit undo and monthly budget fail closed; existing smooth overlay with reduce-motion | Partial, physical QA needed |
| 11 Arabic/English UI | Existing M277 font scaling/48dp/talkback checks; real keyboard and phone checks open | Regression |
| 12 Permissions | Existing request-on-action camera/gallery/notifications; denial/revocation/reboot checks pending | Regression, device gate |

Other LIVE fixes: legacy transaction delete and undo, transaction edit undo, recurring postpone, recurring paid, and budget save now reconcile from the authoritative finance source after failed acknowledgement. A failed acknowledgement might hide a successful commit: reload rather than blindly replay.

## Mandatory release gates
- Exact newest HEAD all CI for this PR and parent PR #294, plus integrated combined SHA.
- Account A/B isolation across sign-out/login including widget/backup/receipt; never erase a prior owner's local finance automatically.
- Cross-source fingerprint matching between OCR, SMS and manual entry with override proof.
- Old encrypted backup multi-version restore with receipt metadata and original notes.
- Same-revision home, reports, widget and PDF parity including currency display-only 0/2/3 decimals.
- SQLCipher 24-route cutover, interruption recovery and two physical-device encrypted backup/restore.
- Release-signed Google Sign-In and production-mode Android/iOS screen, accessibility and permission tests.
- No physical certification and no production approval from green unit tests alone.
