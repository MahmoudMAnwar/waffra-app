# M46 — Conflict-aware finance UI patches alongside Android widget writes

HomeScreen currently writes **all** finance keys from its in-memory state. A separate Android widget can append new bank SMS entries between screen loading and saving a goal, which would risk overwriting the widget's newer entry list.

This opt-in SQLCipher UI adapter is designed for the future source cutover:

- A screen receives the complete authoritative finance state as a baseline.
- When a user changes a goal, category, recurring item or other finance field, save **only changed keys** while holding the same experimental OS writer gate as the widget finance writer.
- Compare each changed field with the original screen baseline; stale same-field edits fail and require reload, avoiding last-writer-wins losses.
- Unrelated newer changes (e.g. widget transaction added while user edited a goal) are preserved in the same SQLCipher transaction with monotonically increasing generation.
- Reject missing/unknown financial fields, invalid amounts/identifiers, and unsafe removal of finance keys.
- Tests simulate a widget inserting during a goal edit, conflicting goal edits, stale transaction overwrite refusal, multi-field atomic update, invalid value rollback and encrypted cold restart.

**Not yet activated in main.dart or widget.** The live app remains on legacy SharedPreferences guarded by M43, and the new adapter defaults off. Full production use additionally requires routing every writer and view to the encrypted snapshot and providing a verified source selector and key recovery. Switching only some screens would be dangerous. Firebase remains the final separate step.
