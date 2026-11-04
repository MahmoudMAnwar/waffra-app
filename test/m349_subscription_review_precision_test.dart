import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smart_features.dart';

WaffraSmartEntry row(String id,String merchant,double amount,
    int year,int month,int day,{bool income=false})=>
  WaffraSmartEntry(id:id,title:merchant,category:'اشتراكات',
   amount:amount,income:income,date:DateTime(year,month,day));

void main(){
 test('M349 three reliable monthly charges suggest a subscription only',(){
  final matches=waffraSmartSubscriptions([
   row('a','Netflix',35,2026,8,4),
   row('b','Netflix',35,2026,9,4),
   row('c','Netflix',37,2026,10,4),
  ]);
  expect(matches.single.name,'Netflix');
  expect(matches.single.months,3);
 });
 test('M349 repeated generic POS label cannot become subscription',(){
  final results=waffraSmartSubscriptions([
   row('a','Purchase',75,2026,8,4),
   row('b','Purchase',75,2026,9,4),
   row('c','Purchase',75,2026,10,4),
  ]);
  expect(results,isEmpty);
 });
 test('M349 two charges in same month are ambiguous, no automated payments',(){
  final results=waffraSmartSubscriptions([
   row('a','Plan',40,2026,8,5),
   row('b','Plan',40,2026,9,5),
   row('c','Plan',40,2026,9,20),
   row('d','Plan',40,2026,10,5),
  ]);
  expect(results,isEmpty);
 });
 test('M349 non-consecutive months and changing values abstain',(){
  expect(waffraSmartSubscriptions([
   row('a','Gym',50,2026,6,1),
   row('b','Gym',50,2026,8,1),
   row('c','Gym',50,2026,10,1),
  ]),isEmpty);
  expect(waffraSmartSubscriptions([
   row('a','Gym',50,2026,8,1),
   row('b','Gym',100,2026,9,1),
   row('c','Gym',50,2026,10,1),
  ]),isEmpty);
 });
 test('M349 income refunds do not become monthly charges',(){
  final results=waffraSmartSubscriptions([
   row('a','Music',15,2026,8,1),
   row('b','Music',15,2026,9,1),
   row('c','Music',15,2026,10,1,income:true),
  ]);
  expect(results,isEmpty);
 });
}
