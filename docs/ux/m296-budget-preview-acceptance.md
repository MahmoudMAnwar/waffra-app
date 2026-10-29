# M296 — Monthly budget validation and dashboard transaction preview

- Budget amount is required even when the tracking switch is OFF. Blank or whitespace shows **هذا الحقل مطلوب** under the input (English: **This field is required**). Zero, negative and malformed amounts fail with the existing amount validation message.
- The amount field remains editable while monitoring is paused; the switch only disables monitoring, not the requirement for saving a positive budget amount.
- Saving a valid positive amount preserves the tracking toggle state.
- Transaction list defaults to the **10 most recent matching entries**, or all entries if 10 or fewer.
- **عرض أكثر / Show more** appears only if **more than 10 matching transactions** remain after current search, type, category, date and amount filters. Clicking displays the remaining entries; **عرض أقل / Show less** returns to 10.
- Expanding does not silently reset filters. Totals, export, encrypted persistence and the transaction ordering remain unchanged.
- Exact-head Flutter analysis and M296 + M295/M260/M274/M277/M283/M285 + form validation tests required. No finance database migration.
