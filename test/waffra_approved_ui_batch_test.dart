import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
 setUp(()=>waffraLanguage.value='ar');
 tearDown(()=>waffraLanguage.value='ar');

 test('Three recycle bins share the same card and do not erase the financial ledger',(){
  final main=File('lib/main.dart').readAsStringSync();
  final recurring=File('lib/waffra_recurring_trash.part.dart').readAsStringSync();
  final common=File('lib/waffra_deleted_item_card.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_deleted_item_card.part.dart';"));
  expect(RegExp(r'return waffraDeletedItemCard\(').allMatches(main).length,2);
  expect(recurring,contains('return waffraDeletedItemCard('));
  expect(common,contains("english?'Delete forever':'حذف نهائي'"));
  expect(common,contains("english?'Restore':'استرجاع'"));

  expect(main,contains('goals.add(goal.copy(saved:0))'),
   reason:'Restored savings goals must start with zero saved balance');
  expect(main,contains('final restored=original.copy(budget:0)'),
   reason:'Restored categories must restart with zero budget');
  expect(recurring,contains('original.copy(active:false,startAt:DateTime.now())'),
   reason:'Restored schedules must never auto-charge');
  expect(recurring,contains('recurringPostponed.removeWhere'));
  expect(recurring,contains('deletedRecurring.remove(item)'));
  expect(recurring.contains('entries.removeWhere'),isFalse);
  expect(main,contains('deletedGoals.remove(item)'));
 });

 test('Savings dialog is simple, localized and contains one primary goal-create action',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('floatingActionButtonLocation:const WaffraPhysicalLeftFab()'));
  expect(source.contains('FilledButton.icon(onPressed:goalDialog'),isFalse);
  expect(source.contains('إضافة أول هدف ادخاري'),isFalse);
  expect(source,contains("waffraIsEnglish?'Amount to add *':'المبلغ المراد إضافته *'"));
  expect(source,contains('for(final quick in [500.0,1000.0,2000.0])'));
  expect(source,contains('LinearProgressIndicator(value:currentProgress'));
  expect(source,contains('waffraAmountFieldError(amount.text)'));
  expect(source,contains("waffraIsEnglish?'Cancel':'إلغاء'"));
 });

 test('Widget draws a square 1x1 circle rather than a stretched oval',(){
  for(final file in [
   '.github/workflows/android.yml',
   '.github/workflows/android-full-smoke.yml',
  ]){
   final source=File(file).readAsStringSync();
   expect(source,contains('android:layout_width="80dp" android:layout_height="80dp"'));
   expect(source,contains('android:layout_gravity="center"'));
   expect(source,contains('android:id="@+id/waffra_widget_circle"'));
   expect(source,contains('android:targetCellWidth="1"'));
   expect(source,contains('android:targetCellHeight="1"'));
  }
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  expect(native,contains('setViewVisibility(R.id.widget_sparkle'));
  expect(native,contains('view.setTextViewText(R.id.widget_balance, balance)'));
  expect(native.contains('takeLast'),isFalse);
 });

 for(final brightness in [Brightness.light,Brightness.dark]){
  testWidgets('Deleted items offer both labeled actions and fit a narrow screen in $brightness',(tester) async{
   await tester.binding.setSurfaceSize(const Size(320,700));
   addTearDown(()=>tester.binding.setSurfaceSize(null));
   var restored=0;
   var deleted=0;
   await tester.pumpWidget(MaterialApp(
    theme:ThemeData(brightness:brightness,useMaterial3:true,fontFamily:'Tajawal'),
    home:Scaffold(body:Builder(builder:(context)=>Center(child:SizedBox(width:310,
     child:waffraDeletedItemCard(
      context:context,
      icon:Icons.flag_outlined,
      iconColor:Colors.green,
      title:'هدف ادخاري للتجربة',
      subtitle:'هدف ادخاري • متبقي 30 يوم',
      onRestore:()=>restored++,
      onDeleteForever:()=>deleted++,
     ))))),
   ));
   expect(find.byIcon(Icons.restore_rounded),findsOneWidget);
   expect(find.byIcon(Icons.delete_forever_outlined),findsOneWidget);
   await tester.tap(find.byIcon(Icons.restore_rounded));
   expect(restored,1);
   await tester.tap(find.byIcon(Icons.delete_forever_outlined));
   expect(deleted,1);
   expect(tester.takeException(),isNull);
  });
 }
}
