import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main(){
 group('Savings challenges – negative and boundary cases',(){
  test('only one daily completion is permitted',(){
   final first=SavingChallenge(id:'1',title:'ادخار يومي',dailyAmount:10,days:30);
   final day=DateTime(2026,10,19,10);
   final after=first.complete(at:day);
   expect(after.completedDays,1);
   expect(after.canComplete(DateTime(2026,10,19,23)),isFalse);
   expect(after.complete(at:DateTime(2026,10,19,23)).completedDays,1);
   expect(after.canComplete(DateTime(2026,10,20)),isTrue);
   expect(after.complete(at:DateTime(2026,10,20)).completedDays,2);
  });
  test('a completed challenge never exceeds its configured duration',(){
   final challenge=SavingChallenge(id:'2',title:'اختبار',dailyAmount:25,
    days:7,completedDays:7,lastDone:DateTime(2026,10,18));
   expect(challenge.canComplete(DateTime(2026,10,19)),isFalse);
   expect(challenge.complete(at:DateTime(2026,10,19)).completedDays,7);
  });
  test('savings challenges round-trip persist progress and dates',(){
   final x=SavingChallenge(id:'3',title:'30 يوم',dailyAmount:10,days:30,
    completedDays:4,lastDone:DateTime(2026,10,19));
   final y=SavingChallenge.fromJson(x.toJson());
   expect(y.dailyAmount,10);
   expect(y.completedDays,4);
   expect(y.lastDone,DateTime(2026,10,19));
  });
 });
}
