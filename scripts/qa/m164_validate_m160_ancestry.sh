#!/usr/bin/env bash
# M164 read-only integration-source audit: never merges, activates SQLCipher, or touches live data.
set -euo pipefail
MAIN_AT_RECONCILIATION="dbd1605d61a8b522e6c0736ca9b1466b563c74aa"
M158_PASSING_HEAD="c0eef7e2bfb5bb6836750af48d8b499d0ab30e63"
git fetch --no-tags origin main
git merge-base --is-ancestor "$MAIN_AT_RECONCILIATION" HEAD || { echo "BLOCK: original main parent lost"; exit 1; }
git merge-base --is-ancestor "$M158_PASSING_HEAD" HEAD || { echo "BLOCK: M158 passing ancestor lost"; exit 1; }
git merge-base --is-ancestor origin/main HEAD || { echo "BLOCK: main moved; reconcile before merge"; exit 1; }
git diff --check origin/main...HEAD
for required in \
  docs/m160-main-reconciliation.md \
  scripts/m161_main_reconciliation_review.py \
  test/m131_backup_boundary_tamper_qa_test.dart \
  test/m132_backup_corruption_recovery_negative_test.dart \
  test/m140_backup_utf8_cross_archive_integrity_test.dart \
  test/m163_atomic_backup_restore_durability_test.dart \
  lib/storage/waffra_production_cutover_release_gate.dart \
  lib/waffra_secure_backup.dart \
  firebase/google-services.json
do
  test -f "$required" || { echo "BLOCK: missing $required"; exit 1; }
done
python3 - <<'PY'
from pathlib import Path
import re
files = [
    Path("lib/storage/waffra_production_cutover_release_gate.dart"),
    Path("lib/waffra_secure_backup.dart"),
]
release, crypto = (p.read_text() for p in files)
if not re.search(r"bool\s+get\s+automaticallyActivateSqlCipher\s*=>\s*false\s*;", release):
    raise SystemExit("BLOCK: automatic SQLCipher activation policy changed")
if "Argon2id" not in crypto or "Pbkdf2" not in crypto or "version==2?_v2Kdf:_legacyKdf" not in crypto:
    raise SystemExit("BLOCK: V2 encrypted archive or V1 decrypt compatibility missing")
print("M164: cutover false and V1/V2 backup compatibility source assertions present")
PY
# Detect conflict markers ONLY in app and test source files; do not suppress a conflict.
if git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' -- 'lib/*.dart' 'lib/**/*.dart' 'test/*.dart' 'test/**/*.dart'; then
  echo "BLOCK: unresolved source conflict markers"; exit 1
fi
echo "M164: read-only ancestry/scope pre-merge checks passed; NOT approval to merge or activate SQLCipher."
