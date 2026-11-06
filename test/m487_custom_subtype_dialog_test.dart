import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_new_account_dialog.dart';

void main(){
 testWidgets('M487 user adds and selects custom bank subtype', (tester)async{
  WaffraNewAccountDraft? result;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
   builder:(context)=>FilledButton(
    onPressed:()async{
     result=await showDialog<WaffraNewAccountDraft>(
      context:context,builder:(_)=>const WaffraNewAccountDialog(
       english:true,suggestedProviderId:'inma',
       suggestedSenderName:'AlinmaPay'));
    },child:const Text('Open account'))))));
  await tester.tap(find.text('Open account'));
  await tester.pumpAndSettle();
  final selector=find.byKey(const Key('m470-new-account-subtype'));
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add account subtype').last);
  await tester.pumpAndSettle();
  await tester.enterText(
   find.byKey(const Key('m487-custom-account-subtype-input')),
   'Rewards Account');
  await tester.pump();
  await tester.tap(find.byKey(const Key('m487-custom-account-subtype-save')));
  await tester.pumpAndSettle();
  expect(find.text('Rewards Account'),findsWidgets);
  await tester.tap(find.byKey(const Key('m470-new-account-save')));
  await tester.pumpAndSettle();
  expect(result,isNotNull);
  expect(result!.kind,'bank');
  expect(result!.providerId,'inma');
  expect(result!.subtype,'other');
  expect(result!.customSubtypeLabel,'Rewards Account');
  expect(result!.openingMinor,0);
 });

 testWidgets('M487 persisted labels can be selected in later bank dialog',
  (tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraNewAccountDialog(english:true,
    suggestedProviderId:'inma',suggestedSenderName:'AlinmaPay',
    customSubtypeOptions:{'bank':['Rewards Account']}))));
  final selector=find.byKey(const Key('m470-new-account-subtype'));
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  expect(find.text('Rewards Account'),findsOneWidget);
  await tester.tap(find.text('Rewards Account').last);
  await tester.pump();
  expect(find.text('Rewards Account'),findsOneWidget);
 });
 testWidgets('M487 cancel Add restores the selected canonical subtype', (tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraNewAccountDialog(english:true,
    suggestedProviderId:'inma',suggestedSenderName:'AlinmaPay'))));
  final selector=find.byKey(const Key('m470-new-account-subtype'));
  await tester.ensureVisible(selector);
  expect(tester.state<FormFieldState<String>>(selector).value,'current');
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add account subtype').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cancel').last);
  await tester.pumpAndSettle();
  expect(tester.state<FormFieldState<String>>(selector).value,'current');
 });

}
