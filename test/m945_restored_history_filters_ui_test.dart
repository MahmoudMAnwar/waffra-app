import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,WaffraHomeLedgerReadCache;
import 'package:waffra/waffra_approved_page_designs.dart';

MoneyEntry row(int i,{bool income=false})=>MoneyEntry(
 id:'restored-$i',title:'Verified historical row $i',
 category:'اختبار',amount:100+i.toDouble(),income:income,
 date:DateTime(2026,11,15,12,i),sourceType:'manual');

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M945 nineteen original entries including two incomes survive expense 20',(){
  final ledger=List<MoneyEntry>.generate(19,(i)=>row(i,income:i<2));
  final cache=WaffraHomeLedgerReadCache();
  expect(cache.index(ledger).month(2026,11).length,19);
  expect(cache.index(ledger).month(2026,11).where((e)=>e.income).length,2);
  ledger.add(MoneyEntry(id:'expense-20',title:'Manual expense',
   category:'اختبار',amount:250,income:false,
   date:DateTime(2026,11,15,13),sourceType:'manual'));
  expect(cache.index(ledger).month(2026,11).length,19);
  cache.invalidate();
  final after=cache.index(ledger).month(2026,11);
  expect(after.length,20);
  expect(after.map((e)=>e.id).toSet().length,20);
  expect(after.where((e)=>e.income).map((e)=>e.id).toSet(),
   {'restored-0','restored-1'});
  expect(after.singleWhere((e)=>e.id=='expense-20').amount,250);
 });

 test('M945 manual and SMS verified ledger replacement invalidates index',(){
  final source=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  expect(source.split('_m684InvalidatePeriodRead();entries..clear()..addAll(verified);').length-1,3);
  expect(source,contains('commitConfirmedManual('));
  expect(source,contains('Confirmed manual entry absent from verified ledger.'));
  expect(source,contains('unawaited(_m467RefreshHomeAccounts());'));
  expect(source,contains('_m684InvalidatePeriodRead();entries..clear()..addAll(previousEntries);'));
 });

 test('M945 one Goals/Dues counted dropdown and preserved original actions',(){
  final p=File('lib/waffra_home_goals_recurring_pages.part.dart').readAsStringSync();
  expect(p,contains("Key('m945-goals-filter-dropdown')"));
  expect(p,contains("Key('m945-dues-filter-dropdown')"));
  expect(p,isNot(contains('Icons.filter_alt_outlined')));
  expect(p,isNot(contains("value:'inactive',child:WaffraText(")));
  expect(p,isNot(contains("value:'incomplete',child:WaffraText(")));
  expect(p,contains('savingsChallengesSection()'));
  expect(p,contains('deletedGoalsDialog()'));
  expect(p,contains('deletedRecurringDialog()'));
  expect(p,contains('toggleRecurringReminders('));
  expect(p,contains('paidGoalDue.goalWalletPaidMinor'));
  expect(p,contains("Key('m945-dues-empty-state')"));
  expect(p,contains('WaffraCurrencyAmount(dueTotal,fontSize:17)'));
  expect(p,contains('WaffraCurrencyAmount(money,fontSize:14'));
 });

 test('M945 one Home inline Show more/less',(){
  final p=File('lib/waffra_home_dashboard_analytics.part.dart').readAsStringSync();
  final index=p.indexOf("Key('waffra-dashboard-transactions-expand')");
  expect(index,greaterThan(p.indexOf("tooltip:waffraIsEnglish?'Filter':'فلترة'")));
  expect(index,lessThan(p.indexOf("tooltip:waffraIsEnglish?'More actions':'المزيد من الخيارات'")));
  expect(p,isNot(contains("Key('waffra-dashboard-unified-activity-expand')")));
  expect(p,contains('_m945UnifiedHistoryCount=history.length;'));
 });

 testWidgets('M945 gold metrics can render real unit widget instead of ريال text',
   (tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   const WaffraApprovedMetrics(metrics:[
    WaffraApprovedMetric('المستهدف','ريال 100',Icons.savings,
     valueWidget:Text('Official currency mark')),
    WaffraApprovedMetric('العدد','5',Icons.track_changes),
   ]))));
  expect(find.text('Official currency mark'),findsOneWidget);
  expect(find.text('ريال 100'),findsNothing);
  expect(find.text('5'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
