# M417 — Google Play SMS declaration submission packet

Status: **DRAFT — prepare now, NOT submitted, NOT approved, NOT release-ready**.
Updated 2026-11-03. Owner-approved scope is PR #352 only. The base M416 and other active work are separate.

## Google Play policy route

- Select the supported **SMS-based money management** exception, described by Google as "apps that track and manage budget".
- Request only `android.permission.READ_SMS` (optional bounded history import) and `android.permission.RECEIVE_SMS` (bank messages arriving after consent). Do not request SEND_SMS, READ_CALL_LOG, READ_CONTACTS or accessibility privileges.
- Google approval is **case-by-case**; this exception is not the same as being an SMS default handler, and the user's Android runtime approval does not constitute Play approval.
- The form appears in Play Console as part of adding a release with the relevant Android App Bundle (`.aab`). It can affect **internal, closed or open testing** releases, not only production.
- Google requires core-function declaration, review instructions, a **real functionality demonstration video**, and safe test access when behind login. Extended review can take several weeks.

## Proposed Play Console declaration answer — accurate only for current M417 candidate

**Core purpose:**
Waffra is a personal money-management and budgeting app for Saudi users. Its user-facing bank-message feature detects incoming banking transaction SMS, extracts draft expense/income details locally, and automatically records high-confidence transactions into a private ledger under explicit standing consent. Uncertain messages require review. Manual and user-shared transaction entry remain available.

**Why READ_SMS is needed:**
After the user expressly opts in, Waffra checks a bounded sample of recent inbox messages to discover qualifying bank-transaction notifications, deduplicate previously imported banking entries, and suggest categorized income/expense records. A copy/paste alternative cannot provide optional automatic historical bank transaction discovery.

**Why RECEIVE_SMS is needed:**
With explicit consent, Waffra detects qualifying financial SMS as they arrive without requiring the user to copy each bank SMS. The receiver does not create ledger entries; the scheduled finance worker saves only strongly verified transactions under explicit opt-in and sends a saved notification after confirmation. Uncertain entries are held for review.

**Minimum access, data safeguards:**
Bank/financial matching and exclusion of OTP, personal and non-financial messages happen on the device. Matched candidates are staged in a bounded AES-GCM encrypted local queue backed by Android Keystore. SMS permission by itself never sends bank SMS to an AI provider. Only after a separate optional cloud-processing agreement may locally redacted financial content be processed by the Firebase/OpenRouter backend. This separate flow is feature-flagged OFF until real project activation, security validation and privacy review. The user may deny SMS access and still use manual/paste flows. A separate prominent standing auto-save consent is required for automatic financial postings. Receiving any individual SMS alone is insufficient.

**Why an alternative is insufficient for this specific feature:**
Share Sheet and manual paste remain supported as fallbacks, but neither can trigger continuous detection of *new* transaction SMS or scan prior SMS for an opt-in banking history. An OTP-specific SMS Retriever API is not designed to retrieve arbitrary bank transaction notifications.

These statements describe the **candidate implementation** and must be independently validated against the final signed AAB, including merged-manifest analysis and network/privacy tests, *before copying them into Google's form*.

## Review access instructions (adapt to final signed build)

1. Install the provided signed Play test build on an Android phone with SMS reception.
2. On initial app opening, observe the Arabic/English prominent disclosure and two choices: **Allow bank SMS access** or **Not now**.
3. Choose Allow; inspect the Android READ_SMS / RECEIVE_SMS permission dialog and grant it.
4. Complete sign-in using the separate reviewer account supplied in Play Console's App access section, or the supported guest flow, if suitable.
5. Send a **synthetic**, non-real bank-SMS sample to the test phone from a test sender. Example action: "Purchase Card — Amount: SAR 12.50 — Merchant: TEST CAFE — 2026-11-03 09:30". Never share real bank messages or OTP.
6. With a real signed test build, demonstrate high-confidence automatic posting and an external saved notification, followed by an exactly-once ledger entry. Separately show uncertain SMS review.
7. Restart and re-send identical test SMS; inspect duplicate handling. Show manual transaction entry still operates after declining/revoking access.
8. Provide reviewer instructions for a pre-seeded demo account and test phone if inbound SMS is not feasible in Google's test environment. **Do not invent test credentials**.

**Important:** Some review steps (especially actual Android receiver behavior, durable queue replay, and account handling) are not yet physically verified. Record a real video from a signed Android build only after these tests pass.

## Required video — storyboard (do not fake it)

- 0:00–0:10: App identity and automatic SMS expense-tracking purpose.
- 0:10–0:25: First-launch disclosure, Allow/Not now, Android permission dialog.
- 0:25–0:45: Synthetic financial SMS arrives; application surfaces transaction proposal.
- 0:45–1:05: Income/expense, amount, category and budget verified; save to ledger.
- 1:05–1:20: Duplicate avoidance, privacy and how to continue with manual import if denied.
- Show account access if Google requires sign-in.
- Publish actual screen recording to an **unlisted** accessible YouTube link or a shareable MP4. Google prefers YouTube. Do not supply example or conceptual animation as proof.

## Play Console path — owner action

1. Sign in at https://play.google.com/console/ and create/complete the Waffra app entry if it does not yet exist.
2. Finish **App content** entries: public privacy policy URL, Data safety reflecting actual SDK/backend flows, target audience, and App access test account. Clearly describe automatic bank SMS tracking in the Play listing.
3. After compiling and testing the approved candidate, create a release (prefer a controlled test track, avoiding public Production) and upload a signed **AAB** whose merged manifest contains only declared permissions.
4. Open **App content → Permissions declaration form** (or the warning surfaced during release creation) and select **SMS-based money management**.
5. Explain READ_SMS and RECEIVE_SMS using the text above, provide real reviewer steps, attach a real feature demo video and any necessary test-login instructions.
6. Complete declarations and **submit the release for review** via Play Console web interface. A first-time sensitive-permission review cannot be reliably initiated solely via the Google Play Publishing API.
7. Check **Policy status** and the owner/contact emails. If rejected, preserve the private PR and adjust the bundle/disclosure/declaration based on Google's stated reason; do not circumvent the policy.
8. Avoid submitting another release during the permission review unless needed; it may extend the review period. A **testing release is not public Production**. Check track restrictions and availability before rollout.

## Nonnegotiable review and release gates

- [ ] Confirm developer account and verified Play Console app entry for Waffra (not assumed).
- [ ] Final signed AAB with manifest permissions inspected and real runtime behavior validated.
- [ ] Recorded demo, public privacy policy (Arabic and English), actual review test-login access.
- [ ] Full PR #352 CI green on exact head and SDK/Android emulator/physical device tests.
- [ ] Validate sender spoofing, OTP filtering, financial false positives and number normalization.
- [ ] Verify per-account isolation: current encrypted queue is **device-local** and should not leak bank candidates across login/logout or another profile; fix before any release.
- [ ] Verify permission revocation, the meaning of Not now, data deletion and any stored message retention.
- [ ] Verify SMS import does not change a balance without user-approved finance writer; existing ledger, goals, budgets and backup survive upgrades.
- [ ] Reconcile overlapping code with PRs #348–#351 and rerun tests on the combined SHA.
- [ ] Complete Google Play SMS exception approval and revised Play Data safety.

## Source links

- Google Play SMS/Call Log exceptions: https://support.google.com/googleplay/android-developer/answer/10208820
- Play Console permissions declaration: https://support.google.com/googleplay/android-developer/answer/9214102
- Preparing app for review: https://support.google.com/googleplay/android-developer/answer/9859455
- Android sensitive permissions policy: https://support.google.com/googleplay/android-developer/answer/16558241
- Testing tracks: https://support.google.com/googleplay/android-developer/answer/9845334

**Owner action required:** Play Console account sign-in, app creation if needed, upload signed AAB, actual video and real test credentials, form certification and final Play submission. Nothing in this document constitutes Google's consent or approval.
