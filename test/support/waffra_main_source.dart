import 'dart:io';

/// Reassemble the real Dart-part methods at their original line-order markers,
/// solely for preexisting source-based regression expectations.
String _method(String path,String marker){
 final c=File(path).readAsStringSync();
 final a=c.indexOf(marker),b=c.lastIndexOf('\n}');
 if(a<0||b<=a)throw StateError('Missing extracted method in $path');
 return c.substring(a,b);
}
String readWaffraMainSourceForContracts(){
 var s=File('lib/main.dart').readAsStringSync();
 const accountToolsMarker=' // M721: original Home calendar, backup and account tools moved to registered same-library part.\n';
 if(s.split(accountToolsMarker).length!=2)throw StateError('Missing or duplicated account tools marker');
 s=s.replaceFirst(accountToolsMarker,_method('lib/waffra_home_account_tools.part.dart',
  ' Future<void> showWaffraFinancialCalendar('));

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
 s=s.replaceFirst(originalActionMarker,goalSource.substring(goalActionStart,goalEnd));

 const smsMarker=' /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.\n // M703: implementation moved byte-identically to registered Home part.\n';
 if(s.split(smsMarker).length!=2)throw StateError('Missing or duplicated M703 part marker');
 s=s.replaceFirst(smsMarker,_method('lib/waffra_home_sms_transfer_review.part.dart',
  ' /// Explicit, idempotent account-to-account transfer from reviewed bank SMS.'));
 return s;
}
