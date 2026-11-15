import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_rule_simulator.dart';

void main(){
 test('M994 conflict at 2000th queued SMS is included, not hidden after 100',(){
  const existing=<WaffraSmsLocalRule>[
   WaffraSmsLocalRule(id:'buy',name:'Buy',sender:'BANK',
    keywords:['شراء'],kind:'expense',income:false,
    category:'بقالة وتموين / سوبرماركت'),
  ];
  const preview=WaffraSmsLocalRule(
   id:'transfer',name:'Transfer',sender:'BANK',
   keywords:['شراء'],kind:'transfer',income:false,category:'');
  final samples=<MapEntry<String,String>>[
   for(var i=0;i<1999;i++)const MapEntry('BANK','لا توجد عملية'),
   const MapEntry('BANK','تم شراء منتج'),
  ];
  final impact=WaffraSmsRuleSimulator.compare(
    existing:existing,preview:preview,samples:samples);
  expect(impact.examined,2000);
  expect(impact.changed,1);
  expect(impact.conflicts,1);
 });

 test('M994 sender scope and 2000-item preview remain exact',(){
  const preview=WaffraSmsLocalRule(
   id:'expense',name:'Buy',sender:'BANK',keywords:['شراء'],
   kind:'expense',income:false,category:'تسوق');
  final messages=<MapEntry<String,String>>[
   for(var i=0;i<1000;i++)const MapEntry('BANK','شراء 20 ريال'),
   for(var i=0;i<1000;i++)const MapEntry('OTHER','شراء 20 ريال'),
  ];
  final impact=WaffraSmsRuleSimulator.compare(
   existing:const [],preview:preview,samples:messages);
  expect(impact.examined,2000);
  expect(impact.changed,1000);
  expect(impact.conflicts,0);
 });

 test('M994 memory bounded above 2000 queued items',(){
  const preview=WaffraSmsLocalRule(
   id:'buy',name:'Buy',sender:'BANK',keywords:['شراء'],
   kind:'expense',income:false,category:'تسوق');
  final msgs=<MapEntry<String,String>>[
   for(var i=0;i<2500;i++)const MapEntry('BANK','شراء'),
  ];
  final impact=WaffraSmsRuleSimulator.compare(
    existing:const [],preview:preview,samples:msgs);
  expect(impact.examined,2000);
  expect(impact.changed,2000);
 });

 test('M994 UI shows whole-queue inspected limit, without auto-post',(){
  final ui=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  final engine=File('lib/waffra_sms_rule_simulator.dart').readAsStringSync();
  expect(ui,contains('replacingId:existing?.id,maxMessages:2000'));
  expect(ui,contains('queued messages checked'));
  expect(engine,isNot(contains('acknowledgeCommitted(')));
  expect(engine,isNot(contains('excludeMessages(')));
  expect(engine,isNot(contains('saveCaptured(')));
 });
}
