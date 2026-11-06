import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraBalanceHeader;
import 'package:waffra/waffra_account_transaction_form.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

void main(){
 testWidgets('M495 #401 long selected account label stays visible on narrow Android',
  (tester)async{
  await tester.binding.setSurfaceSize(const Size(320,760));
  addTearDown(()async=>tester.binding.setSurfaceSize(null));
  const label='مصرف الإنماء - حساب جاري للراتب والمصاريف المنزلية والالتزامات الشهرية';
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(pinned:true,delegate:WaffraBalanceHeader(
     balance:12345.67,english:false,
     selectedAccountLabel:label,onAccountTap:(){},
     refreshVerifiedWidgetBalance:()async{})),
    const SliverToBoxAdapter(child:SizedBox(height:700)),
   ]),
  )));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('m470-balance-account-picker')),findsOneWidget);
  expect(find.text(label),findsOneWidget);
  expect(tester.takeException(),isNull);
 });

 test('M495 #418 date fills row and budget is equally expanded when present',(){
  final src=File('lib/main.dart').readAsStringSync();
  final from=src.indexOf('Future<void> entrySheet({MoneyEntry? initial');
  final to=src.indexOf('Future<void> showReceipt(',from);
  expect(from,greaterThanOrEqualTo(0));
  expect(to,greaterThan(from));
  final editor=src.substring(from,to);
  expect(editor,contains('Expanded(child:dateAction())'));
  expect(editor,contains('if(!income&&waffraHasSelectableBudget(namedBudgets))'));
  expect(editor,contains('Expanded(child:WaffraCenteredDropdownFormField<String>('));
  expect(editor,contains("Key('waffra-entry-date-action')"));
 });

 test('M495 #412 user-confirmed financial account bypasses repeat popup',(){
  final src=File('lib/main.dart').readAsStringSync();
  final from=src.indexOf('reviewSmsAccountLinks(');
  final to=src.indexOf('/// Budget assignment is OPTIONAL',from);
  expect(from,greaterThanOrEqualTo(0));
  expect(to,greaterThan(from));
  final link=src.substring(from,to);
  expect(link,contains('allEditorAccountsConfirmed'));
  expect(link,contains('initialSelectedIds.every((id)=>id!=null)'));
  expect(link,contains('await bridge.readVerifiedAccounts()'));
  expect(link,contains('newAccountConfirmed'));
 });

 test('M495 #419 avoid synchronous UI blocking during navigation and refresh',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('if(_m486ResumeQueued)return;'));
  expect(src,contains('WidgetsBinding.instance.addPostFrameCallback'));
  expect(src,contains('if(target<0||target>=WaffraFooterNavigation.itemCount'));
  expect(src,contains('WaffraStationaryFabAnimator()'));
  expect(src,contains('child:ColoredBox(color:Colors.black.withValues(alpha:.30))'));
  expect(src,contains('WaffraSmoothConfirmationOverlay('));
 });

 test('M499 #416 all editor entry points expose dependent inline Add',(){
  final main=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
  expect(main,contains('forTransfer:true,transferTarget:target'));
  expect(main,contains("value:'__create_transfer_provider__'"));
  expect(main,contains("value:'__create_transfer_child__'"));
  expect(main,contains('onCreateAccount:(group,createProvider)async{'));
  expect(form,contains('if(!mounted||created==null)return;'));
  expect(form,contains('!belongsTo(destinationProvider,destination)'));
  expect(form,contains('if(group!=null&&widget.onCreateAccount!=null)'));
  expect(manager,contains('onCreateAccount:createAccountInsideComposer'));
 });

 testWidgets('M499 #416 child picker is disabled without provider, cancel preserves amount',
  (tester)async{
  var addCalls=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:WaffraAccountTransactionForm(
    english:true,initialOperation:WaffraAccountOperation.transfer,
    accounts:[
     const WaffraAccountBalance('a','Current','bank',50000,false,
      providerId:'inma'),
     const WaffraAccountBalance('b','Savings','bank',10000,false,
      providerId:'inma'),
    ],
    onConfirmTransfer:(_)async{},
    onCreateAccount:(_,__)async{addCalls++;return null;},
   ))));
  await tester.pump();
  final child=find.byKey(const Key('m470-source-account-none-0'));
  expect(child,findsOneWidget);
  expect(tester.widget<DropdownButtonFormField<String>>(child).onChanged,isNull);
  await tester.enterText(find.byKey(const Key('m440-amount')),'12.50');
  final provider=find.byKey(const Key('m470-source-provider-none-0'));
  await tester.ensureVisible(provider);
  await tester.tap(provider);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add bank / provider').last);
  await tester.pumpAndSettle();
  expect(addCalls,1);
  expect(tester.widget<TextField>(find.byKey(const Key('m440-amount')))
   .controller!.text,'12.50');
  expect(tester.widget<DropdownButtonFormField<String>>(child).onChanged,isNull);
  expect(tester.takeException(),isNull);
 });
}
