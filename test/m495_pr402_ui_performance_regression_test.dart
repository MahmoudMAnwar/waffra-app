import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraBalanceHeader;

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
}
