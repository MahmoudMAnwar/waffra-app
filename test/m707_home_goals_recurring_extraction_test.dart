import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

/// M707: source identity and exact method order, never a mock financial UI.
void main(){
 test('M707 production goal and recurring UI is registered and not duplicated',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_goals_recurring_pages.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_goals_recurring_pages.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(main,isNot(contains(' Widget goalsPage(){')));
  expect(main,isNot(contains(' Widget recurringPage(){')));
  expect(part,contains('extension _WaffraHomeGoalsRecurringPagesModule on _HomeScreenState'));
  expect(part.split(' Widget goalsPage(){').length,2);
  expect(part.split(' Widget recurringPage(){').length,2);
  expect(part,contains("Key('m689-goal-card-'+g.id)"));
  expect(part,contains('g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0)'));
  expect(part,contains('paidGoalDue=goal!=null&&paid.length==1?paid.single:null'));
  expect(part,contains('waffraGoalDueCashMinor(paidGoalDue)/100'));
  expect(part,contains('paidGoalDue.goalWalletPaidMinor/100'));
  expect(part,contains('WaffraApprovedPageHero('));
  expect(part,contains('WaffraApprovedStatusPill('));
 });
 test('M707 source-based finance tests see actual same-library pages in old order',(){
  final source=readWaffraMainSourceForContracts();
  final actions=source.indexOf(' Future<void> _m689GoalActions(');
  final goal=source.indexOf(' Widget goalsPage(){');
  final recurring=source.indexOf(' Widget recurringPage(){');
  final after=source.indexOf(' Future<void> showWaffraFinancialCalendar()async{');
  expect(actions,greaterThan(0));
  expect(goal,greaterThan(actions));
  expect(recurring,greaterThan(goal));
  expect(after,greaterThan(recurring));
  final goalSource=source.substring(goal,recurring);
  expect(goalSource,contains('max(0,g.target-g.saved)'));
  final recurringSource=source.substring(recurring,after);
  expect(recurringSource,contains('paidGoalDue.goalWalletPaidMinor/100'));
 });
}
