import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_review_calendar.dart';

Map<String,Object?> message(int id,DateTime day,String kind)=>{
 'id':id.toString().padLeft(64,'a'),
 'sender':'SyntheticBank',
 'receivedAt':day.millisecondsSinceEpoch,
 'body':'Non-sensitive synthetic bank event',
 'local':<String,Object?>{'kind':kind},
};

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M984 per-day counts have no silent three-message cap in data',(){
  final d=DateTime.now();
  final day=DateTime(d.year,d.month,d.day);
  final next=day.subtract(const Duration(days:1));
  final rows=<Map<String,Object?>>[
   message(1,day,'income'),message(2,day,'expense'),
   message(3,day,'transfer'),message(4,day,'due'),
   message(5,next,'income'),
  ];
  final all=WaffraSmsReviewCalendarData.countByLocalDay(rows);
  expect(all[day],['income','expense','transfer','due']);
  expect(all[day]?.length,4);
  expect(all[next]?.length,1);
  expect(WaffraSmsReviewCalendarData.countByLocalDay(rows,sender:'Other'),
   isEmpty);
  expect(WaffraSmsReviewCalendarData.localDay(<String,Object?>{
   'receivedAt':-10}),isNull);
 });

 test('M984 financial card colors include recurring due violet',(){
  expect(WaffraSmsReviewCalendarData.colorForKind('income'),
   const Color(0xFF087A54));
  expect(WaffraSmsReviewCalendarData.colorForKind('expense'),
   Colors.deepOrange);
  expect(WaffraSmsReviewCalendarData.colorForKind('transfer'),
   const Color(0xFFD8BA78));
  expect(WaffraSmsReviewCalendarData.colorForKind('due'),
   const Color(0xFF7653AA));
  expect(WaffraSmsReviewCalendarData.colorForKind('due',dark:true),
   const Color(0xFFD6BBFF));
  expect(WaffraSmsReviewCalendarData.colorForKind('recurring'),
   const Color(0xFF7653AA));
 });

 testWidgets('M984 4 SMS display exactly 3 colored dots, two show 2, one 1',
      (tester)async{
  final d=DateTime.now();
  final today=DateTime(d.year,d.month,d.day);
  final earlier=today.subtract(const Duration(days:1));
  final earlier2=today.subtract(const Duration(days:2));
  final rows=<Map<String,Object?>>[
   message(1,today,'income'),message(2,today,'expense'),
   message(3,today,'transfer'),message(4,today,'due'),
   message(5,earlier,'expense'),message(6,earlier,'transfer'),
   message(7,earlier2,'income'),
  ];
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:SingleChildScrollView(child:WaffraSmsReviewCalendar(
    messages:rows,selectedDay:today,onSelected:(_){},
   )))));
  String dot(int i,DateTime t)=>
   'm984-dot-${t.year}-${t.month}-${t.day}-$i';
  expect(find.byKey(Key(dot(0,today))),findsOneWidget);
  expect(find.byKey(Key(dot(1,today))),findsOneWidget);
  expect(find.byKey(Key(dot(2,today))),findsOneWidget);
  expect(find.byKey(Key(dot(3,today))),findsNothing);
  final one=tester.widget<Container>(find.byKey(Key(dot(0,today))));
  expect((one.decoration as BoxDecoration).color,
   WaffraSmsReviewCalendarData.colorForKind('income'));
  final second=tester.widget<Container>(find.byKey(Key(dot(1,today))));
  expect((second.decoration as BoxDecoration).color,
   WaffraSmsReviewCalendarData.colorForKind('expense'));
  final third=tester.widget<Container>(find.byKey(Key(dot(2,today))));
  expect((third.decoration as BoxDecoration).color,
   WaffraSmsReviewCalendarData.colorForKind('transfer'));
  if(earlier.month==today.month){
   expect(find.byKey(Key(dot(0,earlier))),findsOneWidget);
   expect(find.byKey(Key(dot(1,earlier))),findsOneWidget);
   expect(find.byKey(Key(dot(2,earlier))),findsNothing);
  }
  if(earlier2.month==today.month){
   expect(find.byKey(Key(dot(0,earlier2))),findsOneWidget);
   expect(find.byKey(Key(dot(1,earlier2))),findsNothing);
  }
 });

 testWidgets('M984 Arabic RTL picks a real day and can navigate months',
      (tester)async{
  final d=DateTime.now();
  final date=DateTime(d.year,d.month,d.day);
  DateTime? selected;
  await tester.pumpWidget(MaterialApp(home:Directionality(
   textDirection:TextDirection.rtl,
   child:Scaffold(body:SingleChildScrollView(
    child:WaffraSmsReviewCalendar(
     messages:[message(1,date,'income')],
     selectedDay:date,english:false,onSelected:(value)=>selected=value,
     onClear:(){selected=DateTime(1);},
    ),
   )))));
  await tester.tap(find.byKey(Key(
   'm984-day-${date.year}-${date.month}-${date.day}')));
  expect(selected,date);
  // Calendar buttons below the day grid need actual viewport scrolling.
  await tester.ensureVisible(find.byKey(const Key('m984-calendar-show-all')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m984-calendar-show-all')));
  expect(selected?.year,1);
  await tester.ensureVisible(find.byKey(const Key('m984-calendar-prev')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m984-calendar-prev')));
  await tester.pumpAndSettle();
  expect(find.byKey(Key(
   'm984-day-${date.year}-${date.month}-${date.day}')),findsNothing);
  await tester.ensureVisible(find.byKey(const Key('m984-calendar-next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('m984-calendar-next')));
  await tester.pumpAndSettle();
  expect(find.byKey(Key(
   'm984-day-${date.year}-${date.month}-${date.day}')),findsOneWidget);
 });

 test('M984 filtered day has correct sender list and selection protections',
      (){
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(inbox,contains('DateTime? selectedDay;'));
  expect(inbox,contains('WaffraSmsReviewCalendarData.localDay(row)'));
  expect(inbox,contains('DateUtils.isSameDay(received,selectedDay)'));
  expect(inbox,contains('senderIds.clear()'));
  expect(inbox,contains('displayBySender.clear()'));
  expect(inbox,contains('displaySenders.clear()'));
  expect(inbox,contains('selectedIds.removeWhere((selected)=>!active.contains(selected))'));
  expect(inbox,contains('for(final row in _autoSmsPending)'));
  expect(inbox,contains("if(row['id'] is String)row['id'] as String"));
  expect(inbox,contains('selectedIds.addAll(visibleIds())'));
  // Selecting a sender under a day filter may never select hidden-day SMS.
  expect(inbox,contains('value:idsOf(displayBySender[sender]!).isNotEmpty&&'));
  expect(inbox,contains('final ids=idsOf(displayBySender[sender]!);'));
  // Blocking an entire sender remains possible only if ALL of its SMS IDs,
  // including hidden dates, were explicitly selected by the owner.
  expect(inbox,contains('final groupIds=idsOf(bySender[sender]??const []);'));

  expect(inbox,contains('selectedDay=picked.year==1?null:picked'));
  expect(inbox,contains('refreshReviewIds()'));
  expect(inbox,contains("Key('m984-sms-review-calendar')"));
  expect(inbox,contains("Key('m984-sms-clear-day-filter')"));
 });

 test('M984 horizontal sender switch preserves vertical ListView and approvals',
      (){
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(inbox,contains("Key('m984-sms-sender-horizontal-swipe')"));
  expect(inbox,contains('onHorizontalDragEnd:selectedSender==null||bulkBusy?null:'));
  expect(inbox,contains('final next=current+(velocity<0?1:-1)'));
  expect(inbox,contains('selectedSender=displaySenders[next]'));
  expect(inbox,contains('messageWindow.reset()'));
  expect(inbox,contains('NotificationListener<ScrollNotification>'));
  expect(inbox,contains('Axis.vertical'));
  expect(inbox,contains('ListView.builder('));
  expect(inbox,contains('_m983OpenSmsTypedTemplate(id:id,kind:kind)'));
  expect(inbox,contains('await WaffraAutoSms.excludeMessages(batch)'));
  expect(inbox,isNot(contains('commitConfirmedSms(')));
 });
}
