import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_review_groups.dart';

/// M984 / #695: the calendar is a read-only projection of owner-authenticated
/// pending SMS and independently confirmed due entries. No real SMS in tests.
void main(){
 Map<String,Object?> msg(String id,DateTime at,String kind)=> {
  'id':id,'sender':'SyntheticBank','receivedAt':at.millisecondsSinceEpoch,
  'body':'not-used-and-must-never-be-stored-in-calendar',
  'local':<String,Object?>{'kind':kind},
 };
 final first=DateTime(2026,11,15,9);
 final next=DateTime(2026,11,16,23,59);

 test('M984 one, two, three and four SMS show at most three typed dots',(){
  final one=WaffraSmsReviewCalendarIndex.from([
   msg('a',first,'income'),
  ]);
  expect(one.smsCount(first),1);
  expect(one.dots(first),['income']);
  final two=WaffraSmsReviewCalendarIndex.from([
   msg('a',first,'income'),msg('b',first,'expense'),
  ]);
  expect(two.smsCount(first),2);
  expect(two.dots(first),['income','expense']);
  final many=WaffraSmsReviewCalendarIndex.from([
   msg('a',first,'income'),msg('b',first,'expense'),
   msg('c',first,'transfer'),msg('d',first,'income'),
  ]);
  expect(many.smsCount(first),4);
  expect(many.dots(first),['income','expense','transfer']);
  expect(many.dots(first).length,3);
  expect(many.totalCount(first),4);
  expect(many.dots(next),isEmpty);
 });

 test('M984 due is violet and counted separately from SMS, including mixed day',(){
  final index=WaffraSmsReviewCalendarIndex.from([
   msg('a',first,'income'),msg('b',first,'expense'),
   msg('c',first,'transfer'),msg('d',next,'expense'),
  ],paidDueDates:[
   DateTime(2026,11,15,7),DateTime(2026,11,15,10),
   DateTime(2026,11,17,6),
  ]);
  expect(index.smsCount(first),3);
  expect(index.dueCount(first),2);
  expect(index.totalCount(first),5);
  expect(index.dots(first).length,3);
  expect(index.dots(first).last,'due');
  expect(index.smsCount(DateTime(2026,11,17)),0);
  expect(index.dueCount(DateTime(2026,11,17)),1);
  expect(index.dots(DateTime(2026,11,17)),['due']);
  expect(index.smsCount(next),1);
  expect(index.dueCount(next),0);
 });

 test('M984 no duplicate SMS fingerprint, malformed date or unsafe classification',(){
  final i=WaffraSmsReviewCalendarIndex.from([
   msg('same',first,'income'),
   msg('same',first,'expense'), // duplicate native ID must count once
   <String,Object?>{'id':'invalid','receivedAt':-5,'body':'otp 0000'},
   <String,Object?>{'id':'unknown','receivedAt':next.millisecondsSinceEpoch,
    'body':'private code in SMS; calendar must ignore it'},
  ]);
  expect(i.smsCount(first),1);
  expect(i.dots(first),['income']);
  expect(i.smsCount(next),1);
  expect(i.dots(next),['uncertain']);
  expect(i.matchesId('same',first),isTrue);
  expect(i.matchesId('same',next),isFalse);
  expect(i.matchesId('invalid',next),isFalse);
  expect(i.matchesId('unknown',next),isTrue);
 });

 test('M984 local midnight and leap-month boundaries match received timestamps',(){
  final feb=DateTime(2028,2,29,23,59,58);
  final march=DateTime(2028,3,1,0,0,1);
  final i=WaffraSmsReviewCalendarIndex.from([
   msg('last-feb',feb,'transfer'),msg('first-mar',march,'income'),
  ]);
  expect(i.smsCount(DateTime(2028,2,29)),1);
  expect(i.smsCount(DateTime(2028,3,1)),1);
  expect(i.matchesId('last-feb',DateTime(2028,2,29,8)),isTrue);
  expect(i.matchesId('last-feb',DateTime(2028,3,1)),isFalse);
  expect(i.matchesId('first-mar',DateTime(2028,3,1,22)),isTrue);
 });

 test('M984 2,000 synthetic SMS build one linear index, IDs stay scoped',(){
  final list=List<Map<String,Object?>>.generate(2000,(i)=>
   msg('id-$i',DateTime(2026,11,1+i%25,10),
    const ['income','expense','transfer','uncertain'][i%4]));
  final index=WaffraSmsReviewCalendarIndex.from(list);
  expect(List<int>.generate(25,(j)=>index.smsCount(DateTime(2026,11,1+j)))
   .reduce((a,b)=>a+b),2000);
  for(final day in List<DateTime>.generate(25,(i)=>DateTime(2026,11,i+1))){
   expect(index.dots(day).length,3);
   expect(index.totalCount(day),80);
  }
  expect(index.matchesId('id-42',DateTime(2026,11,18)),isTrue);
  expect(index.matchesId('id-42',DateTime(2026,11,17)),isFalse);
 });

 test('M984 UI calendar month grid, three colors, filter, RTL swiper and selection',(){
  final source=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(source,contains("Key('m984-sms-calendar-button')"));
  expect(source,contains("Key('m984-calendar-prev-month')"));
  expect(source,contains("Key('m984-calendar-next-month')"));
  expect(source,contains("Key('m984-calendar-day-"));
  expect(source,contains("Key('m984-calendar-reset-filter')"));
  expect(source,contains("calendarIndex.dots(date)"));
  expect(source,contains("'income'=>emerald"));
  expect(source,contains("'expense'=>Colors.deepOrange"));
  expect(source,contains("'transfer'=>const Color(0xFFD8A400)"));
  expect(source,contains("const Color(0xFF7653AA)"));
  expect(source,contains('selectedDay=selected==\'clear\'?null:DateTime.tryParse(selected)'));
  expect(source,contains('calendarIndex.matchesId(id,selectedDay!)'));
  expect(source,contains("selectedIds.removeWhere((id)=>"));
  expect(source,contains('visibleSenderNames.length'));
  expect(source,contains('messageWindow.visibleCount(visibleSenderRows.length)'));
  expect(source,contains("Key('m984-sender-previous')"));
  expect(source,contains("Key('m984-sender-next')"));
  expect(source,contains('onHorizontalDragEnd:selectedSender==null'));
  expect(source,contains('Directionality.of(ctx)==TextDirection.rtl'));
  expect(source,contains('refresh(()=>moveSender(offset))'));
  expect(source,contains('selectedIds.removeWhere((selected)=>!active.contains(selected))'));
  expect(source,contains('rebuildCalendarIndex();'));
  expect(source,isNot(contains('WaffraAutoSms.acknowledgeCompletedTransfer(')));
 });

 test('M984 previous four-rule sender grouping and owner review stay unchanged',(){
  final old=File('lib/waffra_sms_review_groups.dart').readAsStringSync();
  expect(old,contains('class WaffraSmsReviewGroups {'));
  expect(old,contains('bool removeReviewedId(String id){'));
  expect(old,contains('final canonicalNames=<String,String>{};'));
  expect(old,contains('rows.sort((a,b){'));
  final ui=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(ui,contains('_m983OpenSmsTypedTemplate(id:id,kind:kind)'));
  expect(ui,contains('await _refreshAutoSmsInbox();'));
  expect(ui,contains('WaffraSmsReviewGroups.from(_autoSmsPending'));
  expect(ui,contains('WaffraSmsReviewPageWindow()'));
  expect(ui,contains('WaffraAutoSms.excludeMessages(batch)'));
 });
}
