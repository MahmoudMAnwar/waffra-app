#!/usr/bin/env python3
"""M626: all mandatory SQLCipher Android integration test files run on 4 shards."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".github/scripts/run-android-finance-integration.sh"
WORKFLOW = ROOT / ".github/workflows/storage-android-integration.yml"
PREBUILD = ROOT / ".github/scripts/prebuild-android-finance-integration.sh"

ORIGINAL = {
    "storage_encryption_android_test.dart": 720,
    "verified_encrypted_finance_bridge_android_test.dart": 240,
    "portable_encrypted_receipts_android_test.dart": 240,
    "finance_cloud_final_release_android_test.dart": 300,
    "m78_parallel_combined_android_test.dart": 300,
    "offline_restore_android_test.dart": 240,
    "copied_receipt_ledger_android_test.dart": 240,
    "fresh_vault_first_run_android_test.dart": 240,
    "offline_finance_e2e_android_test.dart": 240,
    "finance_release_regressions_android_test.dart": 240,
    "live_finance_migration_receipts_android_test.dart": 240,
}
SHARDS = ("vault", "cloud", "receipts", "release")


class ParallelAndroidFinanceCIContract(unittest.TestCase):
    def test_each_original_file_once_with_identical_timeout(self):
        script = SCRIPT.read_text(encoding="utf-8")
        found = []
        for name in SHARDS:
            group = re.search(r"(?m)^  " + re.escape(name)
                              + r"\)\n(?P<body>.*?)(?=^    ;;)",
                              script, re.S | re.M)
            self.assertIsNotNone(group, f"missing shard {name}")
            entries = re.findall(r"(?m)^    run_android_test (\S+) (\d+)$",
                                 group.group("body"))
            self.assertTrue(entries, f"empty shard {name}")
            found.extend((test_name, int(timeout)) for test_name, timeout in entries)
        self.assertEqual(len(found), 11)
        self.assertEqual(len({name for name, _ in found}), 11)
        self.assertEqual(dict(found), ORIGINAL)

    def test_shard_prebuild_compiles_matching_first_target_and_fails_closed(self):
        script = SCRIPT.read_text(encoding="utf-8")
        prebuild = PREBUILD.read_text(encoding="utf-8")
        workflow = WORKFLOW.read_text(encoding="utf-8")
        expected_first = {}
        for shard in SHARDS:
            match = re.search(
                r"(?m)^  " + re.escape(shard) +
                r"\)\n\s*run_android_test (\S+) (\d+)$",
                script,
            )
            self.assertIsNotNone(match, f"missing first test for {shard}")
            expected_first[shard] = match.group(1)
        mapping = dict(re.findall(
            r"(?m)^  (vault|cloud|receipts|release)\) first_test=(\S+) ;;$",
            prebuild,
        ))
        self.assertEqual(mapping, expected_first)
        self.assertIn("timeout --signal=TERM --kill-after=30s 900s", prebuild)
        self.assertIn("flutter build apk --debug --no-pub --target", prebuild)
        self.assertIn('if [[ ! -s "$apk" ]]; then', prebuild)
        self.assertIn('unzip -tqq "$apk"', prebuild)
        self.assertIn('echo "ANDROID_PREBUILD_PASS:$shard:$first_test"', prebuild)
        self.assertIn(
            'run: bash .github/scripts/prebuild-android-finance-integration.sh "${{ matrix.shard }}"',
            workflow,
        )
        self.assertLess(
            workflow.index("Precompile first shard integration APK"),
            workflow.index("Test encrypted vault on Android emulator (primary)"),
        )
        self.assertIn("timeout-minutes: 18", workflow)

    def test_matrix_and_required_all_shards_gate(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("shard: [vault, cloud, receipts, release]", workflow)
        self.assertIn("max-parallel: 4", workflow)
        self.assertIn("fail-fast: false", workflow)
        self.assertIn("name: encrypted-db-${{ matrix.shard }}", workflow)
        self.assertEqual(workflow.count("ANDROID_FINANCE_SHARD: ${{ matrix.shard }}"), 2)
        self.assertIn("needs: android-encrypted-db-shard", workflow)
        self.assertIn("if: always()", workflow)
        self.assertIn('if [[ "$SHARDS_RESULT" != "success" ]]; then', workflow)
        self.assertIn("Verify exact tested SHA", workflow)
        self.assertIn("Prefetch SHA256-verified official SQLite3MC", workflow)
        self.assertIn("Test encrypted vault on Android emulator (primary)", workflow)
        self.assertIn("Retry complete finance tests on fresh API 35", workflow)
        self.assertIn("script: bash .github/scripts/run-android-finance-integration.sh", workflow)


if __name__ == "__main__":
    unittest.main()
