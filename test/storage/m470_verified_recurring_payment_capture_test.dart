import 'dart:io';
import '../support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

void main() {
 const verified=WaffraRuntimeFinanceBackend.verifiedEncrypted;
 const legacy=WaffraRuntimeFinanceBackend.guardedLegacy;
 const existing=<String,Object?>{
  'entries':'[]',
  'waffra_categories_v24':'[{"id":"parent"}]',
 };
 Map<String,Object> displayed({String entries='[]',String postponed='{}'})=><String,Object>{
  'entries':entries,
  'waffra_categories_v24':'[{"id":"parent"}]',
  'waffra_named_budgets_v1':'[]',
  'waffra_goals_v24':'[]',
  'waffra_recurring_v24':'[]',
  'waffra_deleted_goals_v1':'[]',
  'waffra_recurring_postponed_v1':postponed,
  'waffra_monthly_budget_v1':0.0,
  'waffra_monthly_budget_enabled_v1':false,
 };

 test('M470 paid recurring only submits new record and cleared postponement',(){
  final capture=displayed(entries:'[{"id":"rec-bill-2026-11"}]');
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   source:verified,snapshot:capture,witnessedValues:existing);
  expect(capture.keys.toList(),[
   'entries','waffra_recurring_postponed_v1',
  ]);
  expect(capture['entries'],'[{"id":"rec-bill-2026-11"}]');
  expect(capture['waffra_recurring_postponed_v1'],'{}');
 });

 test('M470 postpone-only does not manufacture unrelated optional modules',(){
  final capture=displayed(postponed:'{"rec-bill":"2026-11-20"}');
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   source:verified,snapshot:capture,witnessedValues:existing);
  expect(capture.keys.toSet(),{'entries','waffra_recurring_postponed_v1'});
  expect(capture['entries'],'[]');
 });

 test('M470 rejects accidental unrelated category mutation',(){
  final capture=displayed(entries:'[{"id":"rec-bill"}]')
   ..['waffra_categories_v24']='[{"id":"different-parent"}]';
  expect(()=>WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   source:verified,snapshot:capture,witnessedValues:existing),
   throwsStateError);
 });

 test('M470 rejects an uncommitted nonempty new budget',(){
  final capture=displayed(entries:'[{"id":"rec-bill"}]')
   ..['waffra_named_budgets_v1']='[{"id":"unsaved"}]';
  expect(()=>WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   source:verified,snapshot:capture,witnessedValues:existing),
   throwsStateError);
 });

 test('M470 due posting retains recurring provenance, never manual',(){
  final home=readWaffraMainSourceForContracts();
  final start=home.indexOf('if(!entries.any((e)=>e.id==id)){');
  final end=home.indexOf('recurringPostponed.remove(id);',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final posting=home.substring(start,end);
  expect(posting,contains("sourceType:'recurring'"));
  expect(posting,isNot(contains("sourceType:'manual'")));
 });

 test('M470 never rewrites guarded legacy capture',(){
  final capture=displayed(entries:'[{"id":"due"}]');
  final keys=capture.keys.toList();
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringPostingAndPostponement,
   source:legacy,snapshot:capture,witnessedValues:null);
  expect(capture.keys.toList(),keys);
 });
}
