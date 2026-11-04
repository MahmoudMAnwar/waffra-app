import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 testWidgets('M380 unlinked-budget cancel keeps editor and entered values', (tester)async{
  var saves=0;
  final note=TextEditingController(text:'بنزين 75');
  addTearDown(note.dispose);
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(home)=>
   Scaffold(body:TextButton(
    key:const Key('m380-open-editor'),
    onPressed:()=>showModalBottomSheet<void>(context:home,
     isScrollControlled:true,builder:(sheet)=>Scaffold(
      body:Column(mainAxisSize:MainAxisSize.min,children:[
       TextField(key:const Key('m380-amount'),controller:note),
       FilledButton(
        key:const Key('m380-save-expense'),
        onPressed:()async{
         final approved=await waffraConfirmUnlinkedBudgetSave(
          context:sheet);
         if(!approved||!sheet.mounted)return;
         saves++;
         Navigator.pop(sheet);
        },
        child:const Text('Save')),
      ]),
     )),
    child:const Text('Open editor'))))));
  await tester.tap(find.byKey(const Key('m380-open-editor')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('m380-amount')),findsOneWidget);
  await tester.tap(find.byKey(const Key('m380-save-expense')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-unlinked-budget-confirmation')),findsOneWidget);
  expect(saves,0);
  await tester.tap(find.byKey(const Key('waffra-unlinked-budget-cancel')));
  await tester.pumpAndSettle();
  expect(saves,0);
  expect(find.byKey(const Key('m380-amount')),findsOneWidget);
  expect(note.text,'بنزين 75');
  await tester.tap(find.byKey(const Key('m380-save-expense')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('waffra-unlinked-budget-accept')));
  await tester.pumpAndSettle();
  expect(saves,1);
  expect(find.byKey(const Key('m380-amount')),findsNothing);
 });

 test('M380 manual, receipt/OCR and SMS save gates are opt-in but confirmed',(){
  final app=File('lib/main.dart').readAsStringSync();
  final confirm=app.indexOf('final confirmed=await waffraConfirmUnlinkedBudgetSave(\n         context:sheetContext)');
  final post=app.indexOf('Navigator.pop(sheetContext,MoneyEntry(',confirm);
  expect(confirm,greaterThan(0));
  expect(post,greaterThan(confirm),reason:'Warning precedes any financial write.');
  expect(app,contains('context:ctx,expenseCount:unlinked'));
  expect(app,contains('if(!confirmed||!ctx.mounted)return;'));
  expect(app,contains('if(!income&&selectedBudgetId==null&&'));
  expect(app,contains('waffraHasSelectableBudget(namedBudgets)'));
  expect(app,contains('if(!candidates.any((e)=>!e.income)||choices.isEmpty)return assigned;'),
    reason:'Users without budgets should not receive an irrelevant warning.');
  expect(app,isNot(contains('missingBudgetSelection')),
    reason:'Budget remains optional; confirmations do not enforce an allocation.');
 });

 test('M380 budget choice and back remain concise, data-only and stepwise',(){
  final app=File('lib/main.dart').readAsStringSync();
  expect(app,isNot(contains('اختياري، من غير تغيير القسم')));
  expect(app,isNot(contains('ميزانية العملية (اختياري)')));
  expect(app,contains('حد الميزانية: '));
  expect(app,contains('_tabBackStack.add(tab)'));
  expect(app,contains('_tabBackStack.removeLast()'));
  expect(app,contains('if(addFabExpanded){setState(()=>addFabExpanded=false);return true;}'));
  expect(app,contains('if(goalsOpened){setState(()=>goalsOpened=false);return true;}'));
  expect(app,contains('accountOpened=false;goalsOpened=false;tab=0;'),
    reason:'Account back still follows the explicitly approved Home rule.');
 });
}
