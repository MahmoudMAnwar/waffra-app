import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_new_account_dialog.dart';

void main(){
 testWidgets('M470 new account separates type, provider, name and opening balance',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraNewAccountDialog(english:true))));
  expect(find.byKey(const Key('m470-new-account-kind')),findsOneWidget);
  expect(find.byKey(const Key('m470-new-account-opening')),findsOneWidget);
  expect(find.byKey(const Key('m470-new-account-provider')),findsNothing);
  final save=find.byKey(const Key('m470-new-account-save'));
  expect(tester.widget<FilledButton>(save).onPressed,isNull);
  await tester.enterText(find.byKey(const Key('m470-new-account-label')),'My Cash');
  await tester.enterText(find.byKey(const Key('m470-new-account-opening')),'1500.25');
  await tester.pump();
  expect(tester.widget<FilledButton>(save).onPressed,isNotNull);
  await tester.enterText(find.byKey(const Key('m470-new-account-opening')),'-1');
  await tester.pump();
  expect(tester.widget<FilledButton>(save).onPressed,isNull);
 });
 testWidgets('M470 bank needs provider in addition to account nickname',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraNewAccountDialog(english:true))));
  await tester.tap(find.byKey(const Key('m470-new-account-kind')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bank account').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('m470-new-account-provider')),findsOneWidget);
  expect(find.byKey(const Key('m470-new-account-subtype')),findsOneWidget);
  expect(find.byKey(const Key('m470-new-account-last-four')),findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('m470-new-account-label')));
  await tester.enterText(find.byKey(const Key('m470-new-account-label')),'Salary');
  expect(tester.widget<FilledButton>(
   find.byKey(const Key('m470-new-account-save'))).onPressed,isNull);
 });
 testWidgets('M470 optional bank suffix validates four digits without storing full account numbers',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(
   body:WaffraNewAccountDialog(english:true))));
  expect(find.byKey(const Key('m470-new-account-last-four')),findsNothing);
  await tester.tap(find.byKey(const Key('m470-new-account-kind')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bank account').last);
  await tester.pumpAndSettle();
  final suffix=find.byKey(const Key('m470-new-account-last-four'));
  expect(suffix,findsOneWidget);
  await tester.ensureVisible(suffix);
  await tester.enterText(suffix,'12');
  await tester.pump();
  expect(tester.widget<FilledButton>(
   find.byKey(const Key('m470-new-account-save'))).onPressed,isNull);
  await tester.enterText(suffix,'1234');
  await tester.pump();
  expect(tester.widget<TextField>(suffix).controller!.text,'1234');
 });
}
