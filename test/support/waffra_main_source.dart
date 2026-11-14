import 'dart:io';

/// Reassemble the real Dart-part methods at their original line-order markers,
/// solely for preexisting source-based regression expectations.
String _method(String path,String marker){
 final c=File(path).readAsStringSync();
 final a=c.indexOf(marker),b=c.lastIndexOf('\n}');
 if(a<0||b<=a)throw StateError('Missing extracted method in $path');
 return c.substring(a,b+1);
}
String readWaffraMainSourceForContracts(){
 var s=File('lib/main.dart').readAsStringSync();
 const navMarker=' // M830: original Home navigation and summary helpers moved to registered same-library part.\n';
 if(s.split(navMarker).length!=2)throw StateError('Missing or duplicated M830 navigation helpers marker');
 s=s.replaceFirst(navMarker,_method('lib/waffra_home_navigation_helpers.part.dart',
  ' Widget categoriesPage()=>categoriesPageV2();'));
 const accountToolsMarker=' // M721: original Home calendar, backup and account tools moved to registered same-library part.\n';
 if(s.split(accountToolsMarker).length!=2)throw StateError('Missing or duplicated account tools marker');
 s=s.replaceFirst(accountToolsMarker,_method('lib/waffra_home_account_tools.part.dart',
  ' Future<void> showWaffraFinancialCalendar('));

 const budgetChartMarker=' // M805: original Home budget alerts and chart SVG methods moved to registered part.\n';
 if(s.split(budgetChartMarker).length!=2)throw StateError('Missing or duplicated M805 original chart/alert marker');
 s=s.replaceFirst(budgetChartMarker,_method('lib/waffra_home_budget_alert_charts.part.dart',
  ' Future<void> _requestPercentageAlertPermission()async{'));
 const p=' // M687: PDF exporter moved to a same-library State extension.\n';
 const q=' // M687: Profile page moved to a same-library State extension.\n';
 if(s.split(p).length!=2||s.split(q).length!=2){
  throw StateError('Missing or duplicated Dart part marker');
 }
 s=s.replaceFirst(p,_method('lib/waffra_home_pdf_reports.part.dart',
  ' Future<void> exportEntriesPdf('));
 s=s.replaceFirst(q,_method('lib/waffra_home_profile.part.dart',' Widget profilePage(){'));
 const budgetMarker=' // M715: budget editor, historical linking and category administration moved to registered Home part.\n';
 if(s.split(budgetMarker).length!=2)throw StateError('Missing or duplicate budget workflows marker');
 s=s.replaceFirst(budgetMarker,_method('lib/waffra_home_budget_workflows.part.dart',
  ' Future<void> editMonthlyBudget('));

 const r=' // M691: Budget, monthly summary and insight cards moved to same-library State extension.\n';
 if(s.split(r).length!=2)throw StateError('Missing M691 budget-card part marker');
 s=s.replaceFirst(r,_method('lib/waffra_home_budget_cards.part.dart',
  ' Widget monthlyBudgetCard(){'));
 const entryMarker=' // M719: original verified transaction entry form extracted to same-library Home part.\n';
 if(s.split(entryMarker).length!=2)throw StateError('Missing or duplicate real transaction form marker');
 s=s.replaceFirst(entryMarker,_method('lib/waffra_home_entry_sheet.part.dart',
  ' Future<void> entrySheet('));

 const t=' // M707: approved Goals and Recurring pages moved to registered Home part.\n';
 if(s.split(t).length!=2)throw StateError('Missing or repeated M707 page marker');
 s=s.replaceFirst(t,_method('lib/waffra_home_goals_recurring_pages.part.dart',
  ' Widget goalsPage(){'));
 final goalSource=File('lib/waffra_home_goal_actions.part.dart').readAsStringSync();
 final goalStart=goalSource.indexOf(' Future<void> goalDialog(');
 final goalActionStart=goalSource.indexOf(' Future<void> _m689GoalActions(');
 final goalEnd=goalSource.lastIndexOf('\n}');
 if(goalStart<0||goalActionStart<=goalStart||goalEnd<=goalActionStart){
  throw StateError('Missing or misplaced goal workflows in real Dart part');
 }
 const originalGoalMarker=' // M711: original Home goal workflows live in the registered goal-actions part.\n';
 const originalActionMarker=' // M711: goal action sheet implementation lives in the goal-actions part.\n';
 if(s.split(originalGoalMarker).length!=2||s.split(originalActionMarker).length!=2){
  throw StateError('Missing or duplicate relocated goal section');
 }
 s=s.replaceFirst(originalGoalMarker,goalSource.substring(goalStart,goalActionStart));
 s=s.replaceFirst(originalActionMarker,goalSource.substring(goalActionStart,goalEnd+1));

 const smsMarker=' /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.\n // M703: implementation moved byte-identically to registered Home part.\n';
 if(s.split(smsMarker).length!=2)throw StateError('Missing or duplicated M703 part marker');
 s=s.replaceFirst(smsMarker,_method('lib/waffra_home_sms_transfer_review.part.dart',
  ' /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.'));
 const compactActivityMarker=' // M790: original compact financial activity cards live in registered Home part.\n';
 if(s.split(compactActivityMarker).length!=2)throw StateError('Missing or duplicate M790 verified transaction card marker');
 s=s.replaceFirst(compactActivityMarker,_method('lib/waffra_home_compact_activity_cards.part.dart',
  ' Widget compactTransaction(MoneyEntry entry){'));
 const categoryReceiptMarker=' // M795: Home category selector and protected receipt dialogs moved to registered Dart part.\n';
 if(s.split(categoryReceiptMarker).length!=2)throw StateError('Missing or duplicate M795 real category and receipts marker');
 s=s.replaceFirst(categoryReceiptMarker,_method('lib/waffra_home_category_receipt_dialogs.part.dart',
  ' Future<String?> chooseTransactionCategory('));
 const m906=' // M906: original Home category and confirmation helpers extracted unchanged to registered part.\n';
 if(s.split(m906).length!=2)throw StateError('Missing or duplicate M906 real category/confirmation source');
 s=s.replaceFirst(m906,_method('lib/waffra_home_category_confirmations.part.dart',' double sum(Iterable<MoneyEntry> list,bool income)=>'));
 const financeRecoveryMarker=' // M791: original fail-closed Home finance startup and recovery UI in registered part.\n';
 if(s.split(financeRecoveryMarker).length!=2)throw StateError('Missing or duplicated M791 recovery source marker');
 s=s.replaceFirst(financeRecoveryMarker,_method('lib/waffra_home_finance_recovery.part.dart',
  ' Future<void> _loadFinanceSafely()async{'));
 const dashboardMarker=' // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.\n';
 if(s.split(dashboardMarker).length!=2)throw StateError('Missing M733 registered dashboard section');
 s=s.replaceFirst(dashboardMarker,_method('lib/waffra_home_dashboard_analytics.part.dart',
  ' Widget dashboard(){'));
 const verifiedCardsMarker=' // M733: verified transfer and savings card UI moved to registered same-library part.\n';
 if(s.split(verifiedCardsMarker).length!=2)throw StateError('Missing or duplicated M733 transfer cards marker');
 s=s.replaceFirst(verifiedCardsMarker,_method('lib/waffra_home_verified_transfer_cards.part.dart',
  ' String _m647VerifiedAccountLabel('));
 const categoryWorkflowsMarker=' // M735: Home category workflows extracted unchanged to registered same-library part.\n';
 if(s.split(categoryWorkflowsMarker).length!=2)throw StateError('Missing or duplicate M735 category workflows marker');
 s=s.replaceFirst(categoryWorkflowsMarker,_method('lib/waffra_home_category_workflows.part.dart',
  ' Future<BudgetCategory?> categoryDialog('));
 const inboxMarker=' // M739: original sender-grouped bank SMS inbox dialog moved to same-library part.\n';
 if(s.split(inboxMarker).length!=2)throw StateError('Missing or duplicate M739 original inbox marker');
 s=s.replaceFirst(inboxMarker,_method('lib/waffra_home_sms_inbox.part.dart',
  ' Future<void> _openAutoSmsInbox()async{'));
 const localRulesMarker=' // M741: original local SMS rule and learning methods moved to registered same-library part.\n';
 if(s.split(localRulesMarker).length!=2)throw StateError('Missing or duplicate M741 local-rule marker');
 s=s.replaceFirst(localRulesMarker,_method('lib/waffra_home_sms_rules.part.dart',
  ' Future<void> _openSmsRules('));
 const smsRefreshMarker=' // M742: original native SMS inbox refresh and offline classification moved to registered part.\n';
 if(s.split(smsRefreshMarker).length!=2)throw StateError('Missing or duplicate M742 guarded native SMS refresh marker');
 s=s.replaceFirst(smsRefreshMarker,_method('lib/waffra_home_sms_refresh.part.dart',
  ' Future<void> _refreshAutoSmsInbox('));
 const financeStartupMarker=' // M750: verified Home financial startup load lives in registered same-library part.\n';
 if(s.split(financeStartupMarker).length!=2)throw StateError('Missing or duplicated M750 startup load marker');
 s=s.replaceFirst(financeStartupMarker,_method('lib/waffra_home_finance_startup.part.dart',
  ' Future<void> load()async {'));
 const accountFlowMarker=' // M760: unchanged verified-account refresh, selection, transfer and account filter methods moved to registered Home part.\n';
 if(s.split(accountFlowMarker).length!=2)throw StateError('Missing or duplicated M760 account source');
 s=s.replaceFirst(accountFlowMarker,_method('lib/waffra_home_verified_account_flows.part.dart',
  ' Future<void> _m467RefreshHomeAccounts()async{'));
 const m905Marker=' // M905: original verified transfer and savings activity cache readers moved unchanged to registered Home part.\n';
 if(s.split(m905Marker).length!=2)throw StateError('Missing or repeated M905 activity marker');
 s=s.replaceFirst(m905Marker,_method('lib/waffra_home_unified_activity_reads.part.dart',' void _m648InvalidateTransfers(){'));
 const smsConfirmationMarker=' // M770: original verified SMS review confirmation and entry batching moved to same-library part.\n';
 if(s.split(smsConfirmationMarker).length!=2)throw StateError('Missing or duplicate original M770 SMS confirmation marker');
 s=s.replaceFirst(smsConfirmationMarker,_method('lib/waffra_home_sms_confirmation.part.dart',
  ' Future<List<MoneyEntry>> _m593BuildVerifiedEntries('));
 const financePersistenceMarker=' // M762: verified finance persistence and recurring due/postponement methods moved unchanged to registered Home part.\n';
 if(s.split(financePersistenceMarker).length!=2)throw StateError('Missing or duplicated M762 verified persistence source');
 s=s.replaceFirst(financePersistenceMarker,_method('lib/waffra_home_finance_persistence_due.part.dart',
  ' Future<void> persist('));
 const ledgerActionsMarker=' // M780: original verified ledger deletion/undo and source publication moved to registered Home part.\n';
 if(s.split(ledgerActionsMarker).length!=2)throw StateError('Missing or duplicated M780 verified ledger actions marker');
 s=s.replaceFirst(ledgerActionsMarker,_method('lib/waffra_home_transaction_ledger_actions.part.dart',
  ' void _publishVerifiedTransactionLedger('));
 const m907=' // M907: original authenticated Home delete-all path extracted unchanged to registered part.\n';
 if(s.split(m907).length!=2)throw StateError('Missing or duplicate M907 real confirmed-delete source');
 s=s.replaceFirst(m907,_method('lib/waffra_home_delete_all_transactions.part.dart',' Future<void> confirmDeleteAllEntries() async {'));
 const transactionCardsMarker=' // M781: original Home transaction cards/details/actions moved to registered same-library part.\n';
 if(s.split(transactionCardsMarker).length!=2)throw StateError('Missing or duplicated M781 real transaction card source marker');
 s=s.replaceFirst(transactionCardsMarker,_method('lib/waffra_home_transaction_cards.part.dart',
  ' Widget stat(String label'));
 const verifiedRefreshMarker=' // M782: verified pull-to-refresh and finance reload moved to registered Home part.\n';
 if(s.split(verifiedRefreshMarker).length!=2)throw StateError('Missing/duplicate M782 real verified refresh source');
 s=s.replaceFirst(verifiedRefreshMarker,_method('lib/waffra_home_verified_refresh.part.dart',
  ' Future<void> _refreshAndSettle('));
 const managementMarker=' // M783: original SMS settings, exclusions and local notification actions moved to registered Home part.\n';
 if(s.split(managementMarker).length!=2)throw StateError('Missing or duplicated M783 original SMS management marker');
 s=s.replaceFirst(managementMarker,_method('lib/waffra_home_sms_management.part.dart',
  ' Future<void> _scanPreviousBankSmsFromSettings()async{'));
 const summaryMarker=' // M810: original Home income/expense transaction summary now in registered part.\n';
 if(s.split(summaryMarker).length!=2)throw StateError('Missing/duplicate M810 genuine summary source');
 s=s.replaceFirst(summaryMarker,_method('lib/waffra_home_transaction_summary.part.dart',
  ' Future<void> showSummaryTransactions(bool income)async {'));
 const verifiedPickersMarker=' // M812: verified SMS money-account and optional budget pickers moved to real registered Home part.\n';
 if(s.split(verifiedPickersMarker).length!=2)throw StateError('Missing or duplicated M812 bank account/budget selection marker');
 s=s.replaceFirst(verifiedPickersMarker,_method('lib/waffra_home_verified_finance_pickers.part.dart',
  ' /// Read a single authoritative SQLCipher account witness immediately'));
 const widgetSyncMarker=' // M840: original verified Home/Widget synchronization now in registered Dart part.\n';
 if(s.split(widgetSyncMarker).length!=2)throw StateError('Missing or duplicate M840 actual Widget sync source');
 s=s.replaceFirst(widgetSyncMarker,_method('lib/waffra_home_widget_sync.part.dart',
  ' Future<void> _syncWidgetTransactions()async{'));
 const widgetBalanceMarker=" // M904: original verified Widget balance refresh and fail-closed presentation moved unchanged to registered Home part.\n";
 if(s.split(widgetBalanceMarker).length!=2)throw StateError('Missing or duplicate M904 original Widget balance marker');
 s=s.replaceFirst(widgetBalanceMarker,_method('lib/waffra_home_widget_balance.part.dart',
  ' Future<void> _refreshWidget()async{'));
 const smsIndicatorMarker=' // M835: existing bank SMS review indicator card moved unchanged to registered Home part.\n';
 if(s.split(smsIndicatorMarker).length!=2)throw StateError('Missing or duplicate M835 live SMS Review card marker');
 s=s.replaceFirst(smsIndicatorMarker,_method('lib/waffra_home_sms_review_indicator.part.dart',
  ' // ignore: unused_element\n Widget _autoSmsReviewCard(){'));
 const smsRescanMarker=' // M850: original native SMS notice/rescan logic lives in registered Home Dart part.\n';
 if(s.split(smsRescanMarker).length!=2)throw StateError('Missing or duplicate M850 live native SMS rescan source');
 s=s.replaceFirst(smsRescanMarker,_method('lib/waffra_home_sms_rescan.part.dart',
  ' void _receiveAutoSmsNotice(){'));
 return s;
}
