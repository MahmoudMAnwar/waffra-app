# M631 — Login & biometric verified-finance prewarm

Issue: #545. Base: merged #544 main. Draft PR: pending.

## Owner-reported symptoms
- Repeated phone login remains on the progress button until verification and profile persistence finish.
- Fingerprint completes, but the prior stage is retained until Home loads encrypted source, account balances, and ledger.

## User-proposed experiments and chosen safe implementation
1. Prewarm only the SQLCipher authority BIND after actual owner-verified authentication (or restored-session startup verification), concurrently with permission/biometric staging. Transfer a single owner/session-scoped open binding into Home on unlock; never open duplicate connections for this handoff. Close unused or failed binds and never adopt on a new owner/session.
2. Do not mount a fully functional Home or perform financial ledger reads before mandatory biometric authorization. The original suggestion to mount an Offstage Home while locked would prematurely run widgets/native receivers and financial reads. Likewise, `setState(()=>ready=true)` before verified bank/account balances would violate the previously approved authentic first Home contract and flash wrong numbers. Preserve the bounded 15-second verified account wait and real fail-closed retry.
3. Defer optional widget refresh, reminder scheduling and tour setup until after the verified first Home paint; keep native SMS resume after that Home and owner checks.
4. Measure the actual delays with profile-only stage logs before declaring any performance win.

## Required tests / merge gate
- Reuse one binding across credential+biometric handoff; bind failure retries within Home; no parallel duplicate finance opener.
- Signout before biometric, logout/relogin, owner change and Home disposal close unused/adopted connections without leaking previous owner state.
- No financial accounts, balance, ledger, widget, SMS or data-side effects before allowed session.
- Existing M622 (one authentic financial Home), M624 native SMS, M627 session cleanup and M630 integrity regression must pass.
- Exact-head CI and Android profile APK: fresh install, biometric, logout/relogin, restored session, two-device old data retention, p95 first-frame and tap latency.

Status: **Recorded before code**. No Android performance acceptance yet.
