import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_new_account_dialog.dart';

void main(){
 testWidgets('M470 #11 bank SMS suggestion never saves without user name and consent',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:
   WaffraNewAccountDialog(english:true,suggestedProviderId:'rajhi'))));
  final type=tester.widget<DropdownButtonFormField<String>>(
   find.byKey(const Key('m470-new-account-kind')));
  expect(type.initialValue,'bank');
  final provider=tester.widget<DropdownButtonFormField<String>>(
   find.byKey(const Key('m470-new-account-provider')));
  expect(provider.initialValue,'rajhi');
  final opening=tester.widget<TextField>(
   find.byKey(const Key('m470-new-account-opening')));
  expect(opening.controller!.text,'0');
  final save=find.byKey(const Key('m470-new-account-save'));
  expect(tester.widget<FilledButton>(save).onPressed,isNull);
  await tester.ensureVisible(find.byKey(const Key('m470-new-account-label')));
  await tester.enterText(find.byKey(const Key('m470-new-account-label')),
   'Daily current account');
  await tester.pump();
  expect(tester.widget<FilledButton>(save).onPressed,isNotNull);
 });

 testWidgets('M470 #11 sender name is prefilled; only opening balance is needed',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:
   WaffraNewAccountDialog(
    english:true,suggestedProviderId:'inma',
    suggestedSenderName:'AlinmaPay'))));
  final field=tester.widget<TextField>(
   find.byKey(const Key('m470-new-account-label')));
  expect(field.controller!.text,'AlinmaPay');
  expect(tester.widget<TextField>(
   find.byKey(const Key('m470-new-account-opening'))).controller!.text,'0');
  expect(tester.widget<FilledButton>(
   find.byKey(const Key('m470-new-account-save'))).onPressed,isNotNull);
 });

 testWidgets('M470 #11 suspicious SMS sender is not trusted as account label',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:
   WaffraNewAccountDialog(
    english:true,suggestedProviderId:'inma',
    suggestedSenderName:'AlinmaPay\nunsafe'))));
  final field=tester.widget<TextField>(
   find.byKey(const Key('m470-new-account-label')));
  expect(field.controller!.text,isEmpty);
  expect(tester.widget<FilledButton>(
   find.byKey(const Key('m470-new-account-save'))).onPressed,isNull);
 });

 test('M470 #11 account suggestion only starts on confirmed bank SMS review',(){
  final home=File('lib/main.dart').readAsStringSync();
  final start=home.indexOf(' Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(');
  final end=home.indexOf('/// Budget assignment is OPTIONAL',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final flow=home.substring(start,end);
  expect(flow,contains("candidates.single.sourceType=='sms'"));
  expect(flow,contains('WaffraBankSmsFactsParser.parse(candidates.single.notes)'));
  expect(flow,contains('.canAutoPostAsIncomeExpense'));
  expect(flow,contains('WaffraSmsAccountLearning.bankGroup(smsSender)'));
  expect(flow,contains('!alreadyLinkedToBank'));
  expect(flow,contains('final offered=await showWaffraDialog<bool>('));
  expect(flow,contains('if(offered==true)'));
  expect(flow,contains('suggestedProviderId:knownBank'));
  expect(flow,contains('suggestedSenderName:smsSender'));
  expect(flow,contains('رصيد افتتاحي صفر ريال افتراضيًا'));
  expect(flow,contains("draft.kind!='bank'||draft.providerId!=knownBank"));
  expect(flow,contains('api.createTypedAccountWithIdentity('));
  // Verified suffix and user confirmation are both passed to the writer,
  // with the optional custom subtype label preserved in between.
  expect(flow,contains('lastFour:draft.lastFour,'));
  expect(flow,contains('customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true'));
  expect(flow,contains('await _refreshFromVerifiedFinance();'));
  expect(flow,contains('verified=await bridge.readVerifiedAccounts();'));
  expect(flow,contains('assigned[0]=createdFromSmsAccountId'));
  expect(flow,contains('if(approved!=true)return null;'));
  expect(flow,contains('generation:verified.witness.generation'));
  expect(flow.indexOf('if(approved!=true)return null;'),
   greaterThan(flow.indexOf('assigned[0]=createdFromSmsAccountId')));
  expect(flow,isNot(contains('commitConfirmedSms(')));
 });

 test('M470 #11 SMS posting remains a separate user approved atomic writer',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('await bulkSmsSheet(initialText:body,initialSender:sender'));
  final review=home.substring(home.indexOf('Future<void> bulkSmsSheet('),
   home.indexOf('Future<void> entrySheet(',home.indexOf('Future<void> bulkSmsSheet(')));
  expect(review,contains('reviewSmsAccountLinks('));
  expect(review,contains('commitConfirmedSms('));
  expect(review,contains('userConfirmed:true'));
 });
}
