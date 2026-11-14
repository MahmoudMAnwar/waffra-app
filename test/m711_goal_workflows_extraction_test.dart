import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M711 goal workflows live in one registered same-library part',(){
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_goal_actions.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_goal_actions.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeGoalActions on _HomeScreenState'));
  for(final name in <String>['goalDialog','releaseGoalFunds','fundGoal',
   'createSavingChallenge','deletedGoalsDialog','_m689GoalActions']){
   expect(part,contains(name+'('));
  }
  expect(home,isNot(contains(' Future<void> fundGoal(SavingGoal g)async {')));
  expect(home,isNot(contains(' Future<void> releaseGoalFunds(SavingGoal goal)async{')));
  expect(part,contains('WaffraFinanceRoute.goalCreateEditDeleteRestore'));
 });
 test('M711 source contracts restore original real money workflow order',(){
  final source=readWaffraMainSourceForContracts();
  final goal=source.indexOf(' Future<void> goalDialog(');
  final action=source.indexOf(' Future<void> _m689GoalActions(');
  final page=source.indexOf(' Widget goalsPage(){');
  expect(goal,greaterThan(0));
  expect(action,greaterThan(goal));
  expect(page,greaterThan(action));
  expect(source.substring(goal,page),contains('Future<void> fundGoal('));
  expect(source.substring(goal,page),contains('Future<void> releaseGoalFunds('));
 });
}
