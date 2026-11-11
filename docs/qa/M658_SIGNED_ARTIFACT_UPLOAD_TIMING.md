# M658 — Main signed artifact upload performance and availability evidence

Issue: https://github.com/MahmoudMAnwar/waffra-app/issues/585
Status: Partial; corrective PR source not yet validated on main.

## Evidence from first main after merged PR #580
- Signed main release SHA: 98dee2028200525bd41c97c9c573dd6f1687a109
- Actual run: https://github.com/MahmoudMAnwar/waffra-app/actions/runs/43093248678
- The owner observed elapsed time above **21 minutes**, worse than prior 18m50s successful baseline #43059887405 and the promised target 14–16 minutes (not supported by measurement).
- Exact-head full Flutter+Python and independent gates succeeded; signed APK/AAB builds and source signature checks each succeeded.
- At >21 minutes, the signed APK job was in `Publish signed QA APK (FINAL step)`; the signed AAB job was in `Upload signed Google Play internal-testing AAB candidate`.
- GitHub then reported **both artifact-upload steps failed**, even though the workflow overall status still showed in-progress during job cleanup. The job log download itself timed out during diagnosis; therefore the *specific transport/storage error code is NOT yet known*. A completed signed APK/AAB binary without published GitHub artifact is NOT delivery success.
- GitHub's official upload-artifact documentation: default gzip compression 6 on large, already compressed files wastes time; compression-level 0 is recommended for speed: https://github.com/actions/upload-artifact. This is a demonstrated configuration inefficiency, **not proof that gzip was the sole failure cause**. Network, artifact quota or platform errors remain possible.

## Bounded code changes
- Do not edit app or finance/source-signing code and do not remove either artifact or its receipts.
- Main matrix build should have a finite timeout, so a hung external publisher cannot silently block forever or be green when no artifact is published.
- Both original `actions/upload-artifact@v4` steps should set `compression-level: 0`, preserve `if-no-files-found: error` and 30-day retention. Log input file sizes/start at publication without leaking credentials.
- Enforce exact main SHA, verified Google Play/QA signing, signed APK/AAB, M174 SQLCipher, M449 latest release notes and complete Flutter/Python checks.
- M658 QA source contracts must fail on compression 6/default, missing source receipts, duplicate APK artifact, disabled signing, missing time bound or `continue-on-error`.

## Next production-like measurement
1. Exact-head PR source/CI green before merging M658.
2. On the NEXT main SHA, inspect overall run duration from created_at to completed_at; record APK/AAB steps separately, artifact sizes and output SHA receipts.
3. Compare against first main >21 minutes; do not claim 14–16 or definite speedup without actual evidence.
4. If upload failures persist, inspect completed job logs for quota/401/403/HTTP 5xx, account limits and Actions availability before changing compression again; never mask server failures.
