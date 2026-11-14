"""Real main.dart and registered production parts for old source QA."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def _method(root, path, begin):
    source = (root / path).read_text(encoding="utf-8")
    a, b = source.find(begin), source.rfind("\n}")
    if a < 0 or b <= a:
        raise AssertionError("Missing Dart production method: " + path)
    return source[a:b+1]

def read_waffra_home_source(root=ROOT):
    source = (root / "lib/main.dart").read_text(encoding="utf-8")
    def restore(marker, path, begin):
        nonlocal source
        if source.count(marker) != 1:
            raise AssertionError("Missing/duplicate Dart part marker: " + marker)
        source = source.replace(marker, _method(root, path, begin), 1)
    restore(" // M721: original Home calendar, backup and account tools moved to registered same-library part.\n",
            "lib/waffra_home_account_tools.part.dart"," Future<void> showWaffraFinancialCalendar(")
    restore(" // M687: PDF exporter moved to a same-library State extension.\n",
            "lib/waffra_home_pdf_reports.part.dart"," Future<void> exportEntriesPdf(")
    restore(" // M687: Profile page moved to a same-library State extension.\n",
            "lib/waffra_home_profile.part.dart"," Widget profilePage(){")
    restore(" // M715: budget editor, historical linking and category administration moved to registered Home part.\n",
            "lib/waffra_home_budget_workflows.part.dart"," Future<void> editMonthlyBudget(")
    restore(" // M691: Budget, monthly summary and insight cards moved to same-library State extension.\n",
            "lib/waffra_home_budget_cards.part.dart"," Widget monthlyBudgetCard(){")
    restore(" // M719: original verified transaction entry form extracted to same-library Home part.\n",
            "lib/waffra_home_entry_sheet.part.dart"," Future<void> entrySheet(")
    restore(" // M707: approved Goals and Recurring pages moved to registered Home part.\n",
            "lib/waffra_home_goals_recurring_pages.part.dart"," Widget goalsPage(){")
    goal = (root / "lib/waffra_home_goal_actions.part.dart").read_text(encoding="utf-8")
    a,b,c = goal.find(" Future<void> goalDialog("),goal.find(" Future<void> _m689GoalActions("),goal.rfind("\n}")
    if a < 0 or b <= a or c <= b:
        raise AssertionError("Original goal code part is malformed")
    markers = (
       (" // M711: original Home goal workflows live in the registered goal-actions part.\n",goal[a:b]),
       (" // M711: goal action sheet implementation lives in the goal-actions part.\n",goal[b:c+1]),
    )
    for marker,code in markers:
        if source.count(marker) != 1:
            raise AssertionError("Missing/duplicate goal marker")
        source = source.replace(marker, code, 1)
    restore(" /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.\n // M703: implementation moved byte-identically to registered Home part.\n",
            "lib/waffra_home_sms_transfer_review.part.dart",
            " /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.")
    restore(" // M733: verified transfer and savings card UI moved to registered same-library part.\n",
            "lib/waffra_home_verified_transfer_cards.part.dart",
            " String _m647VerifiedAccountLabel(")
    restore(" // M790: original compact financial activity cards live in registered Home part.\n",
            "lib/waffra_home_compact_activity_cards.part.dart",
            " Widget compactTransaction(MoneyEntry entry){")
    restore(" // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.\n",
            "lib/waffra_home_dashboard_analytics.part.dart",
            " Widget dashboard(){")
    restore(" // M735: Home category workflows extracted unchanged to registered same-library part.\n",
            "lib/waffra_home_category_workflows.part.dart",
            " Future<BudgetCategory?> categoryDialog(")
    restore(" // M739: original sender-grouped bank SMS inbox dialog moved to same-library part.\n",
            "lib/waffra_home_sms_inbox.part.dart",
            " Future<void> _openAutoSmsInbox()async{")
    restore(" // M741: original local SMS rule and learning methods moved to registered same-library part.\n",
            "lib/waffra_home_sms_rules.part.dart",
            " Future<void> _openSmsRules(")
    restore(" // M742: original native SMS inbox refresh and offline classification moved to registered part.\n",
            "lib/waffra_home_sms_refresh.part.dart",
            " Future<void> _refreshAutoSmsInbox(")
    restore(" // M750: verified Home financial startup load lives in registered same-library part.\n",
            "lib/waffra_home_finance_startup.part.dart",
            " Future<void> load()async {")
    restore(" // M760: unchanged verified-account refresh, selection, transfer and account filter methods moved to registered Home part.\n",
            "lib/waffra_home_verified_account_flows.part.dart",
            " Future<void> _m467RefreshHomeAccounts()async{")
    restore(" // M770: original verified SMS review confirmation and entry batching moved to same-library part.\n",
            "lib/waffra_home_sms_confirmation.part.dart",
            " Future<List<MoneyEntry>> _m593BuildVerifiedEntries(")
    restore(" // M762: verified finance persistence and recurring due/postponement methods moved unchanged to registered Home part.\n",
            "lib/waffra_home_finance_persistence_due.part.dart",
            " Future<void> persist(")
    restore(" // M805: original Home budget alerts and chart SVG methods moved to registered part.\n",
            "lib/waffra_home_budget_alert_charts.part.dart",
            " Future<void> _requestPercentageAlertPermission()async{")
    restore(" // M780: original verified ledger deletion/undo and source publication moved to registered Home part.\n",
            "lib/waffra_home_transaction_ledger_actions.part.dart",
            " void _publishVerifiedTransactionLedger(")
    restore(" // M781: original Home transaction cards/details/actions moved to registered same-library part.\n",
            "lib/waffra_home_transaction_cards.part.dart",
            " Widget stat(String label")
    restore(" // M782: verified pull-to-refresh and finance reload moved to registered Home part.\n",
            "lib/waffra_home_verified_refresh.part.dart",
            " Future<void> _refreshAndSettle(")
    restore(" // M783: original SMS settings, exclusions and local notification actions moved to registered Home part.\n",
            "lib/waffra_home_sms_management.part.dart",
            " Future<void> _scanPreviousBankSmsFromSettings()async{")
    restore(" // M795: Home category selector and protected receipt dialogs moved to registered Dart part.\n",
            "lib/waffra_home_category_receipt_dialogs.part.dart",
            " Future<String?> chooseTransactionCategory(")
    restore(" // M791: original fail-closed Home finance startup and recovery UI in registered part.\n",
            "lib/waffra_home_finance_recovery.part.dart",
            " Future<void> _loadFinanceSafely()async{")
    restore(" // M810: original Home income/expense transaction summary now in registered part.\n",
            "lib/waffra_home_transaction_summary.part.dart",
            " Future<void> showSummaryTransactions(bool income)async {")
    restore(" // M812: verified SMS money-account and optional budget pickers moved to real registered Home part.\n",
            "lib/waffra_home_verified_finance_pickers.part.dart",
            " /// Read a single authoritative SQLCipher account witness immediately")
    restore(" // M840: original verified Home/Widget synchronization now in registered Dart part.\n",
            "lib/waffra_home_widget_sync.part.dart",
            " Future<void> _syncWidgetTransactions()async{")
    restore(" // M830: original Home navigation and summary helpers moved to registered same-library part.\n",
            "lib/waffra_home_navigation_helpers.part.dart",
            " Widget categoriesPage()=>categoriesPageV2();")
    return source
