import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraBalanceHeader;
import 'package:waffra/waffra_account_transaction_form.dart';
import 'package:waffra/waffra_home_accounts_sheet.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

void main(){
 testWidgets('M549 selected long account remains accessible on narrow Android',(tester)async{
  await tester.binding.setSurfaceSize(const Size(320,760));
  addTearDown(()async=>tester.binding.setSurfaceSize(null));
  const label='مصرف الإنماء - حساب جاري للراتب والمصاريف المنزلية والالتزامات الشهرية';
  // Approved compact balance is deliberately free of any account dropdown.
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(pinned:true,delegate:WaffraBalanceHeader(
     balance:12345.67,english:false,compact:true,
     heading:'إجمالي الرصيد',
     selectedAccountLabel:label,onAccountTap:(){},
     refreshVerifiedWidgetBalance:()async{})),
    const SliverToBoxAdapter(child:SizedBox(height:700)),
   ]),
  )));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('m470-balance-account-picker')),findsNothing);
  expect(tester.takeException(),isNull);

  // The independent selector's real sheet retains the complete long label.
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   WaffraHomeAccountsSheet(english:false,selected:'one',
    accounts:const [
     WaffraAccountBalance('one',label,'bank',1234567,false),
    ]))));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('m467-account-choice-one')),findsOneWidget);
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
  expect(src,contains('child:ClipRect(child:BackdropFilter('));
  expect(src,contains('WaffraSmoothConfirmationOverlay('));
 });

 test('M499 #416 all editor entry points expose dependent inline Add',(){
  final main=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
  expect(main,contains('forTransfer:true,transferTarget:target'));
  expect(main,contains("value:'__create_transfer_provider__'"));
  expect(main,contains("value:'__create_transfer_child__'"));
  expect(main,contains('createAccountInsideEntryDropdown('));
  expect(main,contains('mainProvider:true,forTransfer:true,transferTarget:target'));
  expect(main,contains('onCreateSmsAccount:(group,createProvider,isDestination)async{'));
  expect(form,contains('if(!mounted||created==null)return;'));
  expect(form,contains('!belongsTo(destinationProvider,destination)'));
  // The inline Add entry point is available from both manual and SMS review.
  // Still require a chosen provider before the dependent child is selectable.
  expect(form,contains('if(group!=null&&(widget.onCreateAccount!=null||widget.onCreateSmsAccount!=null))'));
  expect(form,contains("value:'__create_child__'"));
  expect(form,contains('onChanged:saving||saved||creatingAccount||group==null?null:(v)async{'));
  expect(form,contains("if(v=='__create_child__')"));
  expect(form,contains('await createFromDropdown(createProvider:false,'));
  expect(manager,contains('onCreateAccount:createAccountInsideComposer'));
 });

 test('M500 #420 Details Edit enables verified retroactive account link',(){
  final src=File('lib/main.dart').readAsStringSync();
  final from=src.indexOf('Future<void> entrySheet({MoneyEntry? initial');
  final to=src.indexOf('Future<void> showReceipt(',from);
  expect(from,greaterThanOrEqualTo(0));
  expect(to,greaterThan(from));
  final edit=src.substring(from,to);
  expect(src,contains("case 'edit':await entrySheet(initial:entry);break;"));
  expect(edit,contains('readExistingEntryAccount(entryId:initial.id)'));
  expect(edit,contains('if(initial==null||canLinkExistingAccount)...['));
  expect(edit,contains('originalLinkedAccountId!=null?null:(provider)async'));
  expect(edit,contains('accountId:chosenManualAccount!,userConfirmed:true'));
  expect(edit,contains('await api.linkUnassignedEntry(entryId:initial.id'));
  expect(edit,contains('linkedHistoricalAccountInThisEdit=true;'));
  expect(edit,contains("'Confirm historical account link'"));
  expect(edit,contains("'تأكيد ربط العملية القديمة'"));
  expect(edit,contains('if(approved!=true||!sheetContext.mounted)return;'));
  expect(edit,contains('actionLabel:linkedHistoricalAccountInThisEdit?null'));
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
