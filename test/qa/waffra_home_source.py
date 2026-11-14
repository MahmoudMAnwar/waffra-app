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
    restore(" // M735: Home category workflows extracted unchanged to registered same-library part.\n",
            "lib/waffra_home_category_workflows.part.dart",
            " Future<BudgetCategory?> categoryDialog(")
    restore(" // M739: original sender-grouped bank SMS inbox dialog moved to same-library part.\n",
            "lib/waffra_home_sms_inbox.part.dart",
            " Future<void> _openAutoSmsInbox()async{")
    restore(" // M741: original local SMS rule and learning methods moved to registered same-library part.\n",
            "lib/waffra_home_sms_rules.part.dart",
            " Future<void> _openSmsRules(")
    return source
