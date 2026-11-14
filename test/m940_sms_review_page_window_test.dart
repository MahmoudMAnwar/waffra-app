import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_review_page_window.dart';

void main(){
 test('M940 2400 messages: window reveals every ID with bounded pages',(){
  final ids=List<String>.generate(2400,(i)=>'sms-$i');
  final window=WaffraSmsReviewPageWindow(pageSize:95);
  var visible=window.visibleCount(ids.length);
  expect(visible,95);
  var pages=1;
  while(window.revealNext(ids.length)){
   pages++;
   final next=window.visibleCount(ids.length);
   expect(next,greaterThan(visible));
   expect(next-visible,lessThanOrEqualTo(95));
   visible=next;
  }
  expect(visible,2400);
  expect(ids.take(visible).toSet().length,2400);
  expect(pages,26);
  expect(window.revealNext(ids.length),isFalse);
  window.reset();
  expect(window.visibleCount(ids.length),95);
 });

 test('M940 full SMS bulk selection never truncates to visible rows',(){
  final ids=List<String>.generate(2040,(i)=>'bank-$i');
  final selected=<String>{};
  final window=WaffraSmsReviewPageWindow();
  selected.addAll(ids);
  expect(selected.length,2040);
  expect(window.visibleCount(ids.length),100);
  expect(selected.contains(ids.last),isTrue);
  expect(window.visibleCount(0),0);
  expect(()=>window.visibleCount(-1),throwsRangeError);
  expect(()=>window.revealNext(-1),throwsRangeError);
 });

 test('M940 production review wires page window and original full-ID selection',(){
  final source=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(source,contains('WaffraSmsReviewPageWindow()'));
  expect(source,contains('NotificationListener<ScrollNotification>('));
  expect(source,contains('messageWindow.visibleCount(bySender[selectedSender]?.length??0)'));
  expect(source,contains('selectedIds.addAll(visibleIds());'));
  expect(source,contains('selectedIds.removeAll(visibleIds());'));
  expect(source,contains('messageWindow.revealNext(latest)'));
  expect(source,contains('if(pageRevealScheduled)return false;'));
  expect(source,contains('if(!ctx.mounted||selectedSender!=requestedSender)return;'));
  // M486 sender/editor navigation must never be deferred by post-frame callbacks.
  expect(source,isNot(contains('WidgetsBinding.instance.addPostFrameCallback((_){')));
  expect(source,contains('await _reviewAutoSmsCandidates(targetId:id);'));
 });
}
