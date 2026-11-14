"""M900: fail-closed original production Home Dart-part reassembly regression.

This is a read-only source witness, not Flutter compilation, an Android device
test, or evidence of a successful restore of a private encrypted backup.
"""
from pathlib import Path
import unittest

from waffra_home_source import read_waffra_home_source

ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class M900RegisteredHomeReassemblyGuard(unittest.TestCase):
    def test_nested_real_part_markers_are_registered_and_unique(self):
        main = source("lib/main.dart")
        navigation = source("lib/waffra_home_navigation_helpers.part.dart")
        charts = source("lib/waffra_home_budget_alert_charts.part.dart")
        for part in (
            "waffra_home_navigation_helpers.part.dart",
            "waffra_home_presentation_controls.part.dart",
            "waffra_home_account_tools.part.dart",
            "waffra_home_budget_alert_charts.part.dart",
            "waffra_home_pdf_reports.part.dart",
            "waffra_home_transaction_ledger_actions.part.dart",
            "waffra_home_widget_balance.part.dart",
            "waffra_home_category_confirmations.part.dart",
            "waffra_home_delete_all_transactions.part.dart",
            "waffra_home_unified_activity_reads.part.dart",
            "waffra_home_due_account_provenance.part.dart",
        ):
            self.assertEqual(main.count("part '" + part + "';"), 1, part)
            self.assertTrue(source("lib/" + part).startswith("part of 'main.dart';"), part)
        self.assertEqual(navigation.count(
            " // M721: original Home calendar, backup and account tools "
            "moved to registered same-library part.\n"), 1)
        self.assertEqual(charts.count(
            " // M687: PDF exporter moved to a same-library State extension.\n"), 1)
        self.assertEqual(charts.count(
            " // M780: original verified ledger deletion/undo and source "
            "publication moved to registered Home part.\n"), 1)

    def test_dependencies_restore_before_nested_original_markers(self):
        python_helper = source("test/qa/waffra_home_source.py")
        dart_helper = source("test/support/waffra_main_source.dart")
        self.assertLess(
            python_helper.index('restore(" // M830:'),
            python_helper.index('restore(" // M721:'))
        self.assertLess(
            python_helper.index('restore(" // M805:'),
            python_helper.index('restore(" // M687: PDF'))
        self.assertLess(
            python_helper.index('restore(" // M805:'),
            python_helper.index('restore(" // M780:'))
        self.assertLess(
            dart_helper.index("const navMarker="),
            dart_helper.index("const accountToolsMarker="))
        self.assertLess(
            dart_helper.index("const budgetChartMarker="),
            dart_helper.index("const p="))
        self.assertLess(
            dart_helper.index("const budgetChartMarker="),
            dart_helper.index("const ledgerActionsMarker="))
        self.assertIn("if source.count(marker) != 1:", python_helper)
        self.assertIn("throw StateError('Missing or duplicated", dart_helper)

    def test_real_registered_source_preserves_finance_and_sms_witnesses(self):
        original = read_waffra_home_source(ROOT)
        for method in (
            " Future<void> showWaffraFinancialCalendar(",
            " Future<void> exportEntriesPdf(",
            " Future<void> _refreshAutoSmsInbox(",
            " Future<void> _loadFinanceSafely()async{",
            " Future<void> _syncWidgetTransactions()async{",
            " Future<void> _refreshWidget()async{",
            " Future<void> _publishVerifiedWidgetBalance(",
            " double sum(Iterable<MoneyEntry> list,bool income)=>",
            " Future<bool?> confirmDeletion(",
            " Future<void> confirmDeleteAllEntries() async {",
            " void _m648InvalidateTransfers(){",
            " Future<List<WaffraInternalTransferHistory>> _m648HomeTransfers(",
            " Future<List<WaffraVerifiedGoalMovement>> _m649HomeSavings(",
            " Future<String?> _m650DueVerifiedAccount(MoneyEntry entry){",
            " void _handleDashboardScroll(){",
            " Future<void> setAnimationLevel(String next)async {",
            " void _publishVerifiedTransactionLedger(",
        ):
            self.assertEqual(original.count(method), 1, method)
        self.assertLess(
            original.index(" Future<void> _requestPercentageAlertPermission()async{"),
            original.index(" Future<void> exportEntriesPdf("))
        self.assertLess(
            original.index(" Future<void> exportEntriesPdf("),
            original.index(" void _publishVerifiedTransactionLedger("))


if __name__ == "__main__":
    unittest.main()
