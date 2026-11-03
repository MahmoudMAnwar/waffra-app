import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/waffra_centered_dropdown.dart';

void main(){
 testWidgets('M415 picker options are outlined and selection remains explicit',
  (tester) async{
  String? selected='all';
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:StatefulBuilder(builder:(context,update)=>
    WaffraCenteredDropdownFormField<String>(
     key:ValueKey(selected),
     initialValue:selected,
     decoration:const InputDecoration(labelText:'Status'),
     items:const [
      DropdownMenuItem(value:'all',child:Text('All budgets')),
      DropdownMenuItem(value:'active',child:Text('Active budgets')),
      DropdownMenuItem(value:'paused',child:Text('Paused budgets')),
     ],
     onChanged:(value)=>update(()=>selected=value))))));
  await tester.tap(find.text('All budgets').first);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-modal-choice-0')),findsOneWidget);
  final row= find.ancestor(
   of:find.byKey(const Key('waffra-modal-choice-0')),
   matching:find.byType(Material));
  expect(row,findsWidgets);
  await tester.tap(find.byKey(const Key('waffra-modal-choice-1')));
  await tester.pumpAndSettle();
  expect(selected,'active');
  await tester.tap(find.text('Active budgets').first);
  await tester.pumpAndSettle();
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(selected,'active');
 });
}