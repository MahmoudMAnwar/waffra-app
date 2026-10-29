# M297 — Scan image into a reviewed Waffra transaction

## Home + user journey
- Home + menu: (1) manual transaction, (2) bank message, (3) scan receipt/image.
- The third option asks for camera/gallery access only after choosing a source, scans the original, then opens the **existing** transaction entry form with suggested amount, name, date and income/expense direction.
- The user chooses valid main/leaf categories, can correct every suggestion and must explicitly confirm saving. The selected image is staged temporarily and attached to the transaction only on successful confirmed save. Cancel deletes staged copies.
- A screenshot with multiple recognized purchase/credit anchors opens a selection/review UI, never a single forged invoice.
- OCR bank image parsing refuses to infer numbers lacking **SAR/SR/ريال**, card/reference/available balance lines, invalid precision or multiple competing monetary values; no image-derived transaction saves automatically.
- Screenshots with insufficient evidence open an empty manual-review form instead of a guess. Only the original OCR string remains ephemeral in memory.
- Preserve bilingual form UI, on-demand camera/gallery permissions, encrypted finance write path, duplicate review, haptics, and original transaction editing.

## Bank SMS dialog
- At usable widths, Paste copied SMS and Open phone messages are in one responsive row with a 10dp gap, balanced widths, no clipping. Narrow widths or very large font uses a stacked fallback.
- Existing clipboard auto-analysis and original SMS privacy, validation and saves are preserved.

## Additional feature work remaining
- Vision bounding-box highlighting, improved Arabic preprocessing and provider benchmark; QR verified-source extraction, PDF/batch imports, and learning corrections remain separate phases with mobile device tests. No claim that M297 includes these.
