# M36 — One serialized finance writer for app and widget (offline rehearsal)

The Android quick-add widget and HomeScreen currently load their own SharedPreferences snapshot and can overwrite each other. M36 implements a **disabled-by-default, disposable encrypted writer** that applies narrow transaction changes to the latest finance state.

### Implemented and tested

- Both app-like manual transaction saves and widget-like confirmed bank SMS batches use the **same M34 file lock**. The writer re-reads authoritative M35 SQLCipher finance state only after lock acquisition.
- Append one to 100 validated records with stable IDs. The operation changes only the transactions array and deduplication hashes; never overwrites goals, budgets, categories or recycle bins with stale cached values.
- SMS hashes must be SHA-256 hex. Default behavior skips previously committed hashes and duplicates in the current batch. The returned saved/income/expense/skip counts are based on the encrypted commit, not parsing.
- Duplicate IDs, unsafe receipt file paths, nonrepresentable fractional halalas, missing title/category, bad dates and unconfirmed saves fail without changing the source.
- Entire batch + hashes + financial generation commit atomically to SQLCipher, with stale revision rejection and cold-restart recovery.
- Tests demonstrate app and widget append calls running simultaneously and retaining both transactions.

### Not yet activated on real users

Waffra's existing HomeScreen and Android quick-add widget **have not** been rewired yet. This protects real users while the final source-selection transition, full Android widget integration, dashboard reload/read transaction, new-install key handling, receipts, rollback and release regression tests are completed.

The file lock is cooperative/advisory: it does not stop old code that does not participate. No Firebase, bank-account integration, live transaction or cloud operation is involved.
