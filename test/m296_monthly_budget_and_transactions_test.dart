import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main(){
 setUp(()=>waffraLanguage.value='ar');
 tearDown(()=>waffraLanguage.value='ar');

 test('Blank, zero and invalid monthly budget amounts cannot be saved',(){
  for(final raw in ['', '   ', '0', '0.00', '-5', 'invalid']){
   expect(waffraMonthlyBudgetSaveError(raw),isNotNull,reason:raw);
  }
  expect(waffraMonthlyBudgetSaveError(''), 'هذا الحقل مطلوب');
  expect(waffraMonthlyBudgetSaveError('1500'),isNull);
  expect(waffraMonthlyBudgetSaveError('1,500.25'),isNull);
 });

 test('Budget stays required when tracking is paused, with English errors',(){
  waffraLanguage.value='en';
  expect(waffraMonthlyBudgetSaveError(''), 'This field is required');
  expect(waffraMonthlyBudgetSaveError('0'), 'Enter an amount greater than zero');
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('final fieldError=waffraMonthlyBudgetSaveError(amount.text);'));
  expect(source,contains('if(fieldError!=null||v==null||!v.isFinite||v<=0)'));
  expect(source,contains('TextField(controller:amount,autofocus:false,'));
  expect(source,isNot(contains('if(enabled&&(v==null||!v.isFinite||v<=0))')));
  expect(source,contains('Navigator.pop(ctx,(enabled:enabled,amount:v));'));
 });

 testWidgets('Required feedback appears beneath the amount field',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
   child:SizedBox(width:260,child:TextField(decoration:InputDecoration(
    labelText:'حد المصروفات *',
    errorText:waffraMonthlyBudgetSaveError(''),
    border:const OutlineInputBorder())))))));
  expect(find.text('هذا الحقل مطلوب'),findsOneWidget);
  expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
   'هذا الحقل مطلوب');
 });

 test('Zero through ten filtered transactions show no expansion button',(){
  for(final count in [0,1,5,9,10]){
   expect(waffraCanExpandDashboardTransactions(count),isFalse,reason:'$count');
   expect(waffraDashboardTransactionDisplayCount(count,expanded:false),count);
   expect(waffraDashboardTransactionDisplayCount(count,expanded:true),count);
  }
 });

 test('Eleven or more matching transactions start at ten and can expand',(){
  for(final count in [11,12,50]){
   expect(waffraCanExpandDashboardTransactions(count),isTrue,reason:'$count');
   expect(waffraDashboardTransactionDisplayCount(count,expanded:false),10);
   expect(waffraDashboardTransactionDisplayCount(count,expanded:true),count);
  }
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('if(waffraCanExpandDashboardTransactions(visible.length))'));
  expect(source,contains('visible.length,expanded:showAllTransactions'));
  expect(source,contains("'Show more':'عرض أكثر'"));
  expect(source,contains("'Show less':'عرض أقل'"));
 });
}
