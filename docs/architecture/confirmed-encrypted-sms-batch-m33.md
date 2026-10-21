# M33 — Confirmed bank SMS batch saving in encrypted SQLite

A new, default-off transactional SMS batch writer supports Waffra's agreed UX without direct bank-account access:

- **Explicit confirmation is required** before any write; parsing, previewing or canceling has no persistence effects.
- **Maximum 100 detected transactions per paste**, regardless of parsing method.
- Each normalized SMS transaction is saved together with its one-way SHA-256 deduplication hash in a **single encrypted SQL transaction**.
- Saved total, saved-income and saved-expense counts, skipped duplicates, and money totals reflect actual successfully committed records, not parsed candidates.
- Repeated messages are skipped by default, including repeats from a previous launch. A duplicate transaction may only be saved if the UI explicitly opts into duplicates, and all transaction IDs must still be unique.
- Invalid input or SQLite constraint failure rolls back the whole batch and its hashes: the app must display a retry/review message, not claim any transaction was saved.
- No raw bank SMS is persisted by this service; it accepts only approved normalized title/category, date, integer halalas and hash. Callers must not insert bank-account identifiers into those display fields.
- No Firebase, network access, phone SMS permission, or bank-account integration exists in this component.

## Still blocked

The current HomeScreen bulk SMS UI and Android standalone widget persist directly to SharedPreferences; they are **not** switched to this API yet. Connecting them before a common cross-process source selector, writer barrier and error-handling policy would introduce competing balances. No live finance data is affected. The next step is to route both launch contexts through one safe data source, then test true save confirmation and counts on the real Android UI.
