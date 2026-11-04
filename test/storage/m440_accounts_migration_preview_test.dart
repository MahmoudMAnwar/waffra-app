import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_migration_preview.dart';

void main(){
 Map<String,Object?> snapshot(List<Map<String,Object?>> rows)=>({
  'entries':jsonEncode(rows),
  'waffra_goals_v24':'[]',
  'waffra_categories_v24':'[]',
 });
 Map<String,Object?> entry(String id,double amount,{bool income=false,
  int walletPaid=0})=>({
   'id':id,'title':id,'category':'عام','amount':amount,
   'income':income,'date':'2026-11-01T12:00:00',
   'sourceType':walletPaid>0?'goal_due':'manual',
   if(walletPaid>0)'goalWalletPaidMinor':walletPaid,
  });

 test('M440 read-only preview preserves old source byte-for-byte',(){
  final old=snapshot([entry('salary',5000,income:true),
   entry('rent',2000),entry('goal',500,walletPaid:30000)]);
  final before=jsonEncode(old);
  final plan=WaffraAccountsMigrationPreview.inspect(snapshot:old);
  expect(jsonEncode(old),before);
  expect(plan.historicalEntryCount,3);
  expect(plan.cashIncomeMinor,500000);
  expect(plan.cashExpenseMinor,220000);
  expect(plan.goalWalletPaidMinor,30000);
  expect(plan.historicalNetCashMinor,280000);
  expect(plan.unassignedIds,['goal','rent','salary']);
  expect(plan.sourceDigest.length,64);
 });
 test('M440 reject mapping to phantom account or phantom transaction',(){
  final old=snapshot([entry('old',100)]);
  expect(()=>WaffraAccountsMigrationPreview.inspect(
   snapshot:old,reviewedAccountForEntry:{'old':'missing'},
   approvedAccountIds:{'verified'}),throwsA(isA<StateError>()));
  expect(()=>WaffraAccountsMigrationPreview.inspect(
   snapshot:old,reviewedAccountForEntry:{'phantom':'verified'},
   approvedAccountIds:{'verified'}),throwsA(isA<StateError>()));
 });
 test('M440 mapping is partial, never fabricates missing account links',(){
  final old=snapshot([entry('a',100),entry('b',200)]);
  final result=WaffraAccountsMigrationPreview.inspect(snapshot:old,
   reviewedAccountForEntry:{'a':'cash'},approvedAccountIds:{'cash'});
  expect(result.unassignedIds,['b']);
  expect(result.historicalEntryCount,2);
 });
 test('M440 reject duplicate IDs and unsupported amount precision',(){
  expect(()=>WaffraAccountsMigrationPreview.inspect(snapshot:snapshot([
   entry('same',1),entry('same',2)])),throwsA(isA<StateError>()));
  expect(()=>WaffraAccountsMigrationPreview.inspect(
   snapshot:snapshot([entry('sub-cent',1.001)])),
   throwsA(isA<StateError>()));
 });
}
