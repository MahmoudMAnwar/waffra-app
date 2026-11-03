import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import '../lib/storage/legacy_snapshot_preflight.dart';

Map<String, Object?> snapshot({
 required Map<String, Object?> goal,
 required Map<String, Object?> recurring,
 required Map<String, Object?> budget,
}) => <String, Object?>{
 'waffra_goals_v24': jsonEncode([goal]),
 'waffra_recurring_v24': jsonEncode([recurring]),
 'waffra_named_budgets_v1': jsonEncode([budget]),
};

void main() {
 Map<String, Object?> goal() => {
  'id':'goal1','name':'Rent','target':5000.0,'saved':1000.0,
 };
 Map<String, Object?> recurring() => {
  'id':'r1','title':'Rent','amount':1000.0,
  'day':1,'startAt':'2026-11-01T00:00:00',
 };
 Map<String, Object?> budget() => {
  'id':'b1','name':'Fuel','budget':500.0,
  'income':false,'parentId':'','budgetActive':true,'alertPercent':75,
 };

 test('M414 legacy snapshots without new alert flags remain stageable', () {
  final result=WaffraLegacyPreflight.inspect(snapshot(
   goal:goal(),recurring:recurring(),budget:budget(),
  ));
  expect(result.issues.map((e)=>e.code),isEmpty);
  expect(result.canStage,isTrue);
 });

 test('M414 independent alert and reminder flags survive preflight', () {
  final result=WaffraLegacyPreflight.inspect(snapshot(
   goal:goal()..addAll({'alertEnabled':true,'alertPercent':50}),
   recurring:recurring()..['reminderEnabled']=false,
   budget:budget()..['alertEnabled']=false,
  ));
  expect(result.issues.map((e)=>e.code),isEmpty);
  expect(result.itemCounts['waffra_goals_v24'],1);
  expect(result.itemCounts['waffra_recurring_v24'],1);
  expect(result.itemCounts['waffra_named_budgets_v1'],1);
 });

 test('M414 malformed optional goal alert is rejected safely', () {
  final malformed=WaffraLegacyPreflight.inspect(snapshot(
   goal:goal()..addAll({'alertEnabled':'yes','alertPercent':101}),
   recurring:recurring(),budget:budget(),
  ));
  expect(malformed.issues.map((e)=>e.code),
   contains('invalid_goal_alert_controls'));
  expect(malformed.canStage,isFalse);
 });

 test('M414 malformed recurring reminder and budget alert are rejected', () {
  final malformed=WaffraLegacyPreflight.inspect(snapshot(
   goal:goal(),
   recurring:recurring()..['reminderEnabled']='false',
   budget:budget()..['alertEnabled']='false',
  ));
  final codes=malformed.issues.map((e)=>e.code).toSet();
  expect(codes,contains('invalid_recurring_reminder_flag'));
  expect(codes,contains('invalid_budget_controls'));
  expect(malformed.canStage,isFalse);
 });
}
