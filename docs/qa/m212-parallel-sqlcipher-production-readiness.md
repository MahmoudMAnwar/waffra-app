# M212 — Four parallel SQLCipher production-readiness workstreams

**Status: QA / staged integration only; production NO-GO.**
Requested source of truth: one encrypted SQLCipher database for all **financial**
state, including the original complete bank SMS text, budgets, goals, recurring,
category deletion bins and invoice bytes. Ordinary nonfinancial UI preferences
may remain in device settings, not user banking data.

## Track 1: audit and wire the 24 independent finance routes

- The source authority implements/enforces `WaffraFinanceRoute` dispatch, but
  this does not certify live Home/Widget access on a phone.
- **M212** connects the previously independent
  `WaffraEncryptedFullFinanceReset` through
  `WaffraVerifiedEncryptedFinanceBridge` →
  `WaffraEncryptedFinanceSession` →
  `WaffraVerifiedFinanceAuthority.resetVerifiedFinance` at the dedicated
  `fullFinanceReset` route. Legacy resets are not allowed; source witness,
  fresh snapshot, archived matching backup, biometric and explicit consent
  are mandatory. Reset never revokes the app sign-in account or deletes
  external backups; its external source marker and key are retained.
- Ledger-sensitive route negatives run in Flutter. M188 runs the standalone
  authenticated SQLCipher reset and receipt/image deletion tests. A signed
  device route trace for all 24 still requires separate real-world evidence.
- The existing list of 24 is in
  `docs/qa/m181-live-24-route-evidence-matrix.md`. Use observed audit
  evidence, never synthesize `verifiedRoutes` from the enum.

## Track 2: crash-safe cutover and recovery

- M212 cold-open tests exercise `prepared`, `verified`, `active` phases
  of the encrypted journal, missing external activation marker, missing
  recovered key and incomplete app/widget routing. These cases must fail
  closed rather than fall back to a new/empty legacy account.
- The two-witness source activation and release decision remain disabled.
  `automaticallyActivateSqlCipher => false` remains unchanged.
- A production coordinator still needs atomic native source switch,
  OS-keystore persistent key attestation, crash-injection at every write
  boundary, and revalidation of receipt BLOBs and custom goals.

## Track 3: *two physical Android* devices

The existing read-only M189 probe is ready to run on a laptop with **two
distinct connected and authorized physical Android phones**:

```sh
python3 scripts/qa/m189_physical_device_source_probe.py --check-contract
adb devices -l
python3 scripts/qa/m189_physical_device_source_probe.py \
  --capture --output ./private-waffra-physical-evidence.json
```

Never upload private device logs, bank messages, key material or Android
serials to GitHub. M189 only proves two non-emulated devices can see the
installed package; it intentionally reports **zero** verified 24-route
executions, zero OS-backed recovery attestations and release NO-GO.

Remaining manual/instrumented proofs on **each** phone: installed APK SHA
and signing certificate match; create/enter test-only finance records; quit
both Flutter engines; force-stop/reopen Home and quick-capture Widget; verify
all transaction/recurring/category/goal/receipt data survives and matches
the SQLCipher source; wrong-key and interrupted-migration refusal; encrypted
portable backup exported on A and restored on B with full invoice-byte parity;
verified account deletion. This work cannot be performed on GitHub-hosted
emulators or declared complete without the user's two physical devices.

## Track 4: APK from main after all tests

The existing `.github/workflows/android.yml` already runs the mandatory
Flutter/Python suite and independent same-SHA checks **before** a signed
ARM64 build. It verifies the compiled APK's embedded branch/commit/run,
signing certificate and SHA256 receipt, and publishes its artifact as the
**final** step only when all gates have succeeded.

M212 also updates `docs/release/WAFFRA_APPROVED_CHANGES.txt` on the same
reviewed commit as the code. This fixes a real main APK publication failure:
run 40180513182 passed tests/build/signature and identity checks, but the
release-notes freshness gate correctly blocked uploading the APK because
that file had not been updated since older code.

A passing main APK artifact is **QA only**; it is not an activated SQLCipher
source, Play release, or proof of physical-device testing.

## Remaining blockers

- Observe every actual 24/24 app+widget route against one active source.
- Independently witness the two-key/marker crash-safe transition and recovery.
- Validate external receipt BLOBs and custom goal suggestions throughout
  migration and restore; do not erase or silently exclude any user finance.
- Finish two real Android phone OS-backed-key + backup/restore acceptance,
  signed APK install and user GO.

**Never** enable customer cutover from a test flag, forge independent
approval, switch source markers, use real bank SMS in CI or publish Google Play
from this PR.
