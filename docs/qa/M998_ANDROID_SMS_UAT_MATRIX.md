# M998 — Android real-device SMS acceptance matrix (Issue #708)

**Status: NOT CERTIFIED / NOT EXECUTED ON A PHYSICAL DEVICE.** Automated CI and synthetic Flutter fixtures **cannot** validate Android carrier delivery, OS SMS permissions, SQLCipher migration, actual bank wording, biometric lock, native receiver, performance/jank or the user's older backup. Never mark any row Pass without device evidence.

| ID | Device / condition | Required verification | Status |
|---|---|---|---|
| D01 | Clean test Android phone, SMS permission granted | New genuine bank SMS appears once in owner-scoped encrypted review; no spontaneous ledger write | Not run |
| D02 | SMS permission denied / later granted | No silent history access or fake success, user-visible recovery | Not run |
| D03 | 17 bank/digital bank/wallet sender types | Sender allowlist does not imply account ownership; user explicitly selects exact account | Not run |
| D04 | Barq / EnjazPay / AlinmaPay actual messages | Digital wallet does not populate masked bank account last four | Not run |
| D05 | Existing bank account last four | Editable verified user-linked suffix carried into income/expense typed templates only | Not run |
| D06 | Non-financial OTP from newly installed app | Secure automatic exclusion; no unrelated finance record or OTP shown as merchant | Not run |
| D07 | Financial text plus OTP, two finance events | Human review required; no whole-message ACK or automatic money | Not run |
| D08 | Pending → posted reference, same exact sender/account/SAR | Advisory possible settlement shown; no automatic duplicate charge | Not run |
| D09 | Pending → posted with different sender/account/amount | Never link as same operation | Not run |
| D10 | Identical SMS ID after restart + fresh distinct SMS with same evidence | Same native ID not duplicate; second linked provisionally, never auto removed | Not run |
| D11 | Refund, cancellation, failed, chargeback | Clear non-definitive UI labels; refund never treated as fresh income automatically | Not run |
| D12 | Real bank fees, VAT, SAR/USD mix, balances, references | Only principal identified for SAR; foreign/unknown and mixed evidence remain review-only | Not run |
| D13 | Save/edit a sender keyword rule | Reclassify affected pending rows, preserve unaffected ones; exclusions still require safe verified native ACK | Not run |
| D14 | Sender review modal open during incoming message/rule edit | Live counts, calendar and selections update without reset of user context | Not run |
| D15 | 100, 1000, 2000 real queued messages | Measure UI frame raster/build jank, isolate duration, memory, binder responsiveness; smooth scrolling | Not run |
| D16 | Actual Saudi merchant variants in purchase SMS | Correct safe merchant and Arabic category suggestions; never learn raw account, OTP or merchant without user confirmation | Not run |
| D17 | Existing owner's old backup from pre-account version | Restore once, preserve transactions and totals without duplicate posting, confirm device-safe rollback | Not run |
| D18 | Logout/login and switch to a second owner | No decrypted sender/rules/cache or cross-restart advisory leakage across owners | Not run |
| D19 | Native notification / history re-sync and app background | Same account scoped encrypted review, bounded history, no unexpected re-scan | Not run |
| D20 | RTL, number directions, snackbar and + button | Previously approved designs intact; amount baseline and sender swipe verified | Not run |

**Automated CI gates:** M550 approved behavior preflight; M946 three real Flutter shards; M103 full same-SHA; Waffra Full Offline Finance & UI; native Kotlin tests as applicable. All must succeed at the **final commit**; stale/cancelled workflows are not passes.

**Required evidence before Ready for Review or merge:** record Android model/OS, app commit hash, pass/fail, anonymized screenshots (no real OTP/account text), Flutter profile stopwatch and frame logs, any failed case and PR fix. Protect the spouse's legacy data: perform compatibility testing on a spare device or safe backup, not direct in-place modification. 
