# M20 — independent verification of staged receipt files

M20 adds a read-only, default-disabled integrity audit after the disposable-directory M19 stage. It does **not** move, rename, delete or otherwise modify files.

The verifier checks that each archive receipt maps to the exact SHA-256 derived filename and source position, every staged file is a real regular file (not a symlink), exact receipt bytes match the authenticated preview, all totals match, and no unexpected extra files exist in the sandbox. Any disagreement fails closed. Automated tests cover valid input, default-disabled audit, tampering, missing files, extra files and untrusted mapping.

This is an experimental verification step, **not an approved production restore**. The archive preview must first come from the authenticated backup verifier and M19 staging must complete successfully. Do not use this check to authorize live data replacement on its own.

## Still required before production restore
- Safeguard against concurrent staging/auditing and sandbox path replacement; isolate the folder from untrusted writers.
- Durable app-private receipt staging and atomic ledger-path cutover with crash rollback.
- Secure recovery on storage-full, process kill and power loss.
- Real Android and iOS restore/integration testing and a user-facing confirmation flow.
- Explicit approval before enabling migration, replacing user files or deploying cloud sync.

Until release gates pass, keep all experimental components disabled and stacked PRs out of main.
