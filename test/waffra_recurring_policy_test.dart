import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_recurring_policy.dart';

void main(){
 group('Recurring financial posting policy',(){
  final first=DateTime(2026,11,1);
  test('creating a future schedule does not create a due transaction',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:first,today:DateTime(2026,10,21),startAt:first,alreadyPaid:false),isFalse);
  });
  test('due schedules require confirmation',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:first,today:first,startAt:first,alreadyPaid:false),isTrue);
  });
  test('posted schedule cannot be posted twice',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:first,today:first,startAt:first,alreadyPaid:true),isFalse);
  });
  test('postponement blocks the current date',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:first,today:DateTime(2026,11,1),startAt:first,
    alreadyPaid:false,postponedUntil:DateTime(2026,11,12)),isFalse);
  });
  test('postponed item becomes due on chosen date',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:first,today:DateTime(2026,11,12),startAt:first,
    alreadyPaid:false,postponedUntil:DateTime(2026,11,12)),isTrue);
  });
  test('old months before schedule start are excluded',(){
   expect(WaffraRecurringPolicy.isOutstanding(
    due:DateTime(2026,9,1),today:DateTime(2026,11,15),
    startAt:first,alreadyPaid:false),isFalse);
  });
  test('February 2027 day 31 is clamped to 28',(){
   expect(WaffraRecurringPolicy.dueDate(2027,2,31),DateTime(2027,2,28));
  });
  test('leap February 2028 day 31 is clamped to 29',(){
   expect(WaffraRecurringPolicy.dueDate(2028,2,31),DateTime(2028,2,29));
  });
  test('each monthly posting has its own unique stable identifier',(){
   expect(WaffraRecurringPolicy.entryId('car',DateTime(2026,11,1)),isNot(
    WaffraRecurringPolicy.entryId('car',DateTime(2026,12,1))));
  });
  test('halala rounding makes net arithmetic exact',(){
   expect(WaffraRecurringPolicy.netHalalas([0.1,0.2,1000.15],[0.3,200]),80015);
  });
 });
}
