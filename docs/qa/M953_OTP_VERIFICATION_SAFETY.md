# M953 / Issue #662: verified app authentication messages (stacked on #658)

## Decision and acceptance

Existing M952 first tranche in #658 remains unchanged. This is a separate correction for current app-authentication SMS arriving in the finance review despite the user-approved safe exclusion policy. The original 20-point axes remain a multi-PR program, not a claim of complete release readiness.

| Path | Source | Executable evidence | Result gate |
|---|---|---|---|
| New English app sender OTP variants | `lib/waffra_bank_sms_facts.dart` + `waffra_sms_local_rules.dart` | M953 English unknown sender regression | Excluded only when independent bank-money evidence absent |
| New Arabic auth code variants | same source | M953 Arabic unknown sender regression | No account guess and no finance posting |
| Mixed posted transaction + OTP | same source | M953 money/OTP regression + M508 | Must **not** be excluded |
| Foreground queue + background WorkManager | `main.dart` verified isolate + `lib/waffra_auto_sms_autopost.part.dart` | M953 shared resolver/ACK code check + M661 native durable exclusion | Native ACK for authentic nonfinancial challenge only, no bank writer |
| Existing Saudi seeds and custom rules | immutable M508 seeds + original user rules | M508, M661 and M953 | Preserve exact seed counts, sender scope and no automatic money writes |
| Every PR run | `scripts/qa/m946_full_app_smoke_matrix.py` | M946 experience shard | Fail closed on missing, skipped, failed or non-executed suites |

**Not certified by host tests:** reception and notification on a real Android device, biometric behavior, real signed APK, owner's legacy encrypted archive/V3–V24 reconciliation, or 10k-row FPS/overflows. These remain pending in Issue #657. Do not touch the spouse's historical archive as a disposable fixture.

**Remaining priority after M953:** old-date transaction editing, performance cleanup of remaining OFFSET queries and full Home snapshot hydration, verified restore ledger parity, and real-device RTL/500–2,000 SMS stress. Treat these as pending until separate code and green exact-head tests.
